// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./OrbNFT.sol";
import "./HeroNFT.sol";
import "./BannerNFT.sol";

contract NftFactory is AccessControl, Ownable {
    // Role definitions
    bytes32 public constant HERO_GENERATOR_ROLE   = keccak256("HEROGENERATOR");
    bytes32 public constant BANNER_GENERATOR_ROLE = keccak256("BANNERGENERATOR");
    bytes32 public constant ORB_GENERATOR_ROLE    = keccak256("ORBGENERATOR");

    // NFT contracts
    OrbNFT    private orbNft;
    HeroNFT   private heroNft;
    BannerNFT private bannerNft;

    event AdminAdded(address indexed admin, uint256 indexed time);
    event AdminRemoved(address indexed admin, uint256 indexed time);
    event SetOrbNft(address indexed orbNft, uint256 indexed time);
    event SetHeroNft(address indexed heroNft, uint256 indexed time);
    event SetBannerNft(address indexed bannerNft, uint256 indexed time);
    event OrbGeneratorAdded(address indexed OrbGenerator, uint256 indexed time);
    event OrbGeneratorRemoved(address indexed OrbGenerator, uint256 indexed time);
    event HeroGeneratorAdded(address indexed OrbGenerator, uint256 indexed time);
    event HeroGeneratorRemoved(address indexed OrbGenerator, uint256 indexed time);
    event BannerGeneratorAdded(address indexed OrbGenerator, uint256 indexed time);
    event BannerGeneratorRemoved(address indexed OrbGenerator, uint256 indexed time);

    constructor(address initialOwner, address _orbNft, address _heroNft, address _bannerNft) Ownable(initialOwner) {
        require(_orbNft    != address(0), "orb nft can't be zero address");
        require(_heroNft   != address(0), "hero nft can't be zero address");
        require(_bannerNft != address(0), "banner nft can't be zero address");

	    orbNft    = OrbNFT(_orbNft);
	    heroNft   = HeroNFT(_heroNft);
	    bannerNft = BannerNFT(_bannerNft);

	    // Grant the default admin role to the initial owner
	    _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    // Modifier: Restricted to members of the admin role.
    modifier onlyAdmin() {
	    require(isAdmin(msg.sender), "Restricted to admins.");
	    _;
    }

    // Modifier: Restricted to members of the generator role.
    modifier onlyOrbGenerator() {
        require(isOrbGenerator(msg.sender), "Restricted to random orb generator.");
        _;
    }

    modifier onlyHerobGenerator() {
        require(isHeroGenerator(msg.sender), "Restricted to random hero generator.");
        _;
    }

    modifier onlyBannerGenerator() {
        require(isBannerGenerator(msg.sender), "Restricted to random banner generator.");
        _;
    }

    //--------------------------------------------------
    // Mint different types of nft
    //--------------------------------------------------
    // Can only be called by orb generator to mint orb NFT
    function mintOrb(address _to, uint256 _quality) external onlyOrbGenerator returns(uint256) {
	    return orbNft.mint(_to, _quality);
    }

    // Can only be called by hero generator to mint hero NFT
    function mintHero(address _to, uint256 _tokenId) external onlyHerobGenerator returns(uint256) {
	    return heroNft.mint(_to, _tokenId);
    }

    // Can only be called by banner generator to mint banner NFT
    function mintBanner(address _to, uint256 _tokenId) external onlyBannerGenerator returns(uint256) {
	    return bannerNft.mint(_to, _tokenId);
    }

    //--------------------------------------------------
    // Only owner
    //--------------------------------------------------
    // Add an account to the admin role. 
    function addAdmin(address _account) external virtual onlyOwner {
        grantRole(DEFAULT_ADMIN_ROLE, _account);

        emit AdminAdded(_account, block.timestamp);
    }

    // Remove admin from the admin role.
    function removeAdmin(address _account) external virtual onlyOwner {
	    renounceRole(DEFAULT_ADMIN_ROLE, _account);
        
        emit AdminRemoved(_account, block.timestamp);
    }

    // Return `true` if the account belongs to the admin role.
    function isAdmin(address _account) public virtual view returns (bool) {
	    return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    //--------------------------------------------------
    // Only admin
    //--------------------------------------------------
    // Set the orb NFT contract address
    function setOrbNft(address _orbNft) external onlyAdmin {
        require(_orbNft != address(0), "orb nft can't be zero address");
	    orbNft = OrbNFT(_orbNft);

        emit SetOrbNft(_orbNft, block.timestamp);
    }

    // Set the hero NFT contract address
    function setHeroNft(address _heroNft) external onlyAdmin {
        require(_heroNft != address(0), "hero nft can't be zero address");
	    heroNft = HeroNFT(_heroNft);

        emit SetHeroNft(_heroNft, block.timestamp);
    }

    // Set the banner NFT contract address
    function setBannerNft(address _bannerNft) external onlyAdmin {
        require(_bannerNft != address(0), "banner nft can't be zero address");
	    bannerNft = BannerNFT(_bannerNft);

        emit SetBannerNft(_bannerNft, block.timestamp);
    }

    // Settings for the orb generator
    // Add an account to the orb generator role
    function addOrbGenerator(address _account) external virtual onlyAdmin {
	    grantRole(ORB_GENERATOR_ROLE, _account);

        emit OrbGeneratorAdded(_account, block.timestamp);
    }

    // Remove an account from the orb generator role
    function removeOrbGenerator(address _account) external virtual onlyAdmin {
	    revokeRole(ORB_GENERATOR_ROLE, _account);

        emit OrbGeneratorRemoved(_account, block.timestamp);
    }

    // Check if an account is in the orb generator role
    function isOrbGenerator(address _account) public virtual view returns (bool) {
        return hasRole(ORB_GENERATOR_ROLE, _account);
    }

    // Settings for the hero generator
    // Add an account to the hero generator role
    function addHeroGenerator(address _account) external virtual onlyAdmin {
	    grantRole(HERO_GENERATOR_ROLE, _account);

        emit HeroGeneratorAdded(_account, block.timestamp);
    }

    // Remove an account from the hero generator role
    function removeHeroGenerator(address _account) external virtual onlyAdmin {
	    revokeRole(HERO_GENERATOR_ROLE, _account);

        emit HeroGeneratorRemoved(_account, block.timestamp);
    }

    // Check if an account is in the hero generator role
    function isHeroGenerator(address _account) public virtual view returns (bool) {
        return hasRole(HERO_GENERATOR_ROLE, _account);
    }

    // Settings for the banner generator
    // Add an account to the banner generator role
    function addBannerGenerator(address _account) external virtual onlyAdmin {
	    grantRole(BANNER_GENERATOR_ROLE, _account);

        emit BannerGeneratorAdded(_account, block.timestamp);
    }

    // Remove an account from the banner generator role
    function removeBannerGenerator(address _account) external virtual onlyAdmin {
	    revokeRole(BANNER_GENERATOR_ROLE, _account);

        emit BannerGeneratorRemoved(_account, block.timestamp);
    }

    // Check if an account is in the banner generator role
    function isBannerGenerator(address _account) public virtual view returns (bool) {
        return hasRole(BANNER_GENERATOR_ROLE, _account);
    }
}
