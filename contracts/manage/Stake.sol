// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BLOCKLORDS
 * @dev This contract that allows users to stake LRDS tokens.
 * @author BLOCKLORDS TEAM
 * @dev The contract is controlled by a main contract which can trigger staking and claiming of tokens.
 * It also includes pausable functionality that allows the owner to pause or unpause operations.
 */
contract Stake is Pausable, Ownable {
    using SafeERC20 for IERC20;

    // The ERC20 token that is being staked (LRDS token)
    IERC20 public lrdsToken;

    // Address of the contract responsible for verifying staking actions
    address public verifier;

    // Address of the main contract which can interact with this contract
    address public mainContract;
    
    // Struct to store staking information for each user
    struct StakeInfo {
        uint256 amount;
        uint256 time;
    }

    // Mapping from user address to their staking information
    mapping(address => StakeInfo) public stakes;
    
    event Staked(address indexed user, uint256 amount, uint256 timestamp);   // Event emitted when a user stakes tokens
    event Claimed(address indexed user, uint256 amount, uint256 timestamp);  // Event emitted when a user claims their staked tokens

    /**
     * @dev Constructor function that sets the owner and the LRDS token contract address.
     * @param initialOwner The address of the initial owner of the contract.
     * @param _lrdsToken The address of the LRDS token contract.
     */
    constructor(address initialOwner, IERC20 _lrdsToken) Ownable(initialOwner) {
        lrdsToken = _lrdsToken;
    }
    
    // Modifier to ensure that only the main contract can call certain functions
    modifier onlyMainContract() {
        require(msg.sender == mainContract, "Only the main contract can call this function");
        _;
    }

    /**
     * @dev Function to allow the main contract to stake tokens on behalf of a user.
     * @param _staker The address of the user who is staking tokens.
     * @param _amount The amount of LRDS tokens to be staked.
     */
    function stake(address _staker, uint256 _amount) external whenNotPaused onlyMainContract {
        require(_amount > 0, "Amount should be greater than 0");

        // Ensure the staker has enough tokens to stake
        require(lrdsToken.balanceOf(_staker) >= _amount, "Not enough tokens to stake");

        // Ensure the staker has given sufficient allowance to the contract
        require(lrdsToken.allowance(_staker, address(this)) >= _amount, "Not enough allowance for LRDS transfer");

        // Transfer tokens from the staker to this contract
        lrdsToken.transferFrom(_staker, address(this), _amount);

        // Update the staking information for the user
        stakes[_staker].amount += _amount;
        stakes[_staker].time = block.timestamp;

        emit Staked(_staker, _amount, block.timestamp);
    }

    /**
     * @dev Function to allow the main contract to claim staked tokens on behalf of a user.
     * @param _staker The address of the user who is claiming their staked tokens.
     * @return The amount of tokens claimed.
     */
    function claim(address _staker) external whenNotPaused onlyMainContract returns (uint256) {
        uint256 stakedAmount = stakes[_staker].amount;
        require(stakedAmount > 0, "No staked tokens to claim");

        // Check if the contract has enough balance to cover the claim
        require(lrdsToken.balanceOf(address(this)) >= stakedAmount, "Not enough LRDS tokens in the contract");

        // Reset the stake information for the user
        delete stakes[_staker];

        // Transfer the staked amount back to the staker
        lrdsToken.transfer(_staker, stakedAmount);

        emit Claimed(_staker, stakedAmount, block.timestamp);

        return stakedAmount;
    }

    /**
     * @dev Function to set the address of the main contract.
     * @param _mainContract The address of the main contract.
     */
    function setMainContract(address _mainContract) external onlyOwner {
        mainContract = _mainContract;
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
