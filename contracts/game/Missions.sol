// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title BLOCKLORDS
 * @dev This contract provides functionality for managing hero missions, including starting and finishing missions.
 * @author BLOCKLORDS TEAM
 * @notice Contract for managing hero missions within the Blocklords ecosystem.
 */
 
contract Missions is IERC721Receiver, Pausable, Ownable {

    bool    private lock;           // Reentrancy guard
    address public  heroNft;      // Address of the HERO NFT contract
    address public  verifier;     // Address of the verifier for signature verification

    mapping(address => mapping(uint256 => uint256[3])) public playerTeams;  // Mapping of player addresses to their teams
    mapping(address => uint256) public nonce;                               // Nonce for signature verification

    event StartMissions(address indexed owner, uint256 indexed teamId, uint256 nfts0, uint256 nfts1, uint256 nfts2, uint256 time);  // Event emitted when a mission starts
    event FinishMissions(address indexed owner, uint256 indexed teamId, uint256 nfts0, uint256 nfts1, uint256 nfts2, uint256 time); // Event emitted when a mission finishes
    
    /**
     * @dev Constructs the Missions contract.
     * @param initialOwner The initial owner of the contract.
     * @param _heroNft The address of the Hero NFT contract.
     * @param _verifier The address of the verifier contract.
     */
    constructor(address initialOwner, address _heroNft, address _verifier) Ownable(initialOwner) {
        require(_heroNft != address(0), "Hero nft address not zero");
        require(_verifier != address(0), "Verifier can't be zero address");
        
        heroNft = _heroNft;
        verifier    = _verifier;
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
     * @dev Starts the missions for a player.
     * @param _from The address initiating the mission.
     * @param _data Encoded data containing the mission parameters.
     * @param _deadline The deadline for the mission signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
    function startMissions(address _from, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        (uint256 teamId, uint256[3] memory nftIds) 
            = abi.decode(_data, (uint256, uint256[3]));

        require(_deadline >= block.timestamp, "signature has expired");

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
        verifySignature(_from, _data, _deadline, _v, _r, _s);

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

    /**
     * @dev Completes the missions for a player.
     * @param _from The address initiating the mission completion.
     * @param _data Encoded data containing the mission parameters.
     * @param _deadline The deadline for the mission completion signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
    function finishMissions(address _from, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        (uint256 teamId) 
            = abi.decode(_data, (uint256));

        require(_deadline >= block.timestamp, "signature has expired");

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
        verifySignature(_from, _data, _deadline, _v, _r, _s);

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

    /**
     * @dev Verifies the signature for starting or finishing missions.
     * @param _addr The address of the player initiating the mission or mission completion.
     * @param _data Encoded data containing the mission parameters.
     * @param _deadline The deadline for the mission signature.
     * @param _v ECDSA signature parameter v.
     * @param _r ECDSA signature parameter r.
     * @param _s ECDSA signature parameter s.
     */
    function verifySignature(address _addr, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal view {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 message = keccak256(abi.encodePacked(_addr, _data, _deadline, address(this), nonce[_addr], block.chainid));
        bytes32 hash = keccak256(abi.encodePacked(prefix, message));
        address recover = ecrecover(hash, _v, _r, _s);
        require(recover == verifier, "Verification failed");
    }

    // Method called by the contract owner
    /**
     * @dev Sets the verifier address for signature verification.
     * @param _verifier The verifier address to set.
     */
    function setVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "verifier can't be zero address ");
        verifier = _verifier;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev encrypt token data
    /// @return encrypted data
    function onERC721Received(address, address, uint256, bytes calldata) external override pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
   
}


