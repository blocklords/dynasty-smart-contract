// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./OrbNFT.sol";
import "./HeroNFT.sol";
import "./BannerNFT.sol";

/**
 *  @title BLOCKLORDS
 *  @dev A contract for minting different types of NFTs such as Orb, Hero, and Banner.
 *  It provides role-based access control to manage NFT generation and administration.
 *  @author BLOCKLORDS TEAM
 *  @notice This contract is part of the BLOCKLORDS ecosystem and facilitates the creation and management of NFTs.
 */
 
contract NftFactory is AccessControl, Ownable {
    
    bytes32 public constant HERO_GENERATOR_ROLE   = keccak256("HEROGENERATOR");   // Role for the hero NFT generator
    bytes32 public constant BANNER_GENERATOR_ROLE = keccak256("BANNERGENERATOR"); // Role for the banner NFT generator
    bytes32 public constant ORB_GENERATOR_ROLE    = keccak256("ORBGENERATOR");    // Role for the orb NFT generator

    OrbNFT    private orbNft;    // Instance of the OrbNFT contract
    HeroNFT   private heroNft;   // Instance of the HeroNFT contract
    BannerNFT private bannerNft; // Instance of the BannerNFT contract

    event AdminAdded(address indexed owner, address indexed admin, uint256 indexed time);                      // An admin is added.
    event AdminRemoved(address indexed owner, address indexed admin, uint256 indexed time);                    // An admin is removed.
    event SetOrbNft(address indexed admin, address indexed orbNft, uint256 indexed time);                      // The OrbNFT contract address is set.
    event SetHeroNft(address indexed admin, address indexed heroNft, uint256 indexed time);                    // The HeroNFT contract address is set.
    event SetBannerNft(address indexed admin, address indexed bannerNft, uint256 indexed time);                // The BannerNFT contract address is set.
    event OrbGeneratorAdded(address indexed admin, address indexed OrbGenerator, uint256 indexed time);        // An account is granted the Orb Generator role.
    event OrbGeneratorRemoved(address indexed admin, address indexed OrbGenerator, uint256 indexed time);      // An account is removed from the Orb Generator role.
    event HeroGeneratorAdded(address indexed admin, address indexed OrbGenerator, uint256 indexed time);       // An account is granted the Hero Generator role.
    event HeroGeneratorRemoved(address indexed admin, address indexed OrbGenerator, uint256 indexed time);     // An account is removed from the Hero Generator role.
    event BannerGeneratorAdded(address indexed admin, address indexed OrbGenerator, uint256 indexed time);     // An account is granted the Banner Generator role.
    event BannerGeneratorRemoved(address indexed admin, address indexed OrbGenerator, uint256 indexed time);   // An account is removed from the Banner Generator role.

    /**
     * @dev Initializes the NftFactory contract.
     * @param initialOwner The address of the initial owner of the contract.
     * @param _heroNft The address of the Hero NFT contract.
     * @param _bannerNft The address of the Banner NFT contract.
     * @param _orbNft The address of the Orb NFT contract.
     */
    constructor(address initialOwner, address _heroNft, address _bannerNft, address _orbNft) Ownable(initialOwner) {
        require(_heroNft   != address(0), "hero nft can't be zero address");
        require(_bannerNft != address(0), "banner nft can't be zero address");
        require(_orbNft    != address(0), "orb nft can't be zero address");

	    heroNft   = HeroNFT(_heroNft);
	    bannerNft = BannerNFT(_bannerNft);
	    orbNft    = OrbNFT(_orbNft);

	    // Grant the default admin role to the initial owner
	    _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    /**
    * @dev Modifier that restricts access to functions to only accounts with the admin role.
    * Reverts with an error message if the caller is not an admin.
    */
    modifier onlyAdmin() {
	    require(isAdmin(msg.sender), "Restricted to admins.");
	    _;
    }

    /**
    * @dev Modifier that restricts access to functions to only accounts with the orb generator role.
    * Reverts with an error message if the caller is not an orb generator.
    */
    modifier onlyOrbGenerator() {
        require(isOrbGenerator(msg.sender), "Restricted to random orb generator.");
        _;
    }

    /**
    * @dev Modifier that restricts access to functions to only accounts with the hero generator role.
    * Reverts with an error message if the caller is not a hero generator.
    */
    modifier onlyHeroGenerator() {
        require(isHeroGenerator(msg.sender), "Restricted to random hero generator.");
        _;
    }

    /**
    * @dev Modifier that restricts access to functions to only accounts with the banner generator role.
    * Reverts with an error message if the caller is not a banner generator.
    */
    modifier onlyBannerGenerator() {
        require(isBannerGenerator(msg.sender), "Restricted to random banner generator.");
        _;
    }

    /**
    * @dev Mints a Hero NFT and assigns it to the specified address.
    * Can only be called by accounts with the Hero NFT generator role.
    * @param _to The address to which the newly minted Hero NFT will be assigned.
    * @param _tokenId The ID of the Hero NFT to be minted.
    * @return The ID of the newly minted Hero NFT.
    */
    function mintHero(address _to, uint256 _tokenId) external onlyHeroGenerator returns(uint256) {
	    return heroNft.mint(_to, _tokenId);
    }

    /**
    * @dev Mints a Banner NFT and assigns it to the specified address.
    * Can only be called by accounts with the Banner NFT generator role.
    * @param _to The address to which the newly minted Banner NFT will be assigned.
    * @param _tokenId The ID of the Banner NFT to be minted.
    * @return The ID of the newly minted Banner NFT.
    */
    function mintBanner(address _to, uint256 _tokenId) external onlyBannerGenerator returns(uint256) {
	    return bannerNft.mint(_to, _tokenId);
    }

    /**
     * @dev Mints an Orb NFT and assigns it to the specified address.
     * Can only be called by accounts with the Orb NFT generator role.
     * @param _to The address to which the newly minted Orb NFT will be assigned.
     * @param _quality The quality of the Orb NFT to be minted.
     * @param _receiptId from receipt Id to Orb NFT id.
     * @return The ID of the newly minted Orb NFT.
     */
    function mintOrb(address _to, uint256 _quality, uint256 _receiptId) external onlyOrbGenerator returns(uint256) {
	    return orbNft.mint(_to, _quality, _receiptId);
    }

    //--------------------------------------------------
    // Only owner
    //--------------------------------------------------
    /**
    * @dev Adds the specified account to the admin role.
    * Can only be called by the contract owner.
    * @param _account The address to be added as an admin.
    */
    function addAdmin(address _account) external virtual onlyOwner {
        grantRole(DEFAULT_ADMIN_ROLE, _account);

        emit AdminAdded(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Removes the specified account from the admin role.
    * Can only be called by the contract owner.
    * @param _account The address to be removed from the admin role.
    */
    function removeAdmin(address _account) external virtual onlyOwner {
        require(_account != owner(), "Cannot remove contract owner as admin");
	    renounceRole(DEFAULT_ADMIN_ROLE, _account);
        
        emit AdminRemoved(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Checks if the specified account belongs to the admin role.
    * @param _account The address to be checked.
    * @return A boolean indicating whether the account is an admin.
    */
    function isAdmin(address _account) public virtual view returns (bool) {
	    return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    //--------------------------------------------------
    // Only admin
    //--------------------------------------------------
    /**
    * @dev Sets the address of the Orb NFT contract.
    * Can only be called by an admin.
    * @param _orbNft The address of the Orb NFT contract.
    */
    function setOrbNft(address _orbNft) external onlyAdmin {
        require(_orbNft != address(0), "orb nft can't be zero address");
	    orbNft = OrbNFT(_orbNft);

        emit SetOrbNft(msg.sender, _orbNft, block.timestamp);
    }

    /**
    * @dev Sets the address of the Hero NFT contract.
    * Can only be called by an admin.
    * @param _heroNft The address of the Hero NFT contract.
    */
    function setHeroNft(address _heroNft) external onlyAdmin {
        require(_heroNft != address(0), "hero nft can't be zero address");
	    heroNft = HeroNFT(_heroNft);

        emit SetHeroNft(msg.sender, _heroNft, block.timestamp);
    }

    /**
    * @dev Sets the address of the Banner NFT contract.
    * Can only be called by an admin.
    * @param _bannerNft The address of the Banner NFT contract.
    */
    function setBannerNft(address _bannerNft) external onlyAdmin {
        require(_bannerNft != address(0), "banner nft can't be zero address");
	    bannerNft = BannerNFT(_bannerNft);

        emit SetBannerNft(msg.sender, _bannerNft, block.timestamp);
    }

    /**
    * @dev Adds an account to the hero generator role.
    * Can only be called by an admin.
    * @param _account The address to be added to the hero generator role.
    */
    function addHeroGenerator(address _account) external virtual onlyAdmin {
	    grantRole(HERO_GENERATOR_ROLE, _account);

        emit HeroGeneratorAdded(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Removes an account from the hero generator role.
    * Can only be called by an admin.
    * @param _account The address to be removed from the hero generator role.
    */
    function removeHeroGenerator(address _account) external virtual onlyAdmin {
	    revokeRole(HERO_GENERATOR_ROLE, _account);

        emit HeroGeneratorRemoved(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Checks whether an account belongs to the hero generator role.
    * @param _account The address to be checked.
    * @return A boolean indicating whether the account belongs to the hero generator role.
    */
    function isHeroGenerator(address _account) public virtual view returns (bool) {
        return hasRole(HERO_GENERATOR_ROLE, _account);
    }

    /**
    * @dev Adds an account to the banner generator role.
    * Can only be called by an admin.
    * @param _account The address to be added to the banner generator role.
    */
    function addBannerGenerator(address _account) external virtual onlyAdmin {
	    grantRole(BANNER_GENERATOR_ROLE, _account);

        emit BannerGeneratorAdded(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Removes an account from the banner generator role.
    * Can only be called by an admin.
    * @param _account The address to be removed from the banner generator role.
    */
    function removeBannerGenerator(address _account) external virtual onlyAdmin {
	    revokeRole(BANNER_GENERATOR_ROLE, _account);

        emit BannerGeneratorRemoved(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Checks whether an account belongs to the banner generator role.
    * @param _account The address to be checked.
    * @return A boolean indicating whether the account belongs to the banner generator role.
    */
    function isBannerGenerator(address _account) public virtual view returns (bool) {
        return hasRole(BANNER_GENERATOR_ROLE, _account);
    }

    /**
    * @dev Adds an account to the orb generator role.
    * Can only be called by an admin.
    * @param _account The address to be added to the orb generator role.
    */
    function addOrbGenerator(address _account) external virtual onlyAdmin {
	    grantRole(ORB_GENERATOR_ROLE, _account);

        emit OrbGeneratorAdded(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Removes an account from the orb generator role.
    * Can only be called by an admin.
    * @param _account The address to be removed from the orb generator role.
    */
    function removeOrbGenerator(address _account) external virtual onlyAdmin {
	    revokeRole(ORB_GENERATOR_ROLE, _account);

        emit OrbGeneratorRemoved(msg.sender, _account, block.timestamp);
    }

    /**
    * @dev Checks whether an account belongs to the orb generator role.
    * @param _account The address to be checked.
    * @return A boolean indicating whether the account belongs to the orb generator role.
    */
    function isOrbGenerator(address _account) public virtual view returns (bool) {
        return hasRole(ORB_GENERATOR_ROLE, _account);
    }
}
