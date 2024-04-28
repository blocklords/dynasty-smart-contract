// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 *  @title BLOCKLORDS
 *  @author BLOCKLORDS TEAM
 *  @notice The Hero missions
 */
 
contract Missions is IERC721Receiver, Pausable, Ownable {

    bool    private lock;
    address public  heroNft;
    address public  verifier;

    mapping(address => mapping(uint256 => uint256[3])) public playerTeams;
    mapping(address => uint256) public nonce;

    event StartMissions(address indexed owner, uint256 indexed teamId, uint256 nfts0, uint256 nfts1, uint256 nfts2, uint256 time);
    event FinishMissions(address indexed owner, uint256 indexed teamId, uint256 nfts0, uint256 nfts1, uint256 nfts2, uint256 time);
    
    constructor(address initialOwner, address _heroNft, address _verifier) Ownable(initialOwner) {
        require(_heroNft != address(0), "hero nft address not zero");
        require(_verifier != address(0), "verifier can't be zero address");
        
        heroNft = _heroNft;
        verifier    = _verifier;
    }

    modifier nonReentrant() {
        require(!lock, "no reentrant call");
        lock = true;
        _;
        lock = false;
    }

    function startMissions(address _from, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        (uint256 teamId, uint256[3] memory nftIds, uint256 deadline) 
            = abi.decode(_data, (uint256, uint256[3], uint256));

        require(deadline >= block.timestamp, "signature has expired");

        // ensure the number of NFTs is between 1 and 3
        require(nftIds.length > 0 && nftIds.length <=3, "invalid number of nfts");

        bool deposit = false;
        for (uint256 i = 0; i < nftIds.length; i++) {
            // ensure the teamId is not already in use
            require(playerTeams[_from][teamId][i] == 0, "this team already exists");

            // verify ownership of NFTs
            if (nftIds[i] != 0) {
                require(IERC721(heroNft).ownerOf(nftIds[i]) == _from, "hero NFT does not belong to sender");
                deposit = true;
            }
        }

        // at least one NFT must be deposited
        require(deposit, "one nft must be deposited");

        // verify the signature and ownership of NFTs
        verifySignature(_from, _data, _v, _r, _s);

        nonce[_from]++;
        // store the NFT IDs under the teamId
        playerTeams[_from][teamId] = nftIds;

        for (uint256 i = 0; i < nftIds.length; i++) {
            if (nftIds[i] != 0) {
                IERC721(heroNft).safeTransferFrom(_from, address(this), nftIds[i]);
            }
        }

        emit StartMissions(_from, teamId, nftIds[0], nftIds[1], nftIds[2], block.timestamp);
    }

    function finishMissions(address _from, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant{
        (uint256 teamId, uint256 deadline) 
            = abi.decode(_data, (uint256, uint256));

        require(deadline >= block.timestamp, "signature has expired");

        uint256[3] memory nftIds = playerTeams[_from][teamId];
        
        // ensure the team exists
        bool exist = false;
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (playerTeams[_from][teamId][i] != 0) {
                exist = true; // found a valid NFT ID
                break;
            }
        }
        require(exist, "this team does not exist");

        // ensure the number of NFTs is between 1 and 3
        require(nftIds.length > 0 && nftIds.length <=3, "invalid number of nfts");
        
        // verify the signature
        verifySignature(_from, _data, _v, _r, _s);

        nonce[_from]++;

        for (uint256 i = 0; i < nftIds.length; i++) {
            if (playerTeams[_from][teamId][i] != 0) {
                // transfer all NFTs in playerTeams[_from][teamId] back to the sender (_from)
                IERC721(heroNft).safeTransferFrom(address(this), _from, nftIds[i]);
            }
        }

        // remove the team information
        delete playerTeams[_from][teamId];

        emit FinishMissions(_from, teamId, nftIds[0], nftIds[1], nftIds[2], block.timestamp);
    }

    // Verify signature and hero ownership
    function verifySignature(address _addr, bytes calldata _data, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(_addr, _data, address(this), nonce[_addr], block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed");
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


