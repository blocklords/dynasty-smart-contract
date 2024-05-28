// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./../nfts/NftFactory.sol";
import "./../nfts/OrbNFT.sol";

/**
 * @title BLOCKLORDS
 * @dev This contract implements functionalities related to opening chests, minting NFTs, starting seasons, 
   verifying signatures, and burning Orb NFTs for LRDS rewards.
 * @author BLOCKLORDS TEAM
 * @notice This contract represents a chest where players can open and receive various types of NFTs during active seasons or craft Mythic Orbs by combining five orbs of different qualities.
   Players can also earn LRDS rewards by burning Orb NFTs after the end of a season.
 */

contract Chest is IERC721Receiver, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    bool    private lock;                           // Mutex to prevent reentrancy attacks
    uint256 public  seasonId;                       // ID of the current season
    address public  factory;                        // Address of the factory contract
    address public  orbNft;                         // Address of the Orb NFT contract
    address public  verifier;                       // Address of the verifier for signature verification
    address public  nftFactory;                     // Address of the NFT Factory contract
    uint256 public  maxNFTsWithdrawal = 10;         // The maximum number of nft that can be obtained by opening a treasure chest

    struct Season {
        uint256 startTime;                          // Start time of the season
        uint256 duration;                           // Duration of the season
    }

    mapping(uint256 => Season) public seasons;      // Mapping of season IDs to their details
    mapping(address => uint256) public nonce;       // Nonce for signature verification
    mapping(uint256 => address) public nftTypes;    // Mapping of NFT type indices to their contracts

    event CraftOrb(address indexed owner, uint256 indexed nftId, uint256 indexed quality, uint256 time);                        // Event emitted when an NFT is minted
    event SeasonStarted(uint256 indexed seasonId, uint256 indexed startTime, uint256 indexed endTime,uint256 time);             // Event emitted when a new season is started
    event ChestOpened(address indexed player, uint256[] indexed nftTypeIndices, uint256[] indexed tokenIds, uint256 time);      // Event emitted when a chest is opened
    event BurnOrbForLRDS(address indexed owner, uint256 indexed nftId, uint256 quality, uint256 indexed amount, uint256 time);  // Event emitted when an Orb NFT is burned for LRDS tokens
	event SetMaxNFTsWithdrawal(uint256 indexed MaxNFTsAmount, uint256 indexed time);                                            // Event emitted when the maximum NFT withdrawal limit has been updated

    /**
     * @dev Initializes the Chest contract.
     * @param initialOwner The address of the initial owner of the contract.
     * @param _factory The address of the NFT Factory contract.
     * @param _heroNft The address of the Hero NFT contract.
     * @param _bannerNft The address of the Banner NFT contract.
     * @param _orbNft The address of the Orb NFT contract.
     * @param _verifier The address of the verifier contract.
     */
    constructor(address initialOwner, address _factory, address _heroNft, address _bannerNft, address _orbNft, address _verifier) Ownable(initialOwner) {
        require(_factory   != address(0), "Banner can't be zero address");
        require(_orbNft   != address(0), "Orb can't be zero address");
        require(_verifier != address(0), "Verifier can't be zero address");
        
        nftFactory   = _factory;
        orbNft       = _orbNft;
        verifier     = _verifier;
        
        nftTypes[0] = _heroNft;
        nftTypes[1] = _bannerNft;
        nftTypes[2] = _orbNft;
    }

    /**
     * @dev Reentrancy guard modifier to prevent reentrant calls.
     */
    modifier nonReentrant() {
        require(!lock, "No reentrant call");
        lock = true;
        _;
        lock = false;
    }

    /**
     * @dev Opens a chest and mints NFTs based on the chest content.
     * @param _seasonId The ID of the current season.
     * @param _data The data containing information about the chest content.
     * @param _deadline The deadline for the signature.
     * @param _v The recovery ID.
     * @param _r The R part of the signature.
     * @param _s The S part of the signature.
     */
    function openChest(uint256 _seasonId, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_seasonId > 0, "Season id should be greater than 0!");
        require(isSeasonActive(_seasonId), "Season is not active");

        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");

        (uint256[] memory nftTypeIndices, uint256[] memory itemCodes) 
            = abi.decode(_data, (uint256[], uint256[]));

        // The number of NFT mint does not exceed the set upper limit
        require(nftTypeIndices.length <= maxNFTsWithdrawal, "Exceeds maximum allowed NFTs per withdrawal");

        // Validate chest data format
        require(nftTypeIndices.length == itemCodes.length, "Invalid data format");
        
        // Verify signature
        verifySignature(_data, _deadline, _v, _r, _s);
        uint256[] memory tokenIds = new uint256[](nftTypeIndices.length);
        
        nonce[msg.sender]++;
        
        for (uint256 i = 0; i < nftTypeIndices.length; i++) {
            uint256 nftTypeIndex = nftTypeIndices[i];

            uint256 itemCode = itemCodes[i];

            tokenIds[i] = _mint(nftTypeIndex, itemCode);
        }

        emit ChestOpened(msg.sender, nftTypeIndices, tokenIds, block.timestamp);
    }

    /**
    * @dev Internal function to mint an NFT of a specific type based on the provided index and item codes.
    * @param _nftTypeIndex The index representing the type of NFT to be minted.
    * @param _itemCodes The item codes required for minting the NFT (tokenId or quality).
    * @return The ID of the minted NFT.
    */
    function _mint(uint256 _nftTypeIndex, uint256 _itemCodes) internal returns (uint256) {
            address nftContract = nftTypes[_nftTypeIndex];
            require(nftContract != address(0), "Unsupported NFT type");
            
            uint256 tokenId = 0; // Initialize the token ID variable

            // Depending on the NFT type index, mint the corresponding type of NFT using the NFT Factory contract
            if(_nftTypeIndex == 0){
                tokenId = NftFactory(nftFactory).mintHero(msg.sender, _itemCodes);     //mint hero nft
            } else if(_nftTypeIndex == 1){
                tokenId = NftFactory(nftFactory).mintBanner(msg.sender, _itemCodes);   //mint banner nft
            } else if(_nftTypeIndex == 2){
                tokenId = NftFactory(nftFactory).mintOrb(msg.sender, _itemCodes);      //mint orb nft
            }

            return tokenId; // Return the ID of the minted NFT
    }

    /**
     * @dev Crafts a Mythic Orb NFT by sacrificing five different Orbs of qualities 1 to 5.
     * @param _seasonId The ID of the current season.
     * @param _nftIds The IDs of the NFTs used for crafting the Orb.
     * @param _quality The quality of the crafted Orb.
     * @param _deadline The deadline for the signature.
     * @param _v The recovery ID.
     * @param _r The R part of the signature.
     * @param _s The S part of the signature.
     */
    function craftOrb(uint256 _seasonId, uint256[5] memory _nftIds, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_seasonId > 0, "Season id should be greater than 0!");
        require(isSeasonActive(_seasonId), "Season is not active");
        require(_quality == 6, "The mint quality can only be an orb of 6");
        
        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");
        
        require(_nftIds.length == 5, "Must provide exactly 5 NFT IDs");

        OrbNFT nft = OrbNFT(orbNft);
        require(nft.isApprovedForAll(msg.sender, address(this)), "Contract is not approved to manage the sender's NFTs");

        // verify the signature and ownership of NFTs
        verifySignature(_nftIds, _quality, _deadline, _v, _r, _s);

        // track counts of each quality (1 to 5)
        uint256[5] memory qualityCounts;

        // verify ownership and count qualities
        for (uint256 i = 0; i < 5; i++) {
            require(nft.ownerOf(_nftIds[i]) == msg.sender, "Not the nft owner");
            uint256 nftQuality = nft.quality(_nftIds[i]);
            require(nftQuality >= 1 && nftQuality <= 5, "NFT quality must be between 1 and 5");
            qualityCounts[nftQuality - 1]++; // Increment count for this quality
        }
            
        // ensure exactly one of each quality (1 to 5)
        require(qualityCounts[0] == 1, "Missing NFT with quality 1");
        require(qualityCounts[1] == 1, "Missing NFT with quality 2");
        require(qualityCounts[2] == 1, "Missing NFT with quality 3");
        require(qualityCounts[3] == 1, "Missing NFT with quality 4");
        require(qualityCounts[4] == 1, "Missing NFT with quality 5");

        // burn the NFTs of qualities 1 to 5
        for (uint256 i = 0; i < 5; i++) {
            nft.burn(_nftIds[i]);
        }

        // mint a new Orb NFT with the specified quality
        uint256 mintedNftId = 0;
        nonce[msg.sender]++;

        mintedNftId = NftFactory(nftFactory).mintOrb(msg.sender, _quality);

        emit CraftOrb(msg.sender, mintedNftId, _quality, block.timestamp);
    }

    /**
    * @dev Burns an Orb NFT, triggering an event that facilitates obtaining LRDS tokens from a centralized backend.
    * @param _data Encoded data containing the NFT ID, quality, and amount of LRDS tokens to stake.
    * @param _deadline The timestamp by which the signature must be submitted.
    * @param _v The recovery byte of the signature.
    * @param _r The first 32 bytes of the signature.
    * @param _s The second 32 bytes of the signature.
    */
    function burnOrbForLRDS(bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        // Check if the season is not active (season has ended)
        require(!isSeasonActive(seasonId) && seasonId > 0, "Season is not end");

        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");

        (uint256 nftId, uint256 quality, uint256 amount) 
        = abi.decode(_data, (uint256, uint256, uint256));

        require(amount > 0, "Amount should be greater than 0");

        // burn the Orb NFT if the caller is its owner
        OrbNFT nft = OrbNFT(orbNft);
        require(nft.isApprovedForAll(msg.sender, address(this)), "Contract is not approved to manage the sender's NFTs");
        require(nft.ownerOf(nftId) == msg.sender, "Not the nft owner");
        require(nft.quality(nftId) == quality, "The quality of the nft to be burned is not correct");

        verifySignature(nftId, quality, amount, _deadline, _v, _r, _s);

        nonce[msg.sender]++;
        // Burn nft to get LRDS in the game. can redeem ERC20 LRDS in the game
        nft.safeTransferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, nftId);

        // The number of nft burned and the number of lrds gained by burning events are added to the game.
        emit BurnOrbForLRDS(msg.sender, nftId, quality, amount, block.timestamp);
    }

    /**
    * @dev Verifies a signature for opening a chest.
    * @param _data Encoded data to be signed.
    * @param _deadline The timestamp by which the signature must be submitted.
    * @param _v The recovery byte of the signature.
    * @param _r The first 32 bytes of the signature.
    * @param _s The second 32 bytes of the signature.
    */
    function verifySignature(bytes memory _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _data, address(this), nonce[msg.sender], _deadline, block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);

        require(recover == verifier, "Verification failed about open chest");
    }

    /**
    * @dev Verifies a signature for crafting an Orb.
    * @param _nftIds An array containing the IDs of the NFTs used for crafting.
    * @param _quality The quality of the Mythic Orb to be crafted.
    * @param _deadline The timestamp by which the signature must be submitted.
    * @param _v The recovery byte of the signature.
    * @param _r The first 32 bytes of the signature.
    * @param _s The second 32 bytes of the signature.
    */
    function verifySignature(uint256[5] memory _nftIds, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _nftIds, _quality, _deadline, address(this), nonce[msg.sender], block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed about craft Orb");
    }

    /**
    * @dev Verifies a signature for burning an Orb and staking LRDS tokens.
    * @param _nftId The ID of the Orb NFT to be burned.
    * @param _quality The quality of the Orb NFT to be burned.
    * @param _amount The amount of LRDS tokens to be staked.
    * @param _deadline The timestamp by which the signature must be submitted.
    * @param _v The recovery byte of the signature.
    * @param _r The first 32 bytes of the signature.
    * @param _s The second 32 bytes of the signature.
    */
    function verifySignature(uint256 _nftId, uint256 _quality, uint256 _amount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _nftId, _quality, _amount, _deadline, address(this), nonce[msg.sender], block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed about withdraw");
    }

    /**
    * @dev Checks if the given season is active.
    * @param _seasonId The ID of the season to be checked.
    * @return A boolean indicating whether the season is active or not.
    */
    function isSeasonActive(uint256 _seasonId) internal view returns(bool) {
        uint256 startTime = seasons[_seasonId].startTime;
        uint256 endTime = startTime + seasons[_seasonId].duration;
        return (block.timestamp >= startTime && block.timestamp <= endTime);
    }

    /**
    * @dev Starts a new season with the specified start time and duration.
    * @param _startTime The start time of the new season.
    * @param _duration The duration of the new season.
    */
    function startSeason(uint256 _startTime, uint256 _duration) external onlyOwner {
        require(_startTime > block.timestamp, "Seassion should start in the future");
        require(_duration > 0, "Season duration should be greater than 0");

      	if (seasonId > 1) {
      	    require(!isSeasonActive(seasonId),"Can't start when season is active");
      	}

      	seasonId++;
      	seasons[seasonId] = Season(_startTime, _duration);

      	emit SeasonStarted(seasonId, _startTime, _startTime + _duration, block.timestamp);
    }

    /**
    * @dev Sets the address of the verifier contract.
    * @param _verifier The address of the new verifier contract.
    */
    function setVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Verifier can't be zero address ");

        verifier = _verifier;
    }
    
    /**
    * @dev Sets the maximum number of nft that can be obtained by opening a treasure chest.
    * @param _maxNFTs The maximum number of NFTs allowed to be withdrawn.
    */
    function setMaxNFTsWithdrawal(uint256 _maxNFTs) external onlyOwner {
        require(_maxNFTs > 0, "Maximum NFTs withdrawal must be greater than zero");
        maxNFTsWithdrawal = _maxNFTs;
        
		emit SetMaxNFTsWithdrawal(_maxNFTs, block.timestamp);	  
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev encrypt token data
    /// @return encrypted data
    function onERC721Received(address, address, uint256, bytes calldata) external override pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
   
}


