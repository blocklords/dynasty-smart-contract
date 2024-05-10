// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title BLOCKLORDS
 * @dev This contract provides functionality for minting, burning, and managing Blocklords Hero NFTs.
 * @author BLOCKLORDS TEAM
 * @notice ERC721 token contract representing the Blocklords Heroes (BLHE) token.
 */
 
contract HeroNFT is ERC721, ERC721Burnable, ERC721Enumerable, Ownable {

    bool    private lock;           // Reentrancy guard
    string  private baseUri;        // Base URI for token metadata
    address public  verifier;       // Address of the verifier for signature verification
    address private factory;        // Address of the NFT Factory contract

    mapping(address => uint256) public nonce;    // Nonce for signature verification

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);  // Event emitted when a new token is minted
    event SetFactory(address indexed factory, uint256 indexed time);                  // Event emitted when the factory address is set
    event SetVerifier(address indexed verifier, uint256 indexed time);                // Event emitted when the verifier address is set
    event Burned(address indexed owner, uint256 indexed tokenId, uint256 time);       // Event emitted when a token is burned

    /**
     * @dev Constructor function to initialize the HeroNFT contract.
     * @param initialOwner The address that will be set as the initial owner of the contract.
     * @param _verifier The address of the verifier contract used for signature verification.
     */
    constructor(address initialOwner, address _verifier) ERC721("Blocklords Heroes", "BLHE") Ownable(initialOwner) {
        require(_verifier != address(0), "Verifier can't be zero address");

        verifier = _verifier;
    }
    
    /**
     * @dev Modifier to prevent reentrancy attacks.
     */
    modifier nonReentrant() {
        require(!lock, "No reentrant call");
        lock = true;
        _;
        lock = false;
    }

    /**
     * @dev Modifier to allow only the NFT Factory contract to call the method.
     */
    modifier onlyFactory() {
        require(factory == _msgSender(), "Only NFT factory can call the method");
        _;
    }
    
    /**
     * @dev Safely mints a new Hero NFT.
     * @param _to Address to mint the token to.
     * @param _tokenId ID of the token to mint.
     * @param _deadline Expiry timestamp for the signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     * @return The ID of the minted token.
     */
    function safeMint(address _to, uint256 _tokenId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant returns (uint256) {
        require(_deadline >= block.timestamp, "Signature has expired");

        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_to, _tokenId, address(this), nonce[_to], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about mint hero nft");
        }

        nonce[_to]++;

        _safeMint(_to, _tokenId);
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }
    
    /**
     * @dev Mints a new Hero NFT.
     * @param _to Address to mint the token to.
     * @param _tokenId ID of the token to mint.
     * @return The ID of the minted token.
     */
    function mint(address _to, uint256 _tokenId) external onlyFactory nonReentrant returns (uint256) {     
        nonce[_to]++;

        _safeMint(_to, _tokenId);
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }

    /**
     * @dev Burns a Hero NFT.
     * @param _tokenId ID of the token to burn.
     */
    function burn(uint256 _tokenId) public override nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner of this token");
        _burn(_tokenId);

        emit Burned(msg.sender, _tokenId, block.timestamp);
    }

    // Method called by the contract owner
    /**
     * @dev Sets the base URI for token metadata.
     * @param _baseUri The base URI to set.
     */
    function setBaseURI(string calldata _baseUri) external onlyOwner() {
        baseUri = _baseUri;
    }

    /**
     * @dev Sets the address of the verifier for signature verification.
     * @param _verifier The address of the verifier contract.
     */
    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "Verifier can't be zero address ");
        verifier = _verifier;

        emit SetVerifier(_verifier, block.timestamp);
    }

    /**
     * @dev Sets the address of the NFT Factory contract.
     * @param _factory The address of the NFT Factory contract.
     */
    function setFactory(address _factory) public onlyOwner {
        require(_factory != address(0), "Factory can't be zero address ");
	    factory = _factory;

        emit SetFactory(_factory, block.timestamp);
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


