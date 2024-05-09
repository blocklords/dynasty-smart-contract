// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./../nfts/NftFactory.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The Hero duel
 */
 
contract Duel is IERC721Receiver, Pausable, Ownable {
    bool    private lock;
    address public  heroNft;
    address public  verifier;
    address public  nftFactory;

    mapping(address => uint256) public playerData;
    mapping(address => uint256) public nonce;
    mapping(uint256 => address) public nftTypes;
    mapping(address => mapping(uint256 => bool)) public withdrawnSeasonIds; //to track which seasonId each address has already withdrawn

    event StartDuel(address indexed owner, uint256 indexed nftId, uint256 time);
    event FinishDuel(address indexed owner, uint256 indexed nftId, uint256 time);
    event SeasonWithdrow(address indexed recipient, uint256 seasonId, uint256[] indexed nftTypeIndices, uint256[] indexed tokenIds, uint256 timestamp);
    event FactorySet(address indexed FactoryAddress, uint256 indexed time);
    event NftTypeAdded(address indexed NFTAddress, uint256 indexed time);
    
    constructor(address initialOwner, address _heroNft, address _bannerNft, address _factory, address _verifier) Ownable(initialOwner) {
        require(_heroNft    != address(0), "hero nft address not zero");
        require(_bannerNft  != address(0), "bannerNft nft address not zero");
        require(_factory    != address(0), "factory nft address not zero");
        require(_verifier   != address(0), "verifier can't be zero address");
        
        heroNft    = _heroNft;
        nftFactory = _factory;
        verifier   = _verifier;

        nftTypes[0] = _heroNft;
        nftTypes[1] = _bannerNft;
    }

    modifier nonReentrant() {
        require(!lock, "no reentrant call");
        lock = true;
        _;
        lock = false;
    }

    function startDuel(address _from, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        require(_deadline >= block.timestamp, "signature has expired");
        require(_nftId > 0, "nft Id invalid");
        require(playerData[_from] == 0, "the NFT has been imported");

        IERC721 nft = IERC721(heroNft);
        require(nft.ownerOf(_nftId) == _from, "not hero nft owner");
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_nftId, _from, address(this), nonce[_from], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "verification failed about startDuel");
        }

        nonce[_from]++;
        playerData[_from] = _nftId;

        nft.safeTransferFrom(_from, address(this), _nftId);

        emit StartDuel(_from, _nftId, block.timestamp);
    }

    function finishDuel(address _from, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        require(_deadline >= block.timestamp, "signature has expired");
        require(_nftId > 0, "nft Id invalid");
        require(playerData[_from] == _nftId, "the nft for export is different from that for import");

        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_nftId, _from, address(this), nonce[_from], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "verification failed about finishDuel");
        }

        nonce[_from]++;
        delete playerData[_from];

        IERC721 nft = IERC721(heroNft);
        nft.safeTransferFrom( address(this), _from, _nftId);

        emit FinishDuel(_from, _nftId, block.timestamp);
    }

    //Earn season rewards such as hero NFT, banner NFT. (players pay gas)
    function seasonWithdrow(uint256 _seasonId, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
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

            require(recover == verifier, "verification failed about season withdrow");
        }

        for (uint256 i = 0; i < nftTypeIndices.length; i++) {
            uint256 nftTypeIndex = nftTypeIndices[i];
            uint256 tokenId = tokenIds[i];
            _mint(nftTypeIndex, tokenId);
        }

        // Mark that the player has withdrawn rewards for this season
        withdrawnSeasonIds[msg.sender][_seasonId] = true;

        emit SeasonWithdrow(msg.sender, _seasonId, nftTypeIndices, tokenIds, block.timestamp);
    }
    
    // Depending on the type, mint has different kinds of NFTS
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
    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "verifier can't be zero address ");
        verifier = _verifier;
    }

    function setNftFactory(address _address) external onlyOwner {
		require(_address != address(0), "nft factory address can not be be zero");
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


