// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../nfts/OrbNFT.sol";

/**
 * @title BLOCKLORDS
 * @dev This contract manages Orb (ERC721) staking within a gaming ecosystem.
 * @author BLOCKLORDS TEAM
 * @notice Players can stake and unstake Orbs for gaming purposes. Each staking action is recorded with the NFT IDs and the time of staking. 
   Staked Orbs have a lock duration of 13 weeks before they can be unstaked. 
   The contract also includes signature verification to ensure the validity of staking and unstaking actions.
 */
contract OrbLock is IERC721Receiver, Pausable, Ownable {
    bool    private lock;                                   // Reentrancy guard
    uint256 public seasonId;                                // ID of the current season
    address public orbNft;                                  // Address of the Orb NFT contract
    address public verifier;                                // Address of the verifier for signature verification
    // uint256 public constant lockDuration  = 7862400;     // Lock duration in seconds (13 weeks)
    uint256 public  lockDuration  = 7862400;                // Lock duration in seconds (13 weeks)

    struct Season {
        uint256 startTime;                                  // Start time of the season
        uint256 duration;                                   // Duration of the season
    }

    //Struct to store information about a player's stake.
    struct StakeInfo {
        uint256[2] nftIds;                                   // Array of NFT IDs staked by the player
        uint256 stakeTime;                                  // Timestamp of when the NFTs were staked
    }

    mapping(uint256 => Season) public seasons;                             // Mapping of season IDs to their details
    mapping(address => mapping(uint256 => StakeInfo)) public playerStakes; // Player data tracking the Orb NFTs being staked
    mapping(address => uint256) public nonce;                              // Nonce for signature verification

    event StakeOrb(address indexed owner, uint256 seasonId, uint256[2]  orbNfts, uint256 indexed quality, uint256 stakeIndex, uint256 indexed time);    // Event emitted when an Orb is staked
    event UnstakeOrb(address indexed owner, uint256[2] orbNfts, uint256 indexed stakeIndex, uint256 indexed time);                                      // Event emitted when an Orb is unstaked                             // Event emitted when an NFT is minted
    event SeasonStarted(uint256 indexed seasonId, uint256 indexed startTime, uint256 indexed endTime,uint256 time);         

    /**
     * @dev Constructor function to initialize the OrbLock contract.
     * @param _orbNft The address of the Orb NFT contract.
     * @param _verifier The address of the verifier for signature verification.
     */
    constructor(address initialOwner, address _orbNft, address _verifier) Ownable(initialOwner) {
        require(_orbNft != address(0), "Orb NFT address cannot be zero");
        require(_verifier   != address(0), "Verifier can't be zero address");
        
        orbNft = _orbNft;
        verifier   = _verifier;
    }

    /**
     * @dev Reentrancy guard modifier to prevent reentrant calls.
     */
    modifier nonReentrant() {
        require(!lock, "No reentrant call");
        lock = true;
        _;
        lock = false;
    }

    /**
     * @dev Allows a player to stake Orbs into the pool.
     * @param _seasonId The ID of the current season.
     * @param _data The IDs of the orb NFTs to stake.
     * @param _deadline The deadline for signature verification.
     * @param _v Recovery id of the signer.
     * @param _r Signature data.
     * @param _s Signature data.
     */
    function stakeOrb(uint256 _seasonId, bytes calldata _data, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_seasonId > 0, "Season id should be greater than 0!");
        require(_deadline >= block.timestamp, "Signature has expired");

        (uint256[2] memory nftIds, uint256 quality, uint256 stakeIndex) 
            = abi.decode(_data, (uint256[2], uint256, uint256));

        require(quality >= 4 && quality <= 6, "Invalid quality");

        require(nftIds.length > 0 && nftIds.length <= 2, "The number of stake orbs is wrong");// Limit the number of NFTs staked at once
        require(playerStakes[msg.sender][stakeIndex].stakeTime == 0, "Stake index already exists"); // Ensure unique stakeIndex

        // Check all orbs are of the required quality
        for (uint256 i = 0; i < nftIds.length; i++) {
            // verify ownership of NFTs
            if (nftIds[i] != 0) {
                require(OrbNFT(orbNft).quality(nftIds[i]) == quality, "Orb quality does not match");
                require(IERC721(orbNft).ownerOf(nftIds[i]) == msg.sender, "Not Orb NFT owner");
            }
        }
        
        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(msg.sender, _seasonId, _data, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about stake Orb");
        }

        nonce[msg.sender]++;

        // Update stake mapping
        playerStakes[msg.sender][stakeIndex] = StakeInfo({
            nftIds: nftIds,
            stakeTime: block.timestamp
        });

        // Perform stake operation
        for (uint256 i = 0; i < nftIds.length; i++) {
            // Transfer Orb NFT to this contract
            if (nftIds[i] != 0) {
                IERC721(orbNft).safeTransferFrom(msg.sender, address(this), nftIds[i]);
            }
        }

        emit StakeOrb(msg.sender, _seasonId, nftIds, quality, stakeIndex, block.timestamp);
    }

    /**
     * @dev Allows a player to unstake their Orbs from the pool.
     * @param _stakeIndex The index of the stake to unstake.
     * @param _deadline The deadline for signature verification.
     * @param _v Recovery id of the signer.
     * @param _r Signature data.
     * @param _s Signature data.
     */
    function unstakeOrb(uint256 _stakeIndex, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_deadline >= block.timestamp, "Signature has expired");

        StakeInfo storage stake = playerStakes[msg.sender][_stakeIndex];
        require(stake.stakeTime != 0, "No Orbs staked with this index");
        require(block.timestamp >= stake.stakeTime + lockDuration, "Lock period has not ended");

        // Verify signature
        {
            bytes memory prefix = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, _stakeIndex, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about unstake Orb");
        }
        
        nonce[msg.sender]++;

        uint256[2] memory orbNfts = stake.nftIds;

        for (uint256 i = 0; i < orbNfts.length; i++) {
            if (orbNfts[i] != 0) {
                IERC721(orbNft).safeTransferFrom(address(this), msg.sender, orbNfts[i]);
            }
        }

        delete playerStakes[msg.sender][_stakeIndex];

        emit UnstakeOrb(msg.sender, orbNfts, _stakeIndex, block.timestamp);
    }

    /**
    * @dev Starts a new season with the specified start time and duration.
    * @param _startTime The start time of the new season.
    * @param _duration The duration of the new season.
    */
    function startSeason(uint256 _startTime, uint256 _duration) external onlyOwner {
        require(_startTime > block.timestamp, "Seassion should start in the future");
        require(_duration > 0, "Season duration should be greater than 0");

        if (seasonId > 1) {
            require(!isSeasonActive(seasonId),"Can't start when season is active");
        }

        seasonId++;
        seasons[seasonId] = Season(_startTime, _duration);

        emit SeasonStarted(seasonId, _startTime, _startTime + _duration, block.timestamp);
    }

    /**
    * @dev Checks if the given season is active.
    * @param _seasonId The ID of the season to be checked.
    * @return A boolean indicating whether the season is active or not.
    */
    function isSeasonActive(uint256 _seasonId) internal view returns(bool) {
        uint256 startTime = seasons[_seasonId].startTime;
        uint256 endTime = startTime + seasons[_seasonId].duration;
        return (block.timestamp >= startTime && block.timestamp <= endTime);
    }

    /**
     * @dev Sets a new verifier address.
     * @param _verifier The new verifier address.
     */
    function setVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Verifier can't be zero address");
        verifier = _verifier;
    }
    
    /**
     * @dev Retrieves the stake information for a specific player and stake index.
     * @param player The address of the player whose stake information is being queried.
     * @param stakeIndex The index of the stake for which information is being retrieved.
     * @return nftIds An array of NFT IDs associated with the specified stake.
     * @return stakeTime The timestamp when the NFTs were staked.
     */
    function getStakeInfo(address player, uint256 stakeIndex) public view returns (uint256[2] memory nftIds, uint256 stakeTime) {
        StakeInfo storage stake = playerStakes[player][stakeIndex];
        return (stake.nftIds, stake.stakeTime);
    }

    /**
    * @dev Sets the lock duration for staked NFTs.
    * @param _lockDuration The new lock duration in seconds.
    */
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        require(_lockDuration > 0, "lockDuration must be greater than 0");
        lockDuration = _lockDuration;
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev ERC721 receiver function
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
