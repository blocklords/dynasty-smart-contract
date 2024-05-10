// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BLOCKLORDS
 * @dev The BLOCKLORDS Nft Marketplace is a trading platform allowing to buy and sell Nfts
 * @author BLOCKLORDS TEAM
 * @notice This contract enables users to buy and sell NFTs using ERC721 tokens as currency.
 * It also supports the use of ERC20 tokens for trading.
 * The contract allows the owner to enable/disable sales, add/remove supported ERC721 and ERC20 tokens,
 * set fee receiver address and fee rate, and set gas limit for transfers of mainnet currency.
 * Sales objects are created when a user lists an NFT for sale, and buyers can purchase these NFTs.
 * Sellers receive the sale amount minus the fee, which is sent to the fee receiver address.
 */

contract Marketplace is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;

    uint256 public  salesAmount;    // keep count of SalesObject amount
    bool    private lock;           // reentrancy guard
    bool    public  salesEnabled;   // enable/disable trading
    uint256 public  feeRate;        // fee rate. feeAmount = (feeRate / 1000) * price
    address payable feeReceiver;    // fee reciever
    uint256 public  gasLimit;       // to transfer mainnet currency

    /// @notice individual sale related data
    struct SalesObject {
        uint256 id;               // sales ID
        uint256 tokenId;          // token unique id
        address nft;              // nft address
        address currency;         // currency address
        address payable seller;   // seller address
        address payable buyer;    // buyer address
        uint256 startTime;        // timestamp when the sale starts
        uint256 price;            // nft price
        uint8   status;           // 2 = sale canceled, 1 = sold, 0 = for sale
    }

    // nft token address => (nft id => salesObject)
    mapping(address => mapping(uint256 => SalesObject)) salesObjects;  // marketplace sales objects.

    mapping(address => bool) public supportedNft;                      // supported ERC721 contracts
    mapping(address => bool) public supportedCurrency;                 // supported ERC20 contracts

    event Buy(uint256 indexed saleId, uint256 tokenId, address buyer, uint256 price, uint256 tipsFee, address currency);                                  // Event emitted when a purchase is made
    event Sell( uint256 indexed saleId, uint256 tokenId, address nft, address currency, address seller, address buyer, uint256 startTime, uint256 price); // Event emitted when an NFT is sold
    event CancelSell(uint256 indexed saleId, uint256 tokenId);                                                                                            // Event emitted when a sale is canceled
    event NftReceived(address operator, address from, uint256 tokenId, bytes data);                                                                       // Event emitted when an NFT is received
    event EnableSales(bool indexed enableSales, uint256 indexed time);                                                                                    // Event emitted when sales are enabled or disabled
    event AddSupportedNft(address indexed nftAddress, uint256 indexed time);                                                                              // Event emitted when a supported NFT contract address is added
    event RemoveSupportedNft(address indexed nftAddress, uint256 indexed time);                                                                           // Event emitted when a supported NFT contract address is added
    event AddSupportedCurrency(address indexed currencyAddress, uint256 indexed time);                                                                    // Event emitted when a supported currency contract address is added
    event RemoveSupportedCurrency(address indexed currencyAddress, uint256 indexed time);                                                                 // Event emitted when a supported currency contract address is removed
    event SetFeeReceiver(address indexed feeReceiver, uint256 indexed time);                                                                              // Event emitted when the fee receiver address is set
    event SetFeeRate(uint256 indexed rate, uint256 indexed time);                                                                                         // Event emitted when the fee rate is set

     /**
     * @dev Initializes the contract with the provided fee receiver address and fee rate.
     * @param initialOwner The address that will become the owner of the contract.
     * @param _feeReceiver The address where trading fees will be sent.
     * @param _feeRate The fee rate for each sale, in percentage (0-100).
     */
    constructor(address initialOwner, address payable _feeReceiver, uint256 _feeRate) Ownable(initialOwner) {
        require(_feeReceiver != address(0), "Receiver can't be zero address");
        require(_feeRate <= 100, "Rate should be bellow 100 (10%)");

        feeReceiver = _feeReceiver;
        feeRate     = _feeRate;
        gasLimit    = 5400;
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

    //--------------------------------------------------
    // External methods
    //--------------------------------------------------
    /**
     * @notice enable/disable sales
     * @param _salesEnabled set sales to true/false
     */
    function enableSales(bool _salesEnabled) external onlyOwner {
        salesEnabled = _salesEnabled;

        emit EnableSales(salesEnabled, block.timestamp);
    }

    /**
     * @notice add supported nft token
     * @param _nftAddress ERC721 contract address
     */
    function addSupportedNft(address _nftAddress) external onlyOwner {
        require(_nftAddress != address(0x0), "invalid address");
        supportedNft[_nftAddress] = true;

        emit AddSupportedNft(_nftAddress, block.timestamp);
    }

    /**
     * @notice disable supported nft token
     * @param _nftAddress ERC721 contract address
     */
    function removeSupportedNft(address _nftAddress) external onlyOwner {
        require(_nftAddress != address(0x0), "invalid address");
        supportedNft[_nftAddress] = false;

        emit RemoveSupportedNft(_nftAddress, block.timestamp);
    }

    /**
     * @notice add supported currency token
     * @param _currencyAddress ERC20 contract address
     */
    function addSupportedCurrency(address _currencyAddress) external onlyOwner {
        require(!supportedCurrency[_currencyAddress], "currency already supported");
        supportedCurrency[_currencyAddress] = true;

        emit AddSupportedCurrency(_currencyAddress, block.timestamp);
    }

    /**
     * @notice disable supported currency token
     * @param _currencyAddress ERC20 contract address
     */
    function removeSupportedCurrency(address _currencyAddress) external onlyOwner {
        require(supportedCurrency[_currencyAddress], "currency already removed");
        supportedCurrency[_currencyAddress] = false;

        emit RemoveSupportedCurrency(_currencyAddress, block.timestamp);
    }

    /**
     * @notice change fee receiver address
     * @param _walletAddress address of the new fee receiver
     */
    function setFeeReceiver(address payable _walletAddress) external onlyOwner {
        require(_walletAddress != address(0x0), "invalid address");
        feeReceiver = _walletAddress;

        emit SetFeeReceiver(_walletAddress, block.timestamp);
    }

    /**
     * @notice change fee rate
     * @param _rate amount value. Actual rate in percent = _rate / 10
     */
    function setFeeRate(uint256 _rate) external onlyOwner {
        require(_rate <= 100, "Rate should be bellow 100 (10%)");
        feeRate = _rate;

        emit SetFeeRate(_rate, block.timestamp);
    }
    
    /**
     * @notice change gaslimit to transfer mainnet currency
     * @param _gasLimit amount value of the new gasLimit
     */
    function setGaslimit(uint256 _gasLimit) external onlyOwner{
        require(_gasLimit > 0, "gaslimit must be greater than 0");

        gasLimit = _gasLimit;
    }

    /**
     * @notice returns sales amount
     * @return total amount of sales objects
     */
    function getSalesAmount() external view returns(uint) {
        return salesAmount; 
    }

    //--------------------------------------------------
    // Public methods
    //--------------------------------------------------
    /**
     * @notice put nft for sale
     * @param _tokenId nft unique ID
     * @param _price required price to pay by buyer. Seller receives less: price - fees
     * @param _nftAddress nft token address
     * @param _currency currency token address
     * @return salesAmount total amount of sales
     */
    function sell(uint256 _tokenId, uint256 _price, address _nftAddress, address _currency) external nonReentrant returns(uint) {
        require(_nftAddress != address(0x0), "invalid nft address");
        require(_tokenId != 0, "invalid nft token");
        require(salesEnabled, "sales are closed");
        require(supportedNft[_nftAddress], "nft address unsupported");
        require(supportedCurrency[_currency], "currency not supported");

        salesAmount++;
        salesObjects[_nftAddress][_tokenId] = SalesObject(
            salesAmount,
            _tokenId,
            _nftAddress,
            _currency,
            payable(msg.sender),
            payable(address(0x0)),
            block.timestamp,
            _price,
            0
        );

        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

        emit Sell(salesAmount, _tokenId, _nftAddress, _currency, msg.sender, address(0x0), block.timestamp, _price);

        return salesAmount;
    }

    /**
     * @notice buy nft
     * @param _tokenId nft unique ID
     * @param _nftAddress nft token address
     * @param _currency currency token address
     */
    function buy(uint256 _tokenId, address _nftAddress, address _currency, uint _price) external nonReentrant payable {
        require(tx.origin == msg.sender, "origin is not sender");

        SalesObject storage obj = salesObjects[_nftAddress][_tokenId];
        require(obj.status == 0, "status: sold or canceled");
        require(obj.startTime <= block.timestamp, "not yet for sale");
        require(salesEnabled, "sales are closed");
        require(msg.sender != obj.seller, "cant buy from yourself");

        require(obj.currency == _currency, "must pay same currency as sold");
        uint256 price = this.getSalesPrice(_tokenId, _nftAddress);
        require(price == _price, "invalid price");
        uint256 tipsFee = price * feeRate / 1000;
        uint256 purchase = price - tipsFee;

        obj.status = 1;

        if (obj.currency == address(0x0)) {
            require (msg.value >= price, "your price is too low");
            uint256 returnBack = msg.value - price;
            if (returnBack > 0)
                payable(msg.sender).transfer(returnBack);
            if (tipsFee > 0)
                feeReceiver.transfer(tipsFee);
            (bool success, ) = payable(obj.seller).call{value: purchase, gas: gasLimit}("");
            require(success, "transfer fail");
        } else {
            require(msg.value == 0, "invalid value");
            IERC20(obj.currency).safeTransferFrom(msg.sender, feeReceiver, tipsFee);
            IERC20(obj.currency).safeTransferFrom(msg.sender, obj.seller, purchase);
        }

        IERC721 nft = IERC721(obj.nft);
        nft.safeTransferFrom(address(this), msg.sender, obj.tokenId);
        obj.buyer = payable(msg.sender);

        emit Buy(obj.id, obj.tokenId, obj.buyer, price, tipsFee, obj.currency);
    }

    /**
     * @notice cancel nft sale
     * @param _tokenId nft unique ID
     * @param _nftAddress nft token address
     */
    function cancelSell(uint _tokenId, address _nftAddress) external nonReentrant{
        SalesObject storage obj = salesObjects[_nftAddress][_tokenId];
        require(obj.status == 0, "status: sold or canceled");
        require(obj.seller == msg.sender, "seller not nft owner");

        obj.status = 2;
        IERC721 nft = IERC721(obj.nft);
        nft.safeTransferFrom(address(this), obj.seller, obj.tokenId);

        emit CancelSell(obj.id, obj.tokenId);
    }

    /**
     * @dev fetch sale object at nftId and nftAddress
     * @param _tokenId unique nft ID
     * @param _nftAddress nft token address
     * @return SalesObject at given index
     */
    function getSales(uint _tokenId, address _nftAddress) external view returns(SalesObject memory) {
        return salesObjects[_nftAddress][_tokenId];
    }

    /**
     * @dev returns the price of sale
     * @param _tokenId nft unique ID
     * @param _nftAddress nft token address
     * @return obj.price price of corresponding sale
     */
    function getSalesPrice(uint _tokenId, address _nftAddress) public view returns (uint256) {
        SalesObject storage obj = salesObjects[_nftAddress][_tokenId];
        return obj.price;
    }
    
    /// @dev encrypt token data
    /// @return encrypted data
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public override returns (bytes4) {
        //only receive the _nft staff
        if (address(this) != operator) {
            //invalid from nft
            return 0;
        }

        emit NftReceived(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
