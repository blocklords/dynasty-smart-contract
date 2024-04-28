// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The BLCK token
 */
 
contract BannerNFT is ERC721, ERC721Burnable, ERC721Enumerable, Ownable {

    string private baseUri;
    address public verifier;

    mapping(address => uint256) public nonce;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);
    event SetVerifier(address indexed verifier, uint256 indexed time);

    constructor(address initialOwner, address _verifier) ERC721("Blocklords Banners", "BLCK") Ownable(initialOwner) {
        require(_verifier != address(0), "verifier can't be zero address");

        verifier = _verifier;
    }

    function safeMint(address _to, uint256 _tokenId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external returns(uint256) {
        require(_deadline >= block.timestamp, "signature has expired");
        
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_to, _tokenId, address(this), nonce[_to], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about mint banner nft");
        }

        _safeMint(_to, _tokenId);
        nonce[_to]++;
        
        emit Minted(_to, _tokenId, block.timestamp);
        return _tokenId;
    }

    // Method called by the contract owner
    function setBaseURI(string calldata _baseUri) external onlyOwner() {
        baseUri = _baseUri;
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


