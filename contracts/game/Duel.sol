// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The Hero duel
 */
 
contract Duel is IERC721Receiver, Pausable, Ownable {

    address public heroNft;
    address public verifier;

    mapping(address => uint256) public playerData;
    mapping(address => uint256) public nonce;

    event StartDuel(address indexed owner, uint256 indexed nftId, uint256 time);
    event FinishDuel(address indexed owner, uint256 indexed nftId, uint256 time);
    
    constructor(address initialOwner, address _heroNft, address _verifier) Ownable(initialOwner) {
        require(_heroNft != address(0), "hero nft address not zero");
        require(_verifier != address(0), "verifier can't be zero address");
        
        heroNft = _heroNft;
        verifier    = _verifier;
    }

    function startDuel(address _from, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
        require(_deadline >= block.timestamp, "signature has expired");
        require(_nftId > 0, "nft Id invalid");
        require(playerData[_from] == 0, "the NFT has been imported");

        IERC721 nft = IERC721(heroNft);
        require(nft.ownerOf(_nftId) == _from, "not hero nft owner");
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_nftId, _from, address(this), nonce[_from], _deadline));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "verification failed about startDuel");
        }

        nft.safeTransferFrom(_from, address(this), _nftId);

        nonce[_from]++;
        playerData[_from] = _nftId;

        emit StartDuel(_from, _nftId, block.timestamp);
    }

    function finishDuel(address _from, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
        require(_deadline >= block.timestamp, "signature has expired");
        require(_nftId > 0, "nft Id invalid");
        require(playerData[_from] == _nftId, "the nft for export is different from that for import");

        IERC721 nft = IERC721(heroNft);
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(_nftId, _from, address(this), nonce[_from], _deadline));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "verification failed about finishDuel");
        }

        nft.safeTransferFrom( address(this), _from, _nftId);

        nonce[_from]++;
        delete playerData[_from];

        emit FinishDuel(_from, _nftId, block.timestamp);
    }

    // Method called by the contract owner
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


