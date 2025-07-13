// SPDX-License-Identifier: MIT
// wake-disable unsafe-erc20-call 
// wake-disable unsafe-transfer
// wake-disable unchecked-return-value

pragma solidity ^0.8.20;

import "./AdvancedERC20.sol";
import "./BaseERC721.sol";
import "./SigUtils.sol";

/**
 * @title NFTMarket
 * @dev 复杂版NFT市场，支持上架、下架、价格管理、手续费、批量查询、合约拥有者权限，并集成EIP-2612离线签名购买功能和白名单验证。
 */
contract NFTMarket {
    // 支付ERC20代币合约
    AdvancedERC20 public paymentToken;
    // NFT合约
    BaseERC721 public nftContract;
    // 合约拥有者
    address public owner;
    // 市场手续费率（基点，100=1%）
    uint256 public marketplaceFee = 250; // 2.5%
    // 累计手续费收入
    uint256 public accumulatedFees;

    // EIP-712 域分隔符
    bytes32 public immutable DOMAIN_SEPARATOR;
    // 购买结构体类型hash
    bytes32 public constant BUY_TYPEHASH = keccak256("Buy(address buyer,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)");
    // 用户nonce映射，防止重放攻击
    mapping(address => uint256) public nonces;

    // 上架信息结构体
    struct Listing {
        address seller;
        uint256 price;
        bool active;
        uint256 listedAt;
    }
    // NFT ID => 上架信息
    mapping(uint256 => Listing) public listings;
    // 所有上架NFT ID
    uint256[] public listedTokenIds;
    // NFT ID => 上架数组索引
    mapping(uint256 => uint256) public tokenIdToIndex;

    // 事件
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 timestamp);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price, uint256 timestamp);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller, uint256 timestamp);
    event PriceUpdated(uint256 indexed tokenId, address indexed seller, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event FeesWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);

    // 只有合约拥有者
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    // 必须已上架
    modifier onlyListed(uint256 tokenId) {
        require(listings[tokenId].active, "Not listed");
        _;
    }
    // 必须未上架
    modifier notListed(uint256 tokenId) {
        require(!listings[tokenId].active, "Already listed");
        _;
    }

    /**
     * @dev 构造函数，初始化合约
     * @param _paymentToken ERC20合约地址
     * @param _nftContract NFT合约地址
     * @param name_ EIP-712域名
     * @param version_ EIP-712版本
     */
    constructor(address _paymentToken, address _nftContract, string memory name_, string memory version_) {
        require(_paymentToken != address(0), "paymentToken zero");
        require(_nftContract != address(0), "nftContract zero");
        paymentToken = AdvancedERC20(_paymentToken);
        nftContract = BaseERC721(_nftContract);
        owner = msg.sender;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name_)),
                keccak256(bytes(version_)),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev 上架NFT
     * @param tokenId NFT编号
     * @param price 价格
     */
    function list(uint256 tokenId, uint256 price) external notListed(tokenId) {
        require(price > 0, "Price=0");
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not owner");
        require(
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true,
            listedAt: block.timestamp
        });
        tokenIdToIndex[tokenId] = listedTokenIds.length;
        listedTokenIds.push(tokenId);
        emit NFTListed(tokenId, msg.sender, price, block.timestamp);
    }

    /**
     * @dev 下架NFT
     * @param tokenId NFT编号
     */
    function delist(uint256 tokenId) external onlyListed(tokenId) {
        Listing storage listing = listings[tokenId];
        require(msg.sender == listing.seller, "Not seller");
        address seller = listing.seller;
        _removeListing(tokenId);
        emit NFTDelisted(tokenId, seller, block.timestamp);
    }

    /**
     * @dev 更新NFT价格
     * @param tokenId NFT编号
     * @param newPrice 新价格
     */
    function updatePrice(uint256 tokenId, uint256 newPrice) external onlyListed(tokenId) {
        require(newPrice > 0, "Price=0");
        Listing storage listing = listings[tokenId];
        require(msg.sender == listing.seller, "Not seller");
        uint256 oldPrice = listing.price;
        listing.price = newPrice;
        emit PriceUpdated(tokenId, msg.sender, oldPrice, newPrice, block.timestamp);
    }

    /**
     * @dev 传统购买NFT方式（需要提前approve）
     * @param tokenId NFT编号
     */
    function buyNFT(uint256 tokenId) external onlyListed(tokenId) {
        Listing storage listing = listings[tokenId];
        uint256 amount = listing.price;
        require(msg.sender != listing.seller, "Self buy");
        require(paymentToken.balanceOf(msg.sender) >= amount, "No balance");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT not owned");
        
        // 计算手续费
        uint256 fee = (amount * marketplaceFee) / 10000;
        uint256 sellerAmount = amount - fee;
        
        // 代币转账：买家->卖家
        require(paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount), "pay fail");
        
        // 代币转账：买家->平台
        if (fee > 0) {
            require(paymentToken.transferFrom(msg.sender, address(this), fee), "fee fail");
            accumulatedFees += fee;
        }
        
        // NFT转移
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);
        address seller = listing.seller;
        uint256 price = listing.price;
        _removeListing(tokenId);
        emit NFTPurchased(tokenId, msg.sender, seller, price, block.timestamp);
    }

    /**
     * @dev 通过EIP-2612 Permit签名授权购买NFT，无需提前approve
     * @param tokenId NFT编号
     * @param deadline 签名有效截止时间
     * @param v,r,s 用户签名参数（用于permit授权）
     */
    function buyNFTWithPermit(
        uint256 tokenId, 
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external onlyListed(tokenId) {
        Listing storage listing = listings[tokenId];
        uint256 amount = listing.price;
        require(msg.sender != listing.seller, "Self buy");
        require(paymentToken.balanceOf(msg.sender) >= amount, "No balance");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT not owned");
        
        // 使用EIP-2612 permit签名授权本合约转账用户的代币
        paymentToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // 计算手续费
        uint256 fee = (amount * marketplaceFee) / 10000;
        uint256 sellerAmount = amount - fee;
        
        // 代币转账：买家->卖家（无需提前approve）
        require(paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount), "pay fail");
        
        // 代币转账：买家->平台
        if (fee > 0) {
            require(paymentToken.transferFrom(msg.sender, address(this), fee), "fee fail");
            accumulatedFees += fee;
        }
        
        // NFT转移
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);
        address seller = listing.seller;
        uint256 price = listing.price;
        _removeListing(tokenId);
        emit NFTPurchased(tokenId, msg.sender, seller, price, block.timestamp);
    }

    /**
     * @dev 通过EIP-2612 Permit + EIP-712白名单验证购买NFT
     * @param tokenId NFT编号
     * @param deadline 签名有效截止时间
     * @param v,r,s 用户签名参数（用于permit授权）
     * @param buyV,buyR,buyS 卖家/平台签名参数（用于白名单验证）
     */
    function buyNFTWithPermitAndWhitelist(
        uint256 tokenId, 
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s,
        uint8 buyV, bytes32 buyR, bytes32 buyS
    ) external onlyListed(tokenId) {
        Listing storage listing = listings[tokenId];
        uint256 amount = listing.price;
        require(msg.sender != listing.seller, "Self buy");
        require(paymentToken.balanceOf(msg.sender) >= amount, "No balance");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT not owned");
        require(block.timestamp <= deadline, "Signature expired");
        
        // 1. 使用EIP-2612 permit签名授权本合约转账用户的代币
        paymentToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // 2. 校验EIP-712离线签名（白名单授权）
        uint256 nonce = nonces[msg.sender]++;
        bytes32 structHash = keccak256(abi.encode(BUY_TYPEHASH, msg.sender, tokenId, amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = SigUtils.recoverSigner(digest, buyV, buyR, buyS);
        require(signer == listing.seller || signer == owner, "Invalid whitelist sig");
        
        // 3. 计算手续费
        uint256 fee = (amount * marketplaceFee) / 10000;
        uint256 sellerAmount = amount - fee;
        
        // 4. 代币转账：买家->卖家（无需提前approve）
        require(paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount), "pay fail");
        
        // 5. 代币转账：买家->平台
        if (fee > 0) {
            require(paymentToken.transferFrom(msg.sender, address(this), fee), "fee fail");
            accumulatedFees += fee;
        }
        
        // 6. NFT转移
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);
        address seller = listing.seller;
        uint256 price = listing.price;
        _removeListing(tokenId);
        emit NFTPurchased(tokenId, msg.sender, seller, price, block.timestamp);
    }

    /**
     * @dev 提现手续费（仅拥有者）
     */
    function withdrawFees() external onlyOwner {
        require(accumulatedFees > 0, "No fees");
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        require(paymentToken.transfer(owner, amount), "withdraw fail");
        emit FeesWithdrawn(owner, amount, block.timestamp);
    }

    /**
     * @dev 设置市场手续费率（仅拥有者）
     * @param newFee 新手续费率（基点）
     */
    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee>10%");
        marketplaceFee = newFee;
    }

    /** 查询相关接口 **/
    function getListedTokenIds() external view returns (uint256[] memory) {
        return listedTokenIds;
    }
    function getListedCount() external view returns (uint256) {
        return listedTokenIds.length;
    }
    function isListed(uint256 tokenId) external view returns (bool) {
        return listings[tokenId].active;
    }
    function getListing(uint256 tokenId) external view returns (address seller, uint256 price, bool active, uint256 listedAt) {
        Listing storage listing = listings[tokenId];
        return (listing.seller, listing.price, listing.active, listing.listedAt);
    }
    function getBatchListings(uint256[] calldata tokenIds) external view returns (address[] memory sellers, uint256[] memory prices, bool[] memory actives, uint256[] memory listedAts) {
        uint256 length = tokenIds.length;
        sellers = new address[](length);
        prices = new uint256[](length);
        actives = new bool[](length);
        listedAts = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            Listing storage listing = listings[tokenIds[i]];
            sellers[i] = listing.seller;
            prices[i] = listing.price;
            actives[i] = listing.active;
            listedAts[i] = listing.listedAt;
        }
    }

    /**
     * @dev 内部函数：移除上架NFT
     */
    function _removeListing(uint256 tokenId) internal {
        uint256 index = tokenIdToIndex[tokenId];
        uint256 lastIndex = listedTokenIds.length - 1;
        if (index != lastIndex) {
            uint256 lastTokenId = listedTokenIds[lastIndex];
            listedTokenIds[index] = lastTokenId;
            tokenIdToIndex[lastTokenId] = index;
        }
        listedTokenIds.pop();
        delete tokenIdToIndex[tokenId];
        delete listings[tokenId];
    }
} 