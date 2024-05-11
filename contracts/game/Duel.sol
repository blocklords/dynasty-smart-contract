// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./../nfts/NftFactory.sol";

/**
 *  @title BLOCKLORDS
 *  @dev Contract for managing hero duels within the Blocklords ecosystem.
 *  @author BLOCKLORDS TEAM
 *  @notice This contract facilitates the initiation and conclusion of hero duels.
 *  It also enables players to claim rewards for participating in seasonal events.
 *  Hero and banner NFTs are used as assets for dueling and rewards.
 *  ERC721 token contract addresses for hero and banner NFTs are required.
 */

contract Duel is IERC721Receiver, Pausable, Ownable {
    bool    private lock;          // Reentrancy guard
    address public  heroNft;       // Address of the hero NFT contract
    address public  verifier;      // Address of the verifier for signature verification
    address public  nftFactory;    // Address of the NFT Factory contract

    mapping(address => uint256) public playerData;                          // Player data tracking the hero NFT being used in a duel
    mapping(address => uint256) public nonce;                               // Nonce for signature verification
    mapping(uint256 => address) public nftTypes;                            // Mapping from NFT type index to its contract address
    mapping(address => mapping(uint256 => bool)) public withdrawnSeasonIds; // Tracks which seasonId each address has already withdrawn

    event StartDuel(address indexed owner, uint256 indexed nftId, uint256 time);    // Event emitted when a duel is initiated
    event FinishDuel(address indexed owner, uint256 indexed nftId, uint256 time);   // Event emitted when a duel is concluded
    event SeasonWithdraw(address indexed recipient, uint256 seasonId, uint256[] indexed nftTypeIndices, uint256[] indexed tokenIds, uint256 timestamp);  // Event emitted when a player withdraws rewards for a season
    event FactorySet(address indexed factoryAddress, uint256 indexed time);         // Event emitted when the NFT Factory contract address is set
    event NftTypeAdded(address indexed NFTAddress, uint256 indexed time);           // Event emitted when a new NFT contract address is added
    
    /**
     * @dev Constructor function to initialize the Duel contract.
     * @param initialOwner The address of the initial owner of the contract.
     * @param _heroNft The address of the Hero NFT contract.
     * @param _bannerNft The address of the Banner NFT contract.
     * @param _factory The address of the NFT Factory contract.
     * @param _verifier The address of the verifier for signature verification.
     */
    constructor(address initialOwner, address _heroNft, address _bannerNft, address _factory, address _verifier) Ownable(initialOwner) {
        require(_heroNft    != address(0), "Hero nft can't be zero address");
        require(_bannerNft  != address(0), "BannerNft can't be zero address");
        require(_factory    != address(0), "Factory can't be zero address");
        require(_verifier   != address(0), "Verifier can't be zero address");
        
        heroNft    = _heroNft;
        nftFactory = _factory;
        verifier   = _verifier;

        nftTypes[0] = _heroNft;
        nftTypes[1] = _bannerNft;
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
     * @dev Initiates a hero duel.
     * @param _from The address initiating the duel.
     * @param _nftId The ID of the hero NFT used in the duel.
     * @param _deadline The deadline for signature verification.
     * @param _v Recovery id of the signer.
     * @param _r Signature data.
     * @param _s Signature data.
     */
    function startDuel(address _from, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        require(_deadline >= block.timestamp, "Signature has expired");
        require(_nftId > 0, "Nft Id invalid");
        require(playerData[_from] == 0, "The NFT has been imported");

        IERC721 nft = IERC721(heroNft);
        require(nft.ownerOf(_nftId) == _from, "Not hero nft owner");
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_nftId, _from, address(this), nonce[_from], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about startDuel");
        }

        nonce[_from]++;
        playerData[_from] = _nftId;

        nft.safeTransferFrom(_from, address(this), _nftId);

        emit StartDuel(_from, _nftId, block.timestamp);
    }

    /**
     * @dev Concludes a hero duel.
     * @param _from The address concluding the duel.
     * @param _nftId The ID of the hero NFT used in the duel.
     * @param _deadline The deadline for signature verification.
     * @param _v Recovery id of the signer.
     * @param _r Signature data.
     * @param _s Signature data.
     */
    function finishDuel(address _from, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        require(_deadline >= block.timestamp, "Signature has expired");
        require(_nftId > 0, "Nft Id invalid");
        require(playerData[_from] == _nftId, "The nft for export is different from that for import");

        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_nftId, _from, address(this), nonce[_from], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about finishDuel");
        }

        nonce[_from]++;
        delete playerData[_from];

        IERC721 nft = IERC721(heroNft);
        nft.safeTransferFrom( address(this), _from, _nftId);

        emit FinishDuel(_from, _nftId, block.timestamp);
    }
    /**
     * @dev Claims rewards for a specific season.
     * @param _seasonId The ID of the seasonal event.
     * @param _data Data containing indices of NFT types and corresponding token IDs.     
     * @param _deadline The deadline for signature verification.
     * @param _v Recovery id of the signer.
     * @param _r Signature data.
     * @param _s Signature data.
     */
    function seasonWithdraw(uint256 _seasonId, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");

        // Check if the player has already withdrawn rewards for this season
        require(!withdrawnSeasonIds[msg.sender][_seasonId], "You have already withdrawn rewards for this season");
        
        (uint256[] memory nftTypeIndices, uint256[] memory tokenIds) 
            = abi.decode(_data, (uint256[], uint256[]));

        // Validate chest data format
        require(nftTypeIndices.length == tokenIds.length, "Invalid data format");
        
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(msg.sender, _seasonId, _data, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about season withdrow");
        }

        nonce[msg.sender]++;

        for (uint256 i = 0; i < nftTypeIndices.length; i++) {
            uint256 nftTypeIndex = nftTypeIndices[i];
            uint256 tokenId = tokenIds[i];
            _mint(nftTypeIndex, tokenId);
        }

        // Mark that the player has withdrawn rewards for this season
        withdrawnSeasonIds[msg.sender][_seasonId] = true;

        emit SeasonWithdraw(msg.sender, _seasonId, nftTypeIndices, tokenIds, block.timestamp);
    }
    
    /**
     * @dev Depending on the type, mints different kinds of NFTs.
     * @param _nftTypeIndex The index representing the type of NFT.
     * @param _tokenId The ID of the NFT token.
     */
    function _mint(uint256 _nftTypeIndex, uint256 _tokenId) internal {
            address nftContract = nftTypes[_nftTypeIndex];
            require(nftContract != address(0), "Unsupported NFT type");

            if(_nftTypeIndex == 0){
                NftFactory(nftFactory).mintHero(msg.sender, _tokenId);     //mint hero nft
            } else if(_nftTypeIndex == 1){
                NftFactory(nftFactory).mintBanner(msg.sender, _tokenId);   //mint banner nft
            }
    }

    // Method called by the contract owner
    /**
     * @dev Sets the address of the verifier for signature verification.
     * @param _verifier The address of the verifier contract.
     */
    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "Verifier can't be zero address ");
        verifier = _verifier;
    }

    /**
     * @dev Sets the address of the NFT Factory contract.
     * @param _address The address of the NFT Factory contract.
     */
    function setNftFactory(address _address) external onlyOwner {
		require(_address != address(0), "Nft factory address can not be be zero");
		nftFactory =_address;

		emit FactorySet(_address, block.timestamp);	    
    }

    function pause() public onlyOwner {
        Pausable._pause();
    }

    function unpause() public onlyOwner {
        Pausable._unpause();
    }

    /// @dev encrypt token data
    /// @return encrypted data
    function onERC721Received(address, address, uint256, bytes calldata) external override pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}


