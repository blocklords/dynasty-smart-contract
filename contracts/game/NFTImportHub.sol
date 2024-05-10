// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title BLOCKLORDS
 * @dev Contract for importing Hero NFTs and Banner NFTs, providing signature verification and ownership transfer.
 * @author BLOCKLORDS TEAM
 * @notice This contract allows users to import Hero and Banner NFTs by verifying signatures and transferring ownership.
 */

contract NFTImportHub is IERC721Receiver, Pausable, Ownable {

    bool    private lock;                      // Reentrancy guard
    address public  heroNft;                   // Address of the Hero NFT contract
    address public  bannerNft;                 // Address of the Banner NFT contract
    address public  verifier;                  // Address of the verifier for signature verification

    mapping(address => uint256) public nonce;  // Nonce for signature verification

	event ImportHeroNft(address indexed user, uint256 nft1, uint256 nft2, uint256 nft3, uint256 nft4, uint256 nft5, uint256 indexed time);   // Event emitted when importing Hero NFTs.
	event ImportBannerNft(address indexed user, uint256 nft1, uint256 nft2, uint256 nft3, uint256 nft4, uint256 nft5, uint256 indexed time); // Event emitted when importing Banner NFTs.

    /**
     * @dev Initializes the contract with the provided addresses.
     * @param initialOwner The address that will become the owner of the contract.
     * @param _heroNft Address of the Hero NFT contract.
     * @param _bannerNft Address of the Banner NFT contract.
     * @param _verifier Address of the verifier for signature verification.
     */
    constructor(address initialOwner, address _heroNft, address _bannerNft, address _verifier) Ownable(initialOwner) {
        require(_heroNft != address(0), "hero nft address not zero");
        require(_verifier != address(0), "verifier can't be zero address");
        
        bannerNft = _bannerNft;
        heroNft   = _heroNft;
        verifier  = _verifier;
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
     * @dev Imports Hero NFTs based on the provided data and signature.
     * @param _data Encoded data containing the IDs of Hero NFTs to import.
     * @param _deadline Expiry timestamp for the signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
	function importHeroNft(bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");

        // Decode the data containing NFT IDs
        (uint256[5] memory _nft) = abi.decode(_data, (uint256[5]));

        // Verify the signature
        verifySignature(_data, _deadline, _v, _r, _s);
        
        nonce[msg.sender]++;

        IERC721 nft = IERC721(heroNft);

        // Transfer the NFTs to the contract
		for(uint i = 0; i < 5; i++){
			if(_nft[i] > 0){
				require(nft.ownerOf(_nft[i]) == msg.sender, "not hero owner");
				nft.safeTransferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, _nft[i]);
			}
		}
		emit ImportHeroNft(msg.sender, _nft[0], _nft[1], _nft[2], _nft[3], _nft[4], block.timestamp);
	}

    /**
     * @dev Imports Banner NFTs based on the provided data and signature.
     * @param _data Encoded data containing the IDs of Banner NFTs to import.
     * @param _deadline Expiry timestamp for the signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
	function importBannerNft(bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
        // Ensure signature has not expired
        require(_deadline >= block.timestamp, "Signature has expired");

        // Decode the data containing NFT IDs
        (uint256[5] memory _nft) = abi.decode(_data, (uint256[5]));

        // Verify the signature
        verifySignature(_data, _deadline, _v, _r, _s);

        nonce[msg.sender]++;

        IERC721 nft = IERC721(heroNft);

        // Transfer the NFTs to the contract
		for(uint i = 0; i < 5; i++){
			if(_nft[i] > 0){
				require(nft.ownerOf(_nft[i]) == msg.sender, "not banner owner");
				nft.safeTransferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, _nft[i]);
			}
		}
		emit ImportBannerNft(msg.sender, _nft[0], _nft[1], _nft[2], _nft[3], _nft[4], block.timestamp);
	}

    /**
     * @dev Verifies the provided signature.
     * @param _data Encoded data used for signature.
     * @param _deadline Expiry timestamp for the signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
    function verifySignature(bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(msg.sender, _data, address(this), nonce[msg.sender], _deadline, block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed");
    }

    /**
     * @dev Sets the verifier address used for signature verification.
     * @param _verifier The new verifier address.
     */
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