// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title BLOCKLORDS
 * @dev A contract for managing House NFTs
 * @author BLOCKLORDS TEAM
 * @notice This contract facilitates the creation and management of House NFTs
 */
 
contract HouseNFT is ERC721Enumerable, Ownable {
    
    bool    private lock;                      // Reentrancy guard
    uint256 private nextTokenId;               // Counter for generating the next token ID
    string  private baseUri;                   // Base URI for token metadata
    address public  verifier;                  // Address of the verifier contract for signature verification
    address public  heroNft;                   // Address of the Hero NFT contract

    struct HouseParams {
        uint256 flagShape;
        uint256 houseSymbol;
        uint256 flagColor;
        string  houseName;
        uint256 lordNftId;
    }

    mapping(uint256 => bool) private soulbound;         // Mapping to track if a token is soulbound
    mapping(uint256 => HouseParams) public houseParams; // Mapping to store house parameters
    mapping(address => uint256) public nonce;           // Nonce for signature verification
    mapping(address => bool) public exists;             // Mapping to track if an address owns a house NFT

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);
    event SetHouse(address indexed player, uint256 indexed houseId, uint256 indexed lordNftId, uint256 time);
    event SetVerifier(address indexed verifier, uint256 indexed time);
    event SetHeroNft(address indexed heroNftAddress, uint256 indexed time);

    /**
     * @dev Initializes the contract with the provided addresses.
     * @param initialOwner The address that will become the owner of the contract.
     * @param _heroNft Address of the Hero NFT contract.
     * @param _verifier Address of the verifier for signature verification.
     */
    constructor(address initialOwner, address _heroNft, address _verifier) ERC721("Blocklords House", "BLHS") Ownable(initialOwner) {
        require(_verifier != address(0), "verifier can't be zero address");
        require(_heroNft != address(0), "hero nft address not zero");

        nextTokenId = 1;
        verifier = _verifier;
        heroNft = _heroNft;
    }

    /**
     * @dev Modifier to prevent reentrancy attacks.
     */
    modifier nonReentrant() {
        require(!lock, "no reentrant call");
        lock = true;
        _;
        lock = false;
    }

    /**
     * @dev Mints a new House NFT.
     * @param _to Address to mint the token to.
     * @param _data Encoded data containing the parameters of the house.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     * @return The ID of the minted token.
     */
    function safeMint(address _to, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant returns(uint256) {
        require(!exists[_to], "you already own the house nft");

        (uint256 flagShape, uint256 houseSymbol, uint256 flagColor, string memory houseName) 
            = abi.decode(_data, (uint256, uint256, uint256, string));

        require(_deadline >= block.timestamp, "signature has expired");
        require(flagShape > 0 && flagColor > 0 && houseSymbol > 0 &&  bytes(houseName).length > 0, "house params err");

        uint256 tokenId = nextTokenId++;
      
        // Verify the signature
        verifySignature(_to, _data, _deadline, _v, _r, _s);
        
        exists[_to]                = true;
        
        HouseParams storage house = houseParams[tokenId];
        house.flagShape           = flagShape;
        house.houseSymbol         = houseSymbol;
        house.flagColor           = flagColor;
        house.houseName           = houseName;
        house.lordNftId           = 0;

        nonce[_to]++;

        _safeMint(_to, tokenId);

        soulbound[tokenId]        = true;

        emit Minted(_to, tokenId, block.timestamp);
        return tokenId;
    }

    /**
     * @dev Sets the parameters of a House NFT.
     * @param _from Address of the token owner.
     * @param _data Encoded data containing the parameters of the house.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
    function setHouse(address _from, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        (uint256 flagShape, uint256 houseSymbol, uint256 flagColor, string memory houseName, uint256 lordNftId, uint256 houseId) 
            = abi.decode(_data, (uint256, uint256, uint256, string, uint256, uint256));

        require(_deadline >= block.timestamp, "signature has expired");
        require(IERC721(address(this)).ownerOf(houseId) == _from, "not house nft owner");
        require(flagShape > 0 && flagColor > 0 && houseSymbol > 0 &&  bytes(houseName).length > 0, "house params err");

        // Verify the signature
        verifySignature(_from, _data, _deadline, _v, _r, _s);
        
        HouseParams storage house = houseParams[houseId];
        house.flagShape           = flagShape;
        house.houseSymbol         = houseSymbol;
        house.flagColor           = flagColor;
        house.houseName           = houseName;
        house.lordNftId           = lordNftId;
        
        nonce[_from]++;
        emit SetHouse(_from, houseId, lordNftId, block.timestamp);
    }

    /**
     * @dev Verifies the signature of a transaction.
     * @param _addr The address of the signer.
     * @param _data The data being signed.
     * @param _deadline The expiry timestamp for the signature.
     * @param _v The ECDSA signature parameter v.
     * @param _r The ECDSA signature parameter r.
     * @param _s The ECDSA signature parameter s.
     */
    function verifySignature(address _addr, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
        bytes32 message         = keccak256(abi.encodePacked(nonce[_addr], _addr, _data, _deadline, address(this), block.chainid));
        bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "verification failed");
    }

    // Method called by the contract owner
    /**
     * @dev Sets the address of the verifier contract for signature verification.
     * @param _verifier The address of the new verifier contract.
     */
    function setVerifier (address _verifier) external onlyOwner {
        require(_verifier != address(0), "verifier can't be zero address ");
        verifier = _verifier;

        emit SetVerifier(_verifier, block.timestamp);
    }

    function setBaseURI(string calldata _baseUri) external onlyOwner() {
        baseUri = _baseUri;
    }

    function setHeroNft (address _nft) external onlyOwner {
        require(_nft != address(0), "verifier can't be zero address ");
        heroNft = _nft;
        
        emit SetHeroNft(_nft, block.timestamp);
    }

    // The following functions are overrides required by Solidity.
    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    function supportsInterface(bytes4 interfaceId)public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Enumerable) returns (address) {
        require(!soulbound[tokenId], "token is soulbound");
        return super._update(to, tokenId, auth);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }
}


