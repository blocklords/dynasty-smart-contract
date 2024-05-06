// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The ORB token
 */
 
contract OrbNFT is ERC721, ERC721Burnable, ERC721Enumerable, Ownable {

    bool    private lock;
    uint256 private nextTokenId;
    string  private baseUri;
    address public  verifier;
    address private factory;

    // tokenId mapping to quality (tokenId => quality), quality represented by numbers (1 to 6)
    mapping(uint256 => uint256) public quality;

    // quality limits (maximum supply per quality)
    mapping(uint256 => uint256) public qualityLimit;
    mapping(address => uint256) public nonce;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);
    event SetFactory(address indexed factory, uint256 indexed time);
    event SetVerifier(address indexed verifier, uint256 indexed time);

    constructor(address initialOwner, address _verifier) ERC721("Blocklords Orbs", "ORB") Ownable(initialOwner) {
        require(_verifier != address(0), "verifier can't be zero address");

        nextTokenId = 1;
        verifier    = _verifier;
        factory     = initialOwner;

        // set quality limits
        qualityLimit[1] = 10000;
        qualityLimit[2] = 3000;
        qualityLimit[3] = 1000;
        qualityLimit[4] = 500;
        qualityLimit[5] = 200;
        qualityLimit[6] = 100;
    }
    
    modifier nonReentrant() {
        require(!lock, "no reentrant call");
        lock = true;
        _;
        lock = false;
    }
    
    modifier onlyFactory() {
        require(factory == _msgSender(), "only NFT Factory can call the method");
        _;
    }
    
    function safeMint(address _to, uint256 _quality, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant returns(uint256) {
        require(_quality >= 1 && _quality <= 6, "invalid quality");
        require(_deadline >= block.timestamp, "signature has expired");
        require(qualityLimit[_quality] > 0, "quality has reached its limit");

        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_to, _quality, address(this), nonce[_to], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about mint hero nft");
        }

        uint256 _tokenId = nextTokenId++;

        // decrease quality limit
        qualityLimit[_quality]--;
        quality[_tokenId] = _quality;
        nonce[_to]++;

        _safeMint(_to, _tokenId);
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }

    
    function mint(address _to, uint256 _quality) external onlyFactory nonReentrant returns(uint256) {
        require(_quality >= 1 && _quality <= 6, "invalid quality");
        require(qualityLimit[_quality] > 0, "quality has reached its limit");

        uint256 _tokenId = nextTokenId++;

        // decrease quality limit
        qualityLimit[_quality]--;
        quality[_tokenId] = _quality;
        nonce[_to]++;

        _safeMint(_to, _tokenId);
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }

    // Method called by the contract owner
    function setBaseURI(string calldata _baseUri) external onlyOwner() {
        baseUri = _baseUri;
    }

    function setFactory(address _factory) public onlyOwner {
        require(_factory != address(0), "factory can't be zero address ");
	    factory = _factory;

        emit SetFactory(_factory, block.timestamp);
    }


    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "verifier can't be zero address ");
        verifier = _verifier;

        emit SetVerifier(_verifier, block.timestamp);
    }

    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }
}


