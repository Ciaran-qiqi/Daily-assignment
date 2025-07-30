// SPDX-License-Identifier: MIT
// wake-disable unsafe-erc20-call 
// wake-disable unsafe-transfer
// wake-disable unchecked-return-value
// wake-disable reentrancy


pragma solidity ^0.8.19;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/**
 * @title TP-NFTMarketV2
 * @dev 可升级NFT市场合约的第二个版本（透明代理版本）
 * 在V1基础上添加离线签名上架NFT功能
 */
contract TP_NFTMarketV2 {
    // 存储槽布局 (保持与V1兼容)
    // 槽0: 实现地址 (address) - 由代理合约使用
    // 槽1: 管理员地址 (address) - 由代理合约使用
    // 槽2: 支付代币地址 (address)
    // 槽3: NFT合约地址 (address)
    // 槽4: 市场手续费率 (uint256)
    // 槽5: 累计手续费 (uint256)
    // 槽6: 版本号 (string)
    // 槽7: 签名域名分隔符 (bytes32) - 新增
    
    bytes32 private constant PAYMENT_TOKEN_SLOT = bytes32(uint256(2));
    bytes32 private constant NFT_CONTRACT_SLOT = bytes32(uint256(3));
    bytes32 private constant MARKETPLACE_FEE_SLOT = bytes32(uint256(4));
    bytes32 private constant ACCUMULATED_FEES_SLOT = bytes32(uint256(5));
    bytes32 private constant VERSION_SLOT = bytes32(uint256(6));
    bytes32 private constant DOMAIN_SEPARATOR_SLOT = bytes32(uint256(7));
    
    // 签名类型哈希
    bytes32 private constant LIST_TYPEHASH = keccak256("ListNFT(uint256 tokenId,uint256 price,uint256 nonce)");
    
    // 用户nonce映射，防止重放攻击
    mapping(address => uint256) private _nonces;
    
    // NFT上架信息结构体 - 与V1保持兼容
    struct Listing {
        address seller;        // 卖家地址
        uint256 price;         // 价格
        uint256 timestamp;     // 上架时间（与V1兼容）
        bool active;           // 是否激活
    }
    
    // NFT ID对应的上架信息
    mapping(uint256 => Listing) private _listings;
    
    // tokenId => 是否已上架（与V1兼容）
    mapping(uint256 => bool) private _listedTokenIds;
    
    // 所有已上架的 tokenId 列表（与V1兼容）
    uint256[] private _allListedTokenIds;
    
    // 事件定义
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 timestamp);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price, uint256 timestamp);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller, uint256 timestamp);
    event PriceUpdated(uint256 indexed tokenId, address indexed seller, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event FeesWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);
    event NFTListedWithSignature(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 nonce, uint256 timestamp);
    
    /**
     * @dev 初始化函数
     * @param _paymentToken 支付代币地址
     * @param _nftContract NFT合约地址
     */
    function initialize(address _paymentToken, address _nftContract) external {
        require(_getPaymentToken() == address(0), "Already initialized");
        require(_paymentToken != address(0), "Invalid payment token");
        require(_nftContract != address(0), "Invalid NFT contract");
        
        _setPaymentToken(_paymentToken);
        _setNFTContract(_nftContract);
        _setMarketplaceFee(250); // 2.5%
        _setAccumulatedFees(0);
        _setVersion("2.0.0");
        _setDomainSeparator(_buildDomainSeparator());
    }

    /**
     * @dev 升级后的初始化函数
     */
    function upgradeInitialize() external {
        _setVersion("2.0.0");
        _setDomainSeparator(_buildDomainSeparator());
    }
    
    /**
     * @dev NFT持有者上架NFT到市场（V1功能）
     * @param tokenId NFT的ID
     * @param price 售价
     */
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(!_listings[tokenId].active, "NFT is already listed");
        
        IERC721 nftContract = IERC721(_getNFTContract());
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );
        
        _listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            timestamp: block.timestamp,
            active: true
        });
        
        _listedTokenIds[tokenId] = true;
        _allListedTokenIds.push(tokenId);
        
        emit NFTListed(tokenId, msg.sender, price, block.timestamp);
    }
    
    /**
     * @dev 使用签名上架NFT（V2新功能）
     * @param tokenId NFT的ID
     * @param price 售价
     * @param deadline 签名过期时间
     * @param v 签名v值
     * @param r 签名r值
     * @param s 签名s值
     */
    function listWithSignature(
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(price > 0, "Price must be greater than 0");
        require(!_listings[tokenId].active, "NFT is already listed");
        require(block.timestamp <= deadline, "Signature expired");
        
        IERC721 nftContract = IERC721(_getNFTContract());
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );
        
        // 验证签名
        bytes32 structHash = keccak256(abi.encode(LIST_TYPEHASH, tokenId, price, _nonces[msg.sender]));
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", _getDomainSeparator(), structHash));
        address signer = ecrecover(hash, v, r, s);
        require(signer == msg.sender, "Invalid signature");
        
        // 增加nonce防止重放攻击
        _nonces[msg.sender]++;
        
        _listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            timestamp: block.timestamp,
            active: true
        });
        
        _listedTokenIds[tokenId] = true;
        _allListedTokenIds.push(tokenId);
        
        emit NFTListedWithSignature(tokenId, msg.sender, price, _nonces[msg.sender] - 1, block.timestamp);
    }
    
    /**
     * @dev 购买NFT
     * @param tokenId NFT的ID
     * @param amount 支付的代币数量
     */
    
    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing storage listing = _listings[tokenId];
        require(listing.active, "NFT not listed");
        require(amount == listing.price, "Incorrect amount");
        require(msg.sender != listing.seller, "Cannot buy own NFT");
        
        IERC20 paymentToken = IERC20(_getPaymentToken());
        IERC721 nftContract = IERC721(_getNFTContract());
        
        require(paymentToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT not owned by seller");
        
        uint256 fee = (amount * _getMarketplaceFee()) / 10000;
        uint256 sellerAmount = amount - fee;
        
        // 先移除上架记录，防止重入攻击
        _removeListing(tokenId);
        
        paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount);
        
        if (fee > 0) {
            paymentToken.transferFrom(msg.sender, address(this), fee);
            _setAccumulatedFees(_getAccumulatedFees() + fee);
        }
        
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);
        
        address seller = listing.seller;
        uint256 price = listing.price;
        
        emit NFTPurchased(tokenId, msg.sender, seller, price, block.timestamp);
    }
    
    /**
     * @dev 取消NFT上架
     * @param tokenId NFT的ID
     */
    function delist(uint256 tokenId) external {
        Listing storage listing = _listings[tokenId];
        require(listing.active, "NFT not listed");
        require(msg.sender == listing.seller, "Not the seller");
        
        address seller = listing.seller;
        _removeListing(tokenId);
        
        emit NFTDelisted(tokenId, seller, block.timestamp);
    }
    
    /**
     * @dev 更新NFT价格
     * @param tokenId NFT的ID
     * @param newPrice 新的价格
     */
    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than 0");
        
        Listing storage listing = _listings[tokenId];
        require(listing.active, "NFT not listed");
        require(msg.sender == listing.seller, "Not the seller");
        
        uint256 oldPrice = listing.price;
        listing.price = newPrice;
        
        emit PriceUpdated(tokenId, msg.sender, oldPrice, newPrice, block.timestamp);
    }
    
    /**
     * @dev 提取手续费
     */
    function withdrawFees() external {
        require(msg.sender == _getAdmin(), "Only admin can withdraw");
        
        uint256 amount = _getAccumulatedFees();
        require(amount > 0, "No fees to withdraw");
        
        _setAccumulatedFees(0);
        IERC20(_getPaymentToken()).transfer(msg.sender, amount);
        
        emit FeesWithdrawn(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev 设置市场手续费率
     * @param newFee 新的手续费率
     */
    function setMarketplaceFee(uint256 newFee) external {
        require(msg.sender == _getAdmin(), "Only admin can set fee");
        require(newFee <= 1000, "Fee cannot exceed 10%");
        _setMarketplaceFee(newFee);
    }
    
    /**
     * @dev 变更业务管理员（仅当前业务管理员可调用）
     * @param newAdmin 新的业务管理员地址
     *
     * 详细说明：
     * 1. 只有当前业务管理员（即 _getAdmin() 返回的地址，通常为代理合约地址）可以调用本函数。
     * 2. 推荐在升级到V2时，使用 upgradeToAndCall 一步调用本函数，将业务管理员切换为自己的钱包地址。
     * 3. 该函数会将业务管理员槽（slot1）直接更新为 newAdmin。
     * 4. 这样升级后可以安全地将业务权限转交给自己的钱包或多签。
     */
    function changeBusinessAdmin(address newAdmin) external {
        require(msg.sender == _getAdmin(), "Only admin can change business admin");
        require(newAdmin != address(0), "New admin cannot be zero address");
        assembly {
            sstore(0x1, newAdmin)
        }
    }

    // 查询函数
    function getListedTokenIds() external view returns (uint256[] memory) {
        return _allListedTokenIds;
    }
    
    function getListedCount() external view returns (uint256) {
        return _allListedTokenIds.length;
    }
    
    function isListed(uint256 tokenId) external view returns (bool) {
        return _listings[tokenId].active;
    }
    
    function getListing(uint256 tokenId) external view returns (
        address seller, uint256 price, bool active, uint256 timestamp
    ) {
        Listing storage listing = _listings[tokenId];
        return (listing.seller, listing.price, listing.active, listing.timestamp);
    }
    
    function paymentToken() external view returns (address) {
        return _getPaymentToken();
    }
    
    function nftContract() external view returns (address) {
        return _getNFTContract();
    }
    
    function marketplaceFee() external view returns (uint256) {
        return _getMarketplaceFee();
    }
    
    function accumulatedFees() external view returns (uint256) {
        return _getAccumulatedFees();
    }
    
    function version() external view returns (string memory) {
        return _getVersion();
    }
    
    /**
     * @dev 获取用户nonce
     * @param user 用户地址
     * @return nonce值
     */
    function nonces(address user) external view returns (uint256) {
        return _nonces[user];
    }
    
    /**
     * @dev 获取域名分隔符
     * @return 域名分隔符
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _getDomainSeparator();
    }
    
    // 内部函数
    function _removeListing(uint256 tokenId) internal {
        // 从数组中移除tokenId
        for (uint256 i = 0; i < _allListedTokenIds.length; i++) {
            if (_allListedTokenIds[i] == tokenId) {
                _allListedTokenIds[i] = _allListedTokenIds[_allListedTokenIds.length - 1];
                _allListedTokenIds.pop();
                break;
            }
        }
        
        delete _listedTokenIds[tokenId];
        delete _listings[tokenId];
    }
    
    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NFTMarketV2")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
    
    // 存储槽操作函数
    function _getPaymentToken() internal view returns (address) {
        address token;
        assembly {
            token := sload(0x2)
        }
        return token;
    }
    
    function _setPaymentToken(address token) internal {
        assembly {
            sstore(0x2, token)
        }
    }
    
    function _getNFTContract() internal view returns (address) {
        address nft;
        assembly {
            nft := sload(0x3)
        }
        return nft;
    }
    
    function _setNFTContract(address nft) internal {
        assembly {
            sstore(0x3, nft)
        }
    }
    
    function _getMarketplaceFee() internal view returns (uint256) {
        uint256 fee;
        assembly {
            fee := sload(0x4)
        }
        return fee;
    }
    
    function _setMarketplaceFee(uint256 fee) internal {
        assembly {
            sstore(0x4, fee)
        }
    }
    
    function _getAccumulatedFees() internal view returns (uint256) {
        uint256 fees;
        assembly {
            fees := sload(0x5)
        }
        return fees;
    }
    
    function _setAccumulatedFees(uint256 fees) internal {
        assembly {
            sstore(0x5, fees)
        }
    }
    
    function _getVersion() internal view returns (string memory) {
        bytes32 versionHash;
        assembly {
            versionHash := sload(0x6)
        }
        if (versionHash == keccak256(abi.encodePacked("2.0.0"))) {
            return "2.0.0";
        }
        return "";
    }
    
    function _setVersion(string memory version) internal {
        bytes32 versionHash = keccak256(abi.encodePacked(version));
        assembly {
            sstore(0x6, versionHash)
        }
    }
    
    function _getDomainSeparator() internal view returns (bytes32) {
        bytes32 separator;
        assembly {
            separator := sload(0x7)
        }
        return separator;
    }
    
    function _setDomainSeparator(bytes32 separator) internal {
        assembly {
            sstore(0x7, separator)
        }
    }
    
    function _getAdmin() internal view returns (address) {
        address admin;
        assembly {
            admin := sload(0x1)
        }
        return admin;
    }
} 