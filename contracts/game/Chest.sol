// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./../nfts/HeroNFT.sol";
import "./../nfts/BannerNFT.sol";
import "./../nfts/OrbNFT.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The Royal Orb
 */
 
contract Chest is IERC721Receiver, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    bool    private lock;
    uint256 public  seasonId;
    // address public  heroNft;
    // address public  bannerNft;
    address public  orbNft;
    address public  lrds;
    address public  verifier;
    address public  bank;

    struct Season {
        uint256 startTime;
        uint256 duration;
    }

    mapping(uint256 => Season) public seasons;
    mapping(address => uint256) public nonce;
    mapping(uint256 => address) public nftTypes;

    event Mint(address indexed owner, uint256 indexed nftId, uint256 indexed quality, uint256 time);
    event SeasonStarted(uint256 indexed SeasonId, uint256 indexed startTime, uint256 indexed endTime,uint256 time);
    event Withdraw(address indexed owner, uint256 indexed nftId, uint256 quality, uint256 indexed amount, uint256 time);
    event ChestOpened(address indexed recipient, uint256[] indexed nftTypeIndices, uint256[] indexed tokenIds, uint256 timestamp);
    
    constructor(address initialOwner, address _heroNft, address _bannerNft, address _orbNft, address _lrds, address _bank, address _verifier) Ownable(initialOwner) {
        require(_heroNft   != address(0), "hero can't be zero address");
        require(_bannerNft   != address(0), "banner can't be zero address");
        require(_orbNft   != address(0), "orb can't be zero address");
        require(_lrds     != address(0), "lrds can't be zero address");
        require(_bank     != address(0), "bank can't be zero address");
        require(_verifier != address(0), "verifier can't be zero address");
        
        // heroNft      = _heroNft;
        // bannerNft    = _bannerNft;
        orbNft       = _orbNft;
        lrds         = _lrds;
        bank         = _bank;
        verifier     = _verifier;
        
        nftTypes[0] = _heroNft;
        nftTypes[1] = _bannerNft;
        nftTypes[2] = _orbNft;
    }

    modifier nonReentrant() {
        require(!lock, "no reentrant call");
        lock = true;
        _;
        lock = false;
    }

    // function openChest(bytes calldata _data, uint256 _deadline) external nonReentrant {
    //     require(_deadline >= block.timestamp, "Signature has expired");

    //     (uint256[] memory nftTypeIndices, uint256[] memory tokenIds, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) 
    //         = abi.decode(_data, (uint256[], uint256[], uint8[], bytes32[], bytes32[]));

    //     require(nftTypeIndices.length == tokenIds.length && tokenIds.length == v.length && v.length == r.length && r.length == s.length, "Invalid data format");

    //     for (uint256 i = 0; i < nftTypeIndices.length; i++) {
    //         uint256 nftTypeIndex = nftTypeIndices[i];

    //         uint256 tokenId = tokenIds[i];
    //         uint8 _v = v[i];
    //         bytes32 _r = r[i];
    //         bytes32 _s = s[i];

    //         // require(verifySignature(nftContract, msg.sender, tokenId, _deadline, _v, _r, _s), "Verification failed");

    //         _mint(nftTypeIndex, tokenId, _deadline, _v, _r, _s);
    //     }

    //     emit ChestOpened(msg.sender, nftTypeIndices, tokenIds, block.timestamp);
    // }

    // function _mint(uint256 _nftTypeIndices, uint256 _tokenId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal {
    //         address nftContract = nftTypes[_nftTypeIndices];
    //         require(nftContract != address(0), "Unsupported NFT type");

    //         if(_nftTypeIndices == 0){
    //             HeroNFT(nftContract).safeMint(msg.sender, _tokenId, _deadline, _v, _r, _s);
    //         }else if(_nftTypeIndices == 1){
    //             BannerNFT(nftContract).safeMint(msg.sender, _tokenId, _deadline, _v, _r, _s);
    //         } else if(_nftTypeIndices == 2) {
    //             OrbNFT(nftContract).safeMint(msg.sender, _tokenId, _deadline, _v, _r, _s);
    //         }
    // }
    
    // // orb nft can be cast at the start of the season
    // function mint(uint256 _seasonId, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
    //     require(_seasonId > 0, "season id should be greater than 0!");
    //     require(isSeasonActive(_seasonId), "season is not active");

    //     (uint256[5] memory nftIds, uint256 quality, uint256 deadline, uint8 v, bytes32 r, bytes32 s) 
    //     = abi.decode(_data, (uint256[5], uint256, uint256, uint8, bytes32, bytes32));

    //     require(deadline >= block.timestamp, "signature has expired");

    //     OrbNFT nft = OrbNFT(orbNft);

    //     if (quality == 6) {
    //         require(nftIds.length == 5, "must provide exactly 5 NFT IDs");

    //         // verify the signature and ownership of NFTs
    //         verifySignature(msg.sender, nftIds, quality, deadline, _v, _r, _s);

    //         // track counts of each quality (1 to 5)
    //         uint256[5] memory qualityCounts;

    //         // verify ownership and count qualities
    //         for (uint256 i = 0; i < 5; i++) {
    //             require(nft.ownerOf(nftIds[i]) == msg.sender, "not the nft owner");
    //             uint256 nftQuality = nft.quality(nftIds[i]);
    //             require(nftQuality >= 1 && nftQuality <= 5, "NFT quality must be between 1 and 5");
    //             qualityCounts[nftQuality - 1]++; // Increment count for this quality
    //         }
            
    //         // ensure exactly one of each quality (1 to 5)
    //         require(qualityCounts[0] == 1, "Missing NFT with quality 1");
    //         require(qualityCounts[1] == 1, "Missing NFT with quality 2");
    //         require(qualityCounts[2] == 1, "Missing NFT with quality 3");
    //         require(qualityCounts[3] == 1, "Missing NFT with quality 4");
    //         require(qualityCounts[4] == 1, "Missing NFT with quality 5");

    //         // burn the NFTs of qualities 1 to 5
    //         for (uint256 i = 0; i < 5; i++) {
    //             nft.burn(nftIds[i]);
    //         }
    //     } else {
    //         // For quality 1 to 5, just verify the signature without nftIds
    //         verifySignature(msg.sender, quality, deadline, _v, _r, _s);
    //     }

    //     // mint a new Orb NFT with the specified quality
    //     uint256 mintedNftId = 0;
    //     nonce[msg.sender]++;

    //     mintedNftId = nft.safeMint(msg.sender, quality, deadline, v, r, s);

    //     emit Mint(msg.sender, mintedNftId, quality, block.timestamp);
    // }

    // Open the treasure chest and get nft
    function openChest(uint256 _seasonId, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        require(_seasonId > 0, "season id should be greater than 0!");
        require(isSeasonActive(_seasonId), "season is not active");

        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");

        (uint256[] memory nftTypeIndices, uint256[] memory itemCodes) 
            = abi.decode(_data, (uint256[], uint256[]));

        // Validate chest data format
        require(nftTypeIndices.length == itemCodes.length, "Invalid data format");
        
        // Verify signature
        verifySignature(_data, _deadline, _v, _r, _s);
        
        for (uint256 i = 0; i < nftTypeIndices.length; i++) {
            uint256 nftTypeIndex = nftTypeIndices[i];

            uint256 tokenId = itemCodes[i];

            _mint(nftTypeIndex, tokenId);
        }

        emit ChestOpened(msg.sender, nftTypeIndices, itemCodes, block.timestamp);
    }

    // Depending on the type, mint has different kinds of NFTS
    function _mint(uint256 _nftTypeIndices, uint256 _itemCodes) internal {
            address nftContract = nftTypes[_nftTypeIndices];
            require(nftContract != address(0), "Unsupported NFT type");

            if(_nftTypeIndices == 0){
                HeroNFT(nftContract).mint(msg.sender, _itemCodes);   //itme code is tokenId
            } else if(_nftTypeIndices == 1){
                BannerNFT(nftContract).mint(msg.sender, _itemCodes); //itme code is tokenId
            } else if(_nftTypeIndices == 2) {
                OrbNFT(nftContract).mint(msg.sender, _itemCodes);    //itme code is quality
            }
    }

    // Combine 5 low quality Orbs into one mythic orb
    function craftOrb(uint256 _seasonId, uint256[5] memory _nftIds, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        require(_seasonId > 0, "season id should be greater than 0!");
        require(isSeasonActive(_seasonId), "season is not active");
        require(_quality == 6, "the mint quality can only be an orb of 6");
        
        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "signature has expired");
        
        require(_nftIds.length == 5, "must provide exactly 5 NFT IDs");

        OrbNFT nft = OrbNFT(orbNft);

        // verify the signature and ownership of NFTs
        verifySignature(_nftIds, _quality, _deadline, _v, _r, _s);

        // track counts of each quality (1 to 5)
        uint256[5] memory qualityCounts;

        // verify ownership and count qualities
        for (uint256 i = 0; i < 5; i++) {
            require(nft.ownerOf(_nftIds[i]) == msg.sender, "not the nft owner");
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

        mintedNftId = nft.mint(msg.sender, _quality);

        emit Mint(msg.sender, mintedNftId, _quality, block.timestamp);
    }

    //  allows users to redeem LRDS tokens by burning an Orb NFT at the end of a season
    function withdraw(bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) external {
        // Check if the season is not active (season has ended)
        require(!isSeasonActive(seasonId), "season is not end");

        (uint256 nftId, uint256 quality, uint256 amount, uint256 deadline) 
        = abi.decode(_data, (uint256, uint256, uint256, uint256));

        require(deadline >= block.timestamp, "signature has expired");
        require(amount > 0, "amount should be greater than 0");

        verifySignature(nftId, quality, amount, deadline, _v, _r, _s);

         // burn the Orb NFT if the caller is its owner
        OrbNFT nft = OrbNFT(orbNft);
        require(nft.ownerOf(nftId) == msg.sender, "not the nft owner");

        nft.burn(nftId);

        // transfer LRDS tokens from bank to the caller (msg.sender)
        IERC20 token = IERC20(lrds);
        require(token.balanceOf(bank) >= amount, "not enough token to stake");

        token.safeTransferFrom(bank, msg.sender, amount);

        emit Withdraw(msg.sender, nftId, quality, amount, block.timestamp);
    }


    // Verify signature for open chest
    function verifySignature(bytes memory _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _data, address(this), nonce[msg.sender], _deadline, block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);

        require(recover == verifier, "Verification failed about open chest");
    }

    // verify signature for quality 6 (with nftIds)
    function verifySignature(uint256[5] memory _nftIds, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _nftIds, _quality, _deadline, address(this), nonce[msg.sender], block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed");
    }

    // // verify signature for quality 1 to 5 (without nftIds)
    // function verifySignature(address _addr, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
    //     bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    //     bytes32 message = keccak256(abi.encodePacked(_addr, _quality, _deadline, address(this), nonce[_addr], block.chainid));
    //     bytes32 hash = keccak256(abi.encodePacked(prefix, message));
    //     address recover = ecrecover(hash, _v, _r, _s);
    //     require(recover == verifier, "Verification failed");
    // }

    // verify signature for withdraw token
    function verifySignature(uint256 _nftId, uint256 _quality, uint256 _amount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _nftId, _quality, _amount, _deadline, address(this), nonce[msg.sender], block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed");
    }

    // returns true if season is active
    function isSeasonActive(uint256 _seasonId) internal view returns(bool) {
        uint256 startTime = seasons[_seasonId].startTime;
        uint256 endTime = startTime + seasons[_seasonId].duration;
        return (block.timestamp >= startTime && block.timestamp <= endTime);
    }

    // Method called by the contract owner
     function startSeason(uint256 _startTime, uint256 _duration) external onlyOwner {
        require(_startTime > block.timestamp, "seassion should start in the future");
        require(_duration > 0, "season duration should be greater than 0");

      	if (seasonId > 1) {
      	    require(!isSeasonActive(seasonId),"can't start when season is active");
      	}

      	seasonId++;
      	seasons[seasonId] = Season(_startTime, _duration);

      	emit SeasonStarted(seasonId, _startTime, _startTime + _duration, block.timestamp);
    }

    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "verifier can't be zero address ");
        verifier = _verifier;
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


