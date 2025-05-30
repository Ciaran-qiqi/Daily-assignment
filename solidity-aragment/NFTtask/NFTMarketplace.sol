// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeERC721库
 * @dev 安全的ERC721调用库，处理NFT转移
 */
library SafeERC721 {
    using Address for address;
    
    function safeTransferFromMarket(BaseERC721 token, address from, address to, uint256 tokenId) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, tokenId));
    }
    
    function _callOptionalReturn(BaseERC721 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC721: low-level call failed");
        // ERC721 transferFrom通常不返回值，所以不检查返回值
    }
}

/**
 * @title SafeERC20库
 * @dev 安全的ERC20调用库，处理不规范的ERC20实现
 */
library SafeERC20 {
    using Address for address;
    
    function safeTransfer(BaseERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(BaseERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(BaseERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @title Address库
 * @dev 地址相关的实用函数
 */
library Address {
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @title BaseERC20接口
 * @dev 定义与BaseERC20代币交互所需的基本函数，与您的BaseERC20.sol合约匹配
 */
interface BaseERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
}

/**
 * @title BaseERC721接口
 * @dev 定义与BaseERC721 NFT交互所需的基本函数，与您的BaseERC721.sol合约匹配
 */
interface BaseERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function mint(address to, string memory tokenURI_) external returns (uint256);
    function owner() external view returns (address);
}

/**
 * @title NFT市场合约
 * @dev 允许用户使用ERC20代币买卖NFT的去中心化市场
 * @notice 实现NFT上架和购买功能，使用您的BaseERC20代币作为支付货币
 */
contract NFTMarketplace {
    using SafeERC20 for BaseERC20;
    using SafeERC721 for BaseERC721;
    
    // 支付代币合约实例（您的BaseERC20代币）
    BaseERC20 public paymentToken;
    // NFT合约实例（您的BaseERC721合约）
    BaseERC721 public nftContract;
    
    // 合约拥有者地址
    address public owner;
    
    // 市场手续费率（以基点为单位，100 = 1%）
    uint256 public marketplaceFee = 250; // 2.5%
    
    // 累计的手续费收入
    uint256 public accumulatedFees;
    
    // NFT上架信息结构体
    struct Listing {
        address seller;      // 卖家地址
        uint256 price;       // 价格（以ERC20代币为单位）
        bool active;         // 是否处于活跃状态
        uint256 listedAt;    // 上架时间戳
    }
    
    // NFT ID对应的上架信息
    mapping(uint256 => Listing) public listings;
    
    // 所有上架的NFT ID数组
    uint256[] public listedTokenIds;
    
    // NFT ID在数组中的索引映射
    mapping(uint256 => uint256) public tokenIdToIndex;
    
    // 事件定义
    // NFT上架事件
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 timestamp);
    // NFT购买事件  
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price, uint256 timestamp);
    // NFT下架事件
    event NFTDelisted(uint256 indexed tokenId, address indexed seller, uint256 timestamp);
    // 价格更新事件
    event PriceUpdated(uint256 indexed tokenId, address indexed seller, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    // 手续费提取事件
    event FeesWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);
    
    /**
     * @dev 修饰器：只有合约拥有者才能调用
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev 修饰器：检查NFT是否已上架
     */
    modifier onlyListed(uint256 tokenId) {
        require(listings[tokenId].active, "NFT is not listed for sale");
        _;
    }
    
    /**
     * @dev 修饰器：检查NFT是否未上架
     */
    modifier notListed(uint256 tokenId) {
        require(!listings[tokenId].active, "NFT is already listed");
        _;
    }
    
    /**
     * @dev 构造函数，初始化市场合约
     * @param _paymentToken ERC20支付代币合约地址（您的BaseERC20合约）
     * @param _nftContract ERC721 NFT合约地址（您的BaseERC721合约）
     */
    constructor(address _paymentToken, address _nftContract) {
        require(_paymentToken != address(0), "Payment token address cannot be zero");
        require(_nftContract != address(0), "NFT contract address cannot be zero");
        
        paymentToken = BaseERC20(_paymentToken);
        nftContract = BaseERC721(_nftContract);
        owner = msg.sender;
    }
    
    /**
     * @dev NFT持有者上架NFT到市场（按任务要求实现）
     * @param tokenId NFT的ID
     * @param price 售价（多少个ERC20代币购买此NFT）
     * @notice NFT持有者可以设置价格上架NFT
     * @notice 调用前需要先授权市场合约操作该NFT
     */
    function list(uint256 tokenId, uint256 price) external notListed(tokenId) {
        // 检查价格是否大于0
        require(price > 0, "Price must be greater than 0");
        
        // 检查调用者是否为NFT的拥有者
        require(nftContract.ownerOf(tokenId) == msg.sender, "You are not the owner of this NFT");
        
        // 检查市场合约是否已被授权操作该NFT
        require(
            nftContract.getApproved(tokenId) == address(this) || 
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Marketplace is not approved to transfer this NFT"
        );
        
        // 创建上架信息
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true,
            listedAt: block.timestamp
        });
        
        // 将NFT ID添加到上架列表
        tokenIdToIndex[tokenId] = listedTokenIds.length;
        listedTokenIds.push(tokenId);
        
        // 触发上架事件
        emit NFTListed(tokenId, msg.sender, price, block.timestamp);
    }
    
    /**
     * @dev 购买NFT（按任务要求实现buyNFT函数签名）
     * @param tokenID NFT的ID
     * @param amount 支付的代币数量
     * @notice 买家调用此函数购买上架的NFT
     * @notice 调用前需要先授权市场合约转移足够的ERC20代币
     */
    function buyNFT(uint256 tokenID, uint256 amount) external onlyListed(tokenID) {
        Listing storage listing = listings[tokenID];
        
        // 检查支付金额是否正确
        require(amount == listing.price, "Incorrect payment amount");
        
        // 检查买家不是卖家
        require(msg.sender != listing.seller, "Cannot buy your own NFT");
        
        // 检查买家是否有足够的代币余额
        require(paymentToken.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        
        // 检查NFT仍然属于卖家
        require(nftContract.ownerOf(tokenID) == listing.seller, "NFT is no longer owned by seller");
        
        // 计算手续费和卖家收入
        uint256 fee = (amount * marketplaceFee) / 10000;
        uint256 sellerAmount = amount - fee;
        
        // 转移代币：从买家到卖家（使用安全转账）
        paymentToken.safeTransferFrom(msg.sender, listing.seller, sellerAmount);
        
        // 转移手续费到合约（使用安全转账）
        if (fee > 0) {
            paymentToken.safeTransferFrom(msg.sender, address(this), fee);
            accumulatedFees += fee;
        }
        
        // 转移NFT：从卖家到买家（使用安全转移）
        nftContract.safeTransferFromMarket(listing.seller, msg.sender, tokenID);
        
        // 记录卖家和买家信息用于事件
        address seller = listing.seller;
        uint256 price = listing.price;
        
        // 从上架列表中移除NFT
        _removeListing(tokenID);
        
        // 触发购买事件
        emit NFTPurchased(tokenID, msg.sender, seller, price, block.timestamp);
    }
    
    /**
     * @dev 取消NFT上架
     * @param tokenId NFT的ID
     * @notice 只有NFT的卖家可以取消上架
     */
    function delist(uint256 tokenId) external onlyListed(tokenId) {
        Listing storage listing = listings[tokenId];
        
        // 检查调用者是否为卖家
        require(msg.sender == listing.seller, "Only seller can delist NFT");
        
        // 记录卖家信息用于事件
        address seller = listing.seller;
        
        // 从上架列表中移除NFT
        _removeListing(tokenId);
        
        // 触发下架事件
        emit NFTDelisted(tokenId, seller, block.timestamp);
    }
    
    /**
     * @dev 更新NFT价格
     * @param tokenId NFT的ID
     * @param newPrice 新的价格
     * @notice 只有NFT的卖家可以更新价格
     */
    function updatePrice(uint256 tokenId, uint256 newPrice) external onlyListed(tokenId) {
        require(newPrice > 0, "Price must be greater than 0");
        
        Listing storage listing = listings[tokenId];
        
        // 检查调用者是否为卖家
        require(msg.sender == listing.seller, "Only seller can update price");
        
        uint256 oldPrice = listing.price;
        listing.price = newPrice;
        
        // 触发价格更新事件
        emit PriceUpdated(tokenId, msg.sender, oldPrice, newPrice, block.timestamp);
    }
    
    /**
     * @dev 提取累计的手续费（只有拥有者可以调用）
     */
    function withdrawFees() external onlyOwner {
        require(accumulatedFees > 0, "No fees to withdraw");
        
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        
        // 使用安全转账将手续费转移给管理员
        paymentToken.safeTransfer(owner, amount);
        
        // 触发手续费提取事件
        emit FeesWithdrawn(owner, amount, block.timestamp);
    }
    
    /**
     * @dev 设置市场手续费率（只有拥有者可以调用）
     * @param newFee 新的手续费率（以基点为单位，100 = 1%）
     */
    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee cannot exceed 10%"); // 最大10%
        marketplaceFee = newFee;
    }
    
    /**
     * @dev 获取所有上架的NFT ID
     * @return 上架的NFT ID数组
     */
    function getListedTokenIds() external view returns (uint256[] memory) {
        return listedTokenIds;
    }
    
    /**
     * @dev 获取上架NFT的数量
     * @return 上架NFT的总数
     */
    function getListedCount() external view returns (uint256) {
        return listedTokenIds.length;
    }
    
    /**
     * @dev 检查NFT是否已上架
     * @param tokenId NFT的ID
     * @return 是否已上架
     */
    function isListed(uint256 tokenId) external view returns (bool) {
        return listings[tokenId].active;
    }
    
    /**
     * @dev 获取NFT的上架信息
     * @param tokenId NFT的ID
     * @return seller 卖家地址
     * @return price 价格
     * @return active 是否活跃
     * @return listedAt 上架时间
     */
    function getListing(uint256 tokenId) external view returns (
        address seller,
        uint256 price,
        bool active,
        uint256 listedAt
    ) {
        Listing storage listing = listings[tokenId];
        return (listing.seller, listing.price, listing.active, listing.listedAt);
    }
    
    /**
     * @dev 批量获取NFT上架信息
     * @param tokenIds NFT ID数组
     * @return sellers 卖家地址数组
     * @return prices 价格数组
     * @return actives 活跃状态数组
     * @return listedAts 上架时间数组
     */
    function getBatchListings(uint256[] calldata tokenIds) external view returns (
        address[] memory sellers,
        uint256[] memory prices,
        bool[] memory actives,
        uint256[] memory listedAts
    ) {
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
     * @dev 内部函数：从上架列表中移除NFT
     * @param tokenId NFT的ID
     */
    function _removeListing(uint256 tokenId) internal {
        // 获取要删除的NFT在数组中的索引
        uint256 index = tokenIdToIndex[tokenId];
        uint256 lastIndex = listedTokenIds.length - 1;
        
        // 如果不是最后一个元素，将最后一个元素移到当前位置
        if (index != lastIndex) {
            uint256 lastTokenId = listedTokenIds[lastIndex];
            listedTokenIds[index] = lastTokenId;
            tokenIdToIndex[lastTokenId] = index;
        }
        
        // 删除最后一个元素
        listedTokenIds.pop();
        
        // 删除映射
        delete tokenIdToIndex[tokenId];
        delete listings[tokenId];
    }
} 