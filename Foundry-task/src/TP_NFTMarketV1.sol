// SPDX-License-Identifier: MIT
// wake-disable unsafe-erc20-call 
// wake-disable unsafe-transfer
// wake-disable unchecked-return-value
// wake-disable reentrancy

pragma solidity ^0.8.19;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/**
 * @title TP-NFTMarketV1
 * @dev 第一个版本的 NFT 市场合约（透明代理版本）
 * 提供基本的 NFT 上架、购买、下架等功能
 */
contract TP_NFTMarketV1 {
    // 存储槽位定义 - 与 V2 兼容
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(0));
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(1));
    bytes32 private constant PAYMENT_TOKEN_SLOT = bytes32(uint256(2));
    bytes32 private constant NFT_CONTRACT_SLOT = bytes32(uint256(3));
    bytes32 private constant MARKETPLACE_FEE_SLOT = bytes32(uint256(4));
    bytes32 private constant ACCUMULATED_FEES_SLOT = bytes32(uint256(5));
    bytes32 private constant VERSION_SLOT = bytes32(uint256(6));
    bytes32 private constant DOMAIN_SEPARATOR_SLOT = bytes32(uint256(7));

    // 结构体定义
    struct Listing {
        address seller;        // 卖家地址
        uint256 price;         // 价格
        uint256 timestamp;     // 上架时间
        bool active;           // 是否激活
    }

    // 事件定义
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller);
    event PriceUpdated(uint256 indexed tokenId, address indexed seller, uint256 newPrice);
    event FeesWithdrawn(address indexed admin, uint256 amount);
    event MarketplaceFeeUpdated(uint256 newFee);

    // 映射定义
    mapping(uint256 => Listing) private _listings;           // tokenId => Listing
    mapping(uint256 => bool) private _listedTokenIds;        // tokenId => 是否已上架
    uint256[] private _allListedTokenIds;                   // 所有已上架的 tokenId 列表

    /**
     * @dev 初始化合约
     * @param _paymentToken 支付代币地址
     * @param _nftContract NFT 合约地址
     */
    function initialize(address _paymentToken, address _nftContract) external {
        require(_getPaymentToken() == address(0), "Already initialized");
        require(_paymentToken != address(0), "Invalid payment token");
        require(_nftContract != address(0), "Invalid NFT contract");
        
        _setPaymentToken(_paymentToken);
        _setNFTContract(_nftContract);
        _setMarketplaceFee(250); // 2.5% 手续费
        _setVersion("1.0.0");
        _setAdmin(msg.sender); // 设置管理员为调用者
    }

    /**
     * @dev 上架 NFT
     * @param tokenId NFT 的 tokenId
     * @param price 价格
     */
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(!_listedTokenIds[tokenId], "NFT already listed");
        
        // 检查 NFT 所有权
        address nftContract = _getNFTContract();
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner");
        
        // 检查授权
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
            IERC721(nftContract).getApproved(tokenId) == address(this),
            "Not approved"
        );

        // 创建上架记录
        _listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            timestamp: block.timestamp,
            active: true
        });

        _listedTokenIds[tokenId] = true;
        _allListedTokenIds.push(tokenId);

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @dev 购买 NFT
     * @param tokenId NFT 的 tokenId
     */
    function buyNFT(uint256 tokenId) external {
        require(_listedTokenIds[tokenId], "NFT not listed");
        
        Listing storage listing = _listings[tokenId];
        require(listing.active, "Listing not active");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        address paymentToken = _getPaymentToken();
        address nftContract = _getNFTContract();
        uint256 marketplaceFee = _getMarketplaceFee();

        // 计算手续费
        uint256 feeAmount = (listing.price * marketplaceFee) / 10000;
        uint256 sellerAmount = listing.price - feeAmount;

        // 先移除上架记录，防止重入攻击
        _removeListing(tokenId);

        // 转移支付代币
        require(
            IERC20(paymentToken).transferFrom(msg.sender, address(this), listing.price),
            "Payment transfer failed"
        );

        // 转移 NFT
        IERC721(nftContract).transferFrom(listing.seller, msg.sender, tokenId);

        // 分配资金
        if (sellerAmount > 0) {
            IERC20(paymentToken).transfer(listing.seller, sellerAmount);
        }

        // 更新手续费累计
        _setAccumulatedFees(_getAccumulatedFees() + feeAmount);

        emit NFTSold(tokenId, listing.seller, msg.sender, listing.price);
    }

    /**
     * @dev 下架 NFT
     * @param tokenId NFT 的 tokenId
     */
    function delist(uint256 tokenId) external {
        require(_listedTokenIds[tokenId], "NFT not listed");
        
        Listing storage listing = _listings[tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.active, "Listing not active");

        _removeListing(tokenId);
        emit NFTDelisted(tokenId, msg.sender);
    }

    /**
     * @dev 更新价格
     * @param tokenId NFT 的 tokenId
     * @param newPrice 新价格
     */
    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        require(_listedTokenIds[tokenId], "NFT not listed");
        require(newPrice > 0, "Price must be greater than 0");
        
        Listing storage listing = _listings[tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.active, "Listing not active");

        listing.price = newPrice;
        emit PriceUpdated(tokenId, msg.sender, newPrice);
    }

    /**
     * @dev 提取手续费（仅管理员）
     */
    function withdrawFees() external {
        address admin = _getAdmin();
        require(msg.sender == admin, "Only admin");
        
        uint256 fees = _getAccumulatedFees();
        require(fees > 0, "No fees to withdraw");

        _setAccumulatedFees(0);
        IERC20(_getPaymentToken()).transfer(admin, fees);

        emit FeesWithdrawn(admin, fees);
    }

    /**
     * @dev 设置市场手续费（仅管理员）
     * @param newFee 新手续费率（基点，如 250 = 2.5%）
     */
    function setMarketplaceFee(uint256 newFee) external {
        address admin = _getAdmin();
        require(msg.sender == admin, "Only admin");
        require(newFee <= 1000, "Fee too high"); // 最大 10%

        _setMarketplaceFee(newFee);
        emit MarketplaceFeeUpdated(newFee);
    }

    // 查询函数

    /**
     * @dev 获取所有已上架的 tokenId
     * @return 已上架的 tokenId 数组
     */
    function getListedTokenIds() external view returns (uint256[] memory) {
        return _allListedTokenIds;
    }

    /**
     * @dev 获取已上架 NFT 数量
     * @return 已上架 NFT 数量
     */
    function getListedCount() external view returns (uint256) {
        return _allListedTokenIds.length;
    }

    /**
     * @dev 检查 NFT 是否已上架
     * @param tokenId NFT 的 tokenId
     * @return 是否已上架
     */
    function isListed(uint256 tokenId) external view returns (bool) {
        return _listedTokenIds[tokenId];
    }

    /**
     * @dev 获取上架信息
     * @param tokenId NFT 的 tokenId
     * @return seller 卖家地址
     * @return price 价格
     * @return timestamp 上架时间
     * @return active 是否激活
     */
    function getListing(uint256 tokenId) external view returns (
        address seller,
        uint256 price,
        uint256 timestamp,
        bool active
    ) {
        require(_listedTokenIds[tokenId], "NFT not listed");
        Listing storage listing = _listings[tokenId];
        return (listing.seller, listing.price, listing.timestamp, listing.active);
    }

    /**
     * @dev 获取支付代币地址
     * @return 支付代币地址
     */
    function paymentToken() external view returns (address) {
        return _getPaymentToken();
    }

    /**
     * @dev 获取 NFT 合约地址
     * @return NFT 合约地址
     */
    function nftContract() external view returns (address) {
        return _getNFTContract();
    }

    /**
     * @dev 获取市场手续费率
     * @return 手续费率（基点）
     */
    function marketplaceFee() external view returns (uint256) {
        return _getMarketplaceFee();
    }

    /**
     * @dev 获取累计手续费
     * @return 累计手续费
     */
    function accumulatedFees() external view returns (uint256) {
        return _getAccumulatedFees();
    }

    /**
     * @dev 获取合约版本
     * @return 版本号
     */
    function version() external view returns (string memory) {
        return _getVersion();
    }

    // 内部函数

    /**
     * @dev 移除上架记录
     * @param tokenId NFT 的 tokenId
     */
    function _removeListing(uint256 tokenId) internal {
        delete _listings[tokenId];
        delete _listedTokenIds[tokenId];

        // 从数组中移除
        for (uint256 i = 0; i < _allListedTokenIds.length; i++) {
            if (_allListedTokenIds[i] == tokenId) {
                _allListedTokenIds[i] = _allListedTokenIds[_allListedTokenIds.length - 1];
                _allListedTokenIds.pop();
                break;
            }
        }
    }

    // 存储槽位操作函数

    function _getPaymentToken() internal view returns (address) {
        return address(uint160(uint256(_getStorageSlot(PAYMENT_TOKEN_SLOT))));
    }

    function _setPaymentToken(address _paymentToken) internal {
        _setStorageSlot(PAYMENT_TOKEN_SLOT, bytes32(uint256(uint160(_paymentToken))));
    }

    function _getNFTContract() internal view returns (address) {
        return address(uint160(uint256(_getStorageSlot(NFT_CONTRACT_SLOT))));
    }

    function _setNFTContract(address _nftContract) internal {
        _setStorageSlot(NFT_CONTRACT_SLOT, bytes32(uint256(uint160(_nftContract))));
    }

    function _getMarketplaceFee() internal view returns (uint256) {
        return uint256(_getStorageSlot(MARKETPLACE_FEE_SLOT));
    }

    function _setMarketplaceFee(uint256 _fee) internal {
        _setStorageSlot(MARKETPLACE_FEE_SLOT, bytes32(_fee));
    }

    function _getAccumulatedFees() internal view returns (uint256) {
        return uint256(_getStorageSlot(ACCUMULATED_FEES_SLOT));
    }

    function _setAccumulatedFees(uint256 _fees) internal {
        _setStorageSlot(ACCUMULATED_FEES_SLOT, bytes32(_fees));
    }

    function _getVersion() internal view returns (string memory) {
        bytes32 slot = _getStorageSlot(VERSION_SLOT);
        return _bytes32ToString(slot);
    }

    function _setVersion(string memory _version) internal {
        _setStorageSlot(VERSION_SLOT, _stringToBytes32(_version));
    }

    function _getAdmin() internal view returns (address) {
        return address(uint160(uint256(_getStorageSlot(ADMIN_SLOT))));
    }

    function _setAdmin(address _admin) internal {
        _setStorageSlot(ADMIN_SLOT, bytes32(uint256(uint160(_admin))));
    }

    function _getStorageSlot(bytes32 slot) internal view returns (bytes32) {
        bytes32 value;
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setStorageSlot(bytes32 slot, bytes32 value) internal {
        assembly {
            sstore(slot, value)
        }
    }

    function _stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
} 