// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The BLHE token
 */
 
contract HeroNFT is ERC721, ERC721Burnable, ERC721Enumerable, Ownable {

    string private baseUri;
    address public verifier;

    mapping(address => uint256) public nonce;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 indexed time);
    event SetVerifier(address indexed verifier, uint256 indexed time);

    constructor(address initialOwner, address _verifier) ERC721("Blocklords Heroes", "BLHE") Ownable(initialOwner) {
        require(_verifier != address(0), "verifier can't be zero address");

        verifier = _verifier;
    }
    
    function safeMint(address _to, uint256 _tokenId, uint8 _v, bytes32 _r, bytes32 _s) external returns(uint256) {
        
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_to, _tokenId, address(this), msg.sender, nonce[msg.sender]));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about mint house nft");
        }

        _safeMint(_to, _tokenId);
        nonce[msg.sender]++;
        
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


