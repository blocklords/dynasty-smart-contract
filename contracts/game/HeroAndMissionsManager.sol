// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../manage/Stake.sol";

/**
 * @title BLOCKLORDS
 * @dev This contract is responsible for managing heroes and missions within the game ecosystem.
 * @author BLOCKLORDS TEAM
 * @notice  It includes functionalities to restore health to heroes, refresh missions, and handle 
 *  LRDS tokens for buffs by consuming or staking them. 
 *  It also includes signature verification to ensure that all critical operations are 
 *  authorized by a trusted verifier.
 */
contract HeroAndMissionsManager is Pausable, Ownable {
    Stake public stakeContract;               // Contract that manages staking of LRDS tokens

    address public hero;                      // Address of the Hero NFT contract
    address public lrds;                      // Address of the LRDS token contract
    address public treasury;                  // Address where LRDS tokens are sent
    address public verifier;                  // Address of the verifier for signature verification
    uint256 public maxHeroesCount;            // Maximum number of heroes that can be managed

    bool private lock;                        // Reentrancy guard flag

    mapping(address => uint256) public nonce; // Nonce for signature verification

    // Event declarations for logging various actions
    event RestoreHealthToHero(address indexed owner, uint256 amount, uint256 nftId, uint256 indexed time);
    event RestoreHealthToHeroes(address indexed owner, uint256 amount, uint256[] nftIds, uint256 indexed time);
    event RestoreHealthToAllHeroes(address indexed owner, uint256 amount, uint256 heroCount, uint256 indexed time);
    event RefreshMissions(address indexed owner, uint256 amount, uint256 indexed time);
    event CostLrdsForBuff(address indexed owner, uint256 amount, uint256 typeId, uint256 buffId, uint256 indexed time);
    event StakeLrdsForBuff(address indexed owner, uint256 amount, uint256 indexed time);
    event Claim(address indexed owner, uint256 amount, uint256 indexed time);

    
    /**
     * @dev Constructor function to initialize the HeroAndMissionsManager contract.
     * @param initialOwner The initial owner of the contract.
     * @param _hero The address of the Hero NFT contract.
     * @param _lrds The address of the LRDS token contract.
     * @param _treasury The address where LRDS tokens will be sent.
     * @param _stakeContractAddress The address of the Stake contract that handles LRDS staking.
     * @param _verifier The address of the verifier used for signature verification.
     */
    constructor(address initialOwner, address _hero, address _lrds, address _treasury, address _stakeContractAddress, address _verifier) Ownable(initialOwner) {
        require(_hero     != address(0), "Hero can't be zero address");
        require(_lrds     != address(0), "LRDS can't be zero address");
        require(_treasury != address(0), "Treasury can't be zero address");
        require(_verifier != address(0), "Verifier can't be zero address");
        
        hero     = _hero;
        lrds     = _lrds;
        treasury = _treasury;
        verifier = _verifier;

        stakeContract = Stake(_stakeContractAddress);

        maxHeroesCount = 10; // Set the default maximum number of heroes that can be managed to 10
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
     * @dev Restores the health of a single hero by consuming LRDS tokens.
     * @param _amount The amount of LRDS tokens to be consumed.
     * @param _nftId The ID of the Hero NFT whose health is to be restored.
     * @param _deadline The timestamp until when the signature is valid.
     * @param _v The recovery byte of the signature.
     * @param _r Half of the ECDSA signature pair.
     * @param _s Half of the ECDSA signature pair.
     */
    function restoreHealthToHero(uint256 _amount, uint256 _nftId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
		require(_amount   > 0, "Amount should be greater than 0");
        require(_deadline >= block.timestamp, "signature has expired");

		IERC20 _token = IERC20(lrds);
		
		require(_token.balanceOf(msg.sender) >= _amount, "Not enough tokens to restore hero health");
        require(IERC721(hero).ownerOf(_nftId) == msg.sender, "Not hero NFT owner");

        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message         = keccak256(abi.encodePacked(msg.sender, _amount, _nftId, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash            = keccak256(abi.encodePacked(prefix, message));
            address recover         = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about restore hero health");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Transfer lrds tokens to the treasury wallet
        require(_token.transferFrom(msg.sender, treasury, _amount), "Failed to transfer tokens to treasury");
        
        // Emit event after successful restoration
        emit RestoreHealthToHero(msg.sender, _amount, _nftId, block.timestamp);
    }

    /**
     * @dev Restores the health of multiple heroes by consuming LRDS tokens.
     * @param _amount The amount of LRDS tokens to be consumed.
     * @param _nftIds An array of Hero NFT IDs whose health is to be restored.
     * @param _deadline The timestamp until when the signature is valid.
     * @param _v The recovery byte of the signature.
     * @param _r Half of the ECDSA signature pair.
     * @param _s Half of the ECDSA signature pair.
     */
    function restoreHealthToHeroes(uint256 _amount, uint256[] memory _nftIds, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_amount        > 0, "Amount should be greater than 0");
        require(_nftIds.length > 0, "No heroes specified");
        require(_nftIds.length <= maxHeroesCount, "Too many heroes specified");
        require(_deadline      >= block.timestamp, "signature has expired");

        // Verify ownership of each NFT in the array
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(IERC721(hero).ownerOf(_nftIds[i]) == msg.sender, "Not hero NFT owner");
        }

        IERC20 _token = IERC20(lrds);

        require(_token.balanceOf(msg.sender) >= _amount, "Not enough tokens to restore heroes' health");

        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, _amount, _nftIds, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about restore heroes' health");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Transfer lrds tokens to the treasury wallet
        require(_token.transferFrom(msg.sender, treasury, _amount), "Failed to transfer tokens to treasury");

        // Emit event after successful restoration for specified heroes
        emit RestoreHealthToHeroes(msg.sender, _amount, _nftIds, block.timestamp);
    }

    /**
     * @dev Restores the health of all heroes by consuming LRDS tokens.
     * @param _amount The amount of LRDS tokens to be consumed.
     * @param _heroCount The total number of heroes whose health is to be restored.
     * @param _deadline The timestamp until when the signature is valid.
     * @param _v The recovery byte of the signature.
     * @param _r Half of the ECDSA signature pair.
     * @param _s Half of the ECDSA signature pair.
     */
    function restoreHealthToAllHeroes(uint256 _amount, uint256 _heroCount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_amount    > 0, "Amount should be greater than 0");
        require(_heroCount > 0, "Hero count should be greater than 0");
        require(_deadline  >= block.timestamp, "signature has expired");

        IERC20 _token = IERC20(lrds);
        
        require(_token.balanceOf(msg.sender) >= _amount, "Not enough tokens to restore heroes' health");

        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, _amount, _heroCount, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash    = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed about restore all heroes' health");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Transfer lrds tokens to the treasury wallet
        require(_token.transferFrom(msg.sender, treasury, _amount), "Failed to transfer tokens to treasury");
        
        // Emit event after successful restoration for all heroes
        emit RestoreHealthToAllHeroes(msg.sender, _amount, _heroCount, block.timestamp);
    }

    /**
     * @dev Refreshes missions for the user by consuming LRDS tokens.
     * @param _amount The amount of LRDS tokens to be consumed.
     * @param _deadline The timestamp until when the signature is valid.
     * @param _v The recovery byte of the signature.
     * @param _r Half of the ECDSA signature pair.
     * @param _s Half of the ECDSA signature pair.
     */
    function refreshMissions(uint256 _amount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_amount   > 0, "Amount should be greater than 0");
        require(_deadline >= block.timestamp, "signature has expired");

        IERC20 _token = IERC20(lrds);
        
        require(_token.balanceOf(msg.sender) >= _amount, "Not enough tokens to refresh missions");

        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, _amount, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash    = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed for refreshing missions");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Transfer lrds tokens to the treasury wallet
        require(_token.transferFrom(msg.sender, treasury, _amount), "Failed to transfer tokens to treasury");
        
        // Emit event after successful mission refresh
        emit RefreshMissions(msg.sender, _amount, block.timestamp);
    }

    /**
     * @dev Allows users to consume LRDS tokens for buffs.
     * @param _amount The amount of LRDS tokens to be consumed.
     * @param _typeId The type ID of the buff being applied.
     * @param _buffId The ID of the specific buff.
     * @param _deadline The timestamp until when the signature is valid.
     * @param _v The recovery byte of the signature.
     * @param _r Half of the ECDSA signature pair.
     * @param _s Half of the ECDSA signature pair.
     */
    function costLrdsForBuff(uint256 _amount, uint256 _typeId, uint256 _buffId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount should be greater than 0");
        require(_typeId > 0, "Type ID should be greater than 0");
        require(_buffId > 0, "Buff ID should be greater than 0");
        require(_deadline >= block.timestamp, "signature has expired");
        
        IERC20 _token = IERC20(lrds);
        
        require(_token.balanceOf(msg.sender) >= _amount, "Not enough tokens to acquire buff");

        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, _amount, _typeId, _buffId, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash    = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed for acquiring buff by cost LRDS");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Transfer lrds tokens to the treasury wallet
        require(_token.transferFrom(msg.sender, treasury, _amount), "Failed to transfer tokens to treasury");
        
        // Emit event after successful buff acquisition
        emit CostLrdsForBuff(msg.sender, _amount, _typeId, _buffId, block.timestamp);
    }

    /**
     * @dev Allows users to stake LRDS tokens for buffs.
     * @param _amount The amount of LRDS tokens to be staked.
     * @param _deadline The timestamp until when the signature is valid.
     * @param _v The recovery byte of the signature.
     * @param _r Half of the ECDSA signature pair.
     * @param _s Half of the ECDSA signature pair.
     */
    function stakeLrdsForBuff(uint256 _amount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_amount   > 0, "Amount should be greater than 0");
        require(_deadline >= block.timestamp, "signature has expired");
        
        IERC20 _token = IERC20(lrds);
        
        require(_token.balanceOf(msg.sender) >= _amount, "Not enough tokens to acquire buff");

        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, _amount, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash    = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed for acquiring buff by stake LRDS");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Transfer lrds tokens to the treasury wallet
        stakeContract.stake(msg.sender, _amount);
        
        // Emit event after successful buff acquisition
        emit StakeLrdsForBuff(msg.sender, _amount, block.timestamp);
    }
    
    /**
    * @dev Allows users to claim their staked LRDS tokens.
    * @param _deadline The timestamp until when the signature is valid.
    * @param _v The recovery byte of the signature.
    * @param _r Half of the ECDSA signature pair.
    * @param _s Half of the ECDSA signature pair.
    */
    function claim(uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external nonReentrant whenNotPaused {
        require(_deadline >= block.timestamp, "signature has expired");
        
        // Verify signature
        {
            bytes memory prefix     = "\x19Ethereum Signed Message:\n32";
            bytes32 message = keccak256(abi.encodePacked(msg.sender, address(this), nonce[msg.sender], _deadline, block.chainid));
            bytes32 hash    = keccak256(abi.encodePacked(prefix, message));
            address recover = ecrecover(hash, _v, _r, _s);

            require(recover == verifier, "Verification failed for acquiring buff");
        }

        // Increment nonce to prevent replay attacks
        nonce[msg.sender]++;

        // Call the claim function in the Stake contract
        uint256 amount = stakeContract.claim(msg.sender);
        
        // Emit event after successful buff acquisition
        emit Claim(msg.sender, amount, block.timestamp);
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
     * @dev Sets the maximum number of heroes that can be managed by the contract.
     * @param _maxHeroesCount The new maximum number of heroes.
     */
    function setMaxHeroesCount(uint256 _maxHeroesCount) external onlyOwner {
        require(_maxHeroesCount > 0, "Max heroes count must be greater than 0");
        maxHeroesCount = _maxHeroesCount;
    }

    /**
     * @dev Sets the address of the Stake contract.
     * @param _newStakeContractAddress The new address of the Stake contract.
     */
    function setStakeContractAddress(address _newStakeContractAddress) external onlyOwner {
        require(_newStakeContractAddress != address(0), "New Stake contract address can't be zero address");
        stakeContract = Stake(_newStakeContractAddress);
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

}