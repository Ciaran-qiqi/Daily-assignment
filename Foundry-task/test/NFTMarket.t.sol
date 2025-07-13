// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "../src/AdvancedERC20.sol";
import "../src/BaseERC721.sol";

/**
 * @title NFTMarketTest
 * @dev NFTMarket合约的完整测试套件
 */
contract NFTMarketTest is Test {
    NFTMarket public nftMarket;
    AdvancedERC20 public paymentToken;
    BaseERC721 public nftContract;
    
    address public owner = address(this);
    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public buyer2 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    uint256 public constant MARKETPLACE_FEE = 250; // 2.5%
    
    uint256 public tokenId1 = 1;
    uint256 public tokenId2 = 2;
    uint256 public tokenId3 = 3;
    
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 timestamp);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price, uint256 timestamp);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller, uint256 timestamp);
    event PriceUpdated(uint256 indexed tokenId, address indexed seller, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event FeesWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);

    function setUp() public {
        // 部署代币合约
        paymentToken = new AdvancedERC20("PaymentToken", "PT", 1000000);
        nftContract = new BaseERC721();
        
        // 部署NFT市场
        nftMarket = new NFTMarket(address(paymentToken), address(nftContract), "NFTMarket", "1.0");
        
        // 分配代币给用户
        paymentToken.transfer(seller, INITIAL_SUPPLY / 4);
        paymentToken.transfer(buyer, INITIAL_SUPPLY / 4);
        paymentToken.transfer(buyer2, INITIAL_SUPPLY / 4);
        
        // 铸造NFT给卖家
        nftContract.mint(seller, tokenId1);
        nftContract.mint(seller, tokenId2);
        nftContract.mint(seller, tokenId3);
    }

    // ========== 基础功能测试 ==========
    
    function test_Constructor() public {
        assertEq(address(nftMarket.paymentToken()), address(paymentToken));
        assertEq(address(nftMarket.nftContract()), address(nftContract));
        assertEq(nftMarket.owner(), owner);
        assertEq(nftMarket.marketplaceFee(), MARKETPLACE_FEE);
    }
    
    function test_InitialState() public {
        assertEq(nftMarket.getListedCount(), 0);
        assertEq(nftMarket.accumulatedFees(), 0);
    }

    // ========== NFT上架测试 ==========
    
    function test_ListNFT() public {
        vm.startPrank(seller);
        
        // 授权NFT市场
        nftContract.approve(address(nftMarket), tokenId1);
        
        // 上架NFT
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.stopPrank();
        
        // 验证上架成功
        (address listingSeller, uint256 price, bool active, uint256 listedAt) = nftMarket.getListing(tokenId1);
        assertEq(listingSeller, seller);
        assertEq(price, NFT_PRICE);
        assertTrue(active);
        assertGt(listedAt, 0);
        
        assertEq(nftMarket.getListedCount(), 1);
        assertTrue(nftMarket.isListed(tokenId1));
    }
    
    function test_ListNFTMultiple() public {
        vm.startPrank(seller);
        
        // 授权多个NFT
        nftContract.approve(address(nftMarket), tokenId1);
        nftContract.approve(address(nftMarket), tokenId2);
        
        // 上架多个NFT
        nftMarket.list(tokenId1, NFT_PRICE);
        nftMarket.list(tokenId2, NFT_PRICE * 2);
        
        vm.stopPrank();
        
        // 验证上架成功
        assertEq(nftMarket.getListedCount(), 2);
        assertTrue(nftMarket.isListed(tokenId1));
        assertTrue(nftMarket.isListed(tokenId2));
    }
    
    function test_ListNFTNotOwner() public {
        vm.startPrank(buyer);
        
        nftContract.approve(address(nftMarket), tokenId1);
        
        vm.expectRevert("Not owner");
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.stopPrank();
    }
    
    function test_ListNFTNotApproved() public {
        vm.startPrank(seller);
        
        vm.expectRevert("Not approved");
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.stopPrank();
    }
    
    function test_ListNFTZeroPrice() public {
        vm.startPrank(seller);
        
        nftContract.approve(address(nftMarket), tokenId1);
        
        vm.expectRevert("Price=0");
        nftMarket.list(tokenId1, 0);
        
        vm.stopPrank();
    }
    
    function test_ListNFTAlreadyListed() public {
        vm.startPrank(seller);
        
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.expectRevert("Already listed");
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.stopPrank();
    }

    // ========== NFT下架测试 ==========
    
    function test_DelistNFT() public {
        // 先上架
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        
        // 下架
        nftMarket.delist(tokenId1);
        
        vm.stopPrank();
        
        // 验证下架成功
        assertEq(nftMarket.getListedCount(), 0);
        assertFalse(nftMarket.isListed(tokenId1));
    }
    
    function test_DelistNFTNotSeller() public {
        // 先上架
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 其他人尝试下架
        vm.startPrank(buyer);
        vm.expectRevert("Not seller");
        nftMarket.delist(tokenId1);
        vm.stopPrank();
    }
    
    function test_DelistNFTNotListed() public {
        vm.startPrank(seller);
        
        vm.expectRevert("Not listed");
        nftMarket.delist(tokenId1);
        
        vm.stopPrank();
    }

    // ========== 价格更新测试 ==========
    
    function test_UpdatePrice() public {
        // 先上架
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        
        uint256 newPrice = NFT_PRICE * 2;
        nftMarket.updatePrice(tokenId1, newPrice);
        
        vm.stopPrank();
        
        // 验证价格更新
        (address listingSeller, uint256 price, bool active, ) = nftMarket.getListing(tokenId1);
        assertEq(price, newPrice);
        assertTrue(active);
    }
    
    function test_UpdatePriceNotSeller() public {
        // 先上架
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 其他人尝试更新价格
        vm.startPrank(buyer);
        vm.expectRevert("Not seller");
        nftMarket.updatePrice(tokenId1, NFT_PRICE * 2);
        vm.stopPrank();
    }
    
    function test_UpdatePriceZeroPrice() public {
        // 先上架
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.expectRevert("Price=0");
        nftMarket.updatePrice(tokenId1, 0);
        
        vm.stopPrank();
    }

    // ========== 传统购买测试 ==========
    
    function test_BuyNFT() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 买家购买
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), NFT_PRICE);
        nftMarket.buyNFT(tokenId1);
        vm.stopPrank();
        
        // 验证购买成功
        assertEq(nftContract.ownerOf(tokenId1), buyer);
        assertFalse(nftMarket.isListed(tokenId1));
        assertEq(nftMarket.getListedCount(), 0);
        
        // 验证资金分配
        uint256 fee = (NFT_PRICE * MARKETPLACE_FEE) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        assertEq(paymentToken.balanceOf(seller), sellerAmount);
        assertEq(nftMarket.accumulatedFees(), fee);
    }
    
    function test_BuyNFTInsufficientBalance() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 买家余额不足
        vm.startPrank(buyer2);
        paymentToken.approve(address(nftMarket), NFT_PRICE);
        
        vm.expectRevert("No balance");
        nftMarket.buyNFT(tokenId1);
        
        vm.stopPrank();
    }
    
    function test_BuyNFTSelfBuy() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.expectRevert("Self buy");
        nftMarket.buyNFT(tokenId1);
        
        vm.stopPrank();
    }

    // ========== EIP-2612 Permit购买测试 ==========
    
    function test_BuyNFTWithPermit() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 买家使用permit购买
        vm.startPrank(buyer);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成permit签名
        bytes32 domainSeparator = paymentToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer,
            address(nftMarket),
            NFT_PRICE,
            paymentToken.nonces(buyer),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey(), digest);
        
        nftMarket.buyNFTWithPermit(tokenId1, deadline, v, r, s);
        
        vm.stopPrank();
        
        // 验证购买成功
        assertEq(nftContract.ownerOf(tokenId1), buyer);
        assertFalse(nftMarket.isListed(tokenId1));
    }
    
    function test_BuyNFTWithPermitExpired() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 买家使用过期permit
        vm.startPrank(buyer);
        
        uint256 deadline = block.timestamp - 1 hours; // 已过期
        
        bytes32 domainSeparator = paymentToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer,
            address(nftMarket),
            NFT_PRICE,
            paymentToken.nonces(buyer),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey(), digest);
        
        vm.expectRevert("Permit failed");
        nftMarket.buyNFTWithPermit(tokenId1, deadline, v, r, s);
        
        vm.stopPrank();
    }

    // ========== EIP-2612 + EIP-712 白名单购买测试 ==========
    
    function test_BuyNFTWithPermitAndWhitelist() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 买家使用permit+白名单购买
        vm.startPrank(buyer);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成permit签名
        bytes32 domainSeparator = paymentToken.DOMAIN_SEPARATOR();
        bytes32 permitStructHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer,
            address(nftMarket),
            NFT_PRICE,
            paymentToken.nonces(buyer),
            deadline
        ));
        bytes32 permitDigest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, permitStructHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey(), permitDigest);
        
        // 生成白名单签名（卖家签名）
        bytes32 buyTypeHash = nftMarket.BUY_TYPEHASH();
        bytes32 buyStructHash = keccak256(abi.encode(buyTypeHash, buyer, tokenId1, NFT_PRICE, nftMarket.nonces(buyer), deadline));
        bytes32 buyDigest = keccak256(abi.encodePacked("\x19\x01", nftMarket.DOMAIN_SEPARATOR(), buyStructHash));
        
        (uint8 buyV, bytes32 buyR, bytes32 buyS) = vm.sign(sellerPrivateKey(), buyDigest);
        
        nftMarket.buyNFTWithPermitAndWhitelist(tokenId1, deadline, v, r, s, buyV, buyR, buyS);
        
        vm.stopPrank();
        
        // 验证购买成功
        assertEq(nftContract.ownerOf(tokenId1), buyer);
        assertFalse(nftMarket.isListed(tokenId1));
    }
    
    function test_BuyNFTWithPermitAndWhitelistInvalidSignature() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 买家使用错误的签名
        vm.startPrank(buyer);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成permit签名
        bytes32 domainSeparator = paymentToken.DOMAIN_SEPARATOR();
        bytes32 permitStructHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer,
            address(nftMarket),
            NFT_PRICE,
            paymentToken.nonces(buyer),
            deadline
        ));
        bytes32 permitDigest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, permitStructHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey(), permitDigest);
        
        // 使用错误的签名者
        bytes32 buyTypeHash = nftMarket.BUY_TYPEHASH();
        bytes32 buyStructHash = keccak256(abi.encode(buyTypeHash, buyer, tokenId1, NFT_PRICE, nftMarket.nonces(buyer), deadline));
        bytes32 buyDigest = keccak256(abi.encodePacked("\x19\x01", nftMarket.DOMAIN_SEPARATOR(), buyStructHash));
        
        (uint8 buyV, bytes32 buyR, bytes32 buyS) = vm.sign(buyerPrivateKey(), buyDigest); // 买家签名，应该是卖家签名
        
        vm.expectRevert("Invalid whitelist sig");
        nftMarket.buyNFTWithPermitAndWhitelist(tokenId1, deadline, v, r, s, buyV, buyR, buyS);
        
        vm.stopPrank();
    }

    // ========== 手续费管理测试 ==========
    
    function test_WithdrawFees() public {
        // 先进行一些交易产生手续费
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), NFT_PRICE);
        nftMarket.buyNFT(tokenId1);
        vm.stopPrank();
        
        uint256 fees = nftMarket.accumulatedFees();
        assertGt(fees, 0);
        
        // 提现手续费
        uint256 ownerBalanceBefore = paymentToken.balanceOf(owner);
        nftMarket.withdrawFees();
        uint256 ownerBalanceAfter = paymentToken.balanceOf(owner);
        
        assertEq(ownerBalanceAfter - ownerBalanceBefore, fees);
        assertEq(nftMarket.accumulatedFees(), 0);
    }
    
    function test_WithdrawFeesNotOwner() public {
        vm.startPrank(buyer);
        
        vm.expectRevert("Only owner");
        nftMarket.withdrawFees();
        
        vm.stopPrank();
    }
    
    function test_WithdrawFeesNoFees() public {
        vm.expectRevert("No fees");
        nftMarket.withdrawFees();
    }
    
    function test_SetMarketplaceFee() public {
        uint256 newFee = 500; // 5%
        nftMarket.setMarketplaceFee(newFee);
        
        assertEq(nftMarket.marketplaceFee(), newFee);
    }
    
    function test_SetMarketplaceFeeNotOwner() public {
        vm.startPrank(buyer);
        
        vm.expectRevert("Only owner");
        nftMarket.setMarketplaceFee(500);
        
        vm.stopPrank();
    }
    
    function test_SetMarketplaceFeeTooHigh() public {
        vm.expectRevert("Fee>10%");
        nftMarket.setMarketplaceFee(1100); // 11%
    }

    // ========== 查询功能测试 ==========
    
    function test_GetListedTokenIds() public {
        // 上架多个NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftContract.approve(address(nftMarket), tokenId2);
        nftMarket.list(tokenId1, NFT_PRICE);
        nftMarket.list(tokenId2, NFT_PRICE);
        vm.stopPrank();
        
        uint256[] memory listedIds = nftMarket.getListedTokenIds();
        assertEq(listedIds.length, 2);
        assertEq(listedIds[0], tokenId1);
        assertEq(listedIds[1], tokenId2);
    }
    
    function test_GetBatchListings() public {
        // 上架多个NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftContract.approve(address(nftMarket), tokenId2);
        nftMarket.list(tokenId1, NFT_PRICE);
        nftMarket.list(tokenId2, NFT_PRICE * 2);
        vm.stopPrank();
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        
        (address[] memory sellers, uint256[] memory prices, bool[] memory actives, uint256[] memory listedAts) = nftMarket.getBatchListings(tokenIds);
        
        assertEq(sellers[0], seller);
        assertEq(sellers[1], seller);
        assertEq(prices[0], NFT_PRICE);
        assertEq(prices[1], NFT_PRICE * 2);
        assertTrue(actives[0]);
        assertTrue(actives[1]);
    }

    // ========== 事件测试 ==========
    
    function test_ListNFTEvent() public {
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        
        vm.expectEmit(true, true, false, true);
        emit NFTListed(tokenId1, seller, NFT_PRICE, block.timestamp);
        nftMarket.list(tokenId1, NFT_PRICE);
        
        vm.stopPrank();
    }
    
    function test_BuyNFTEvent() public {
        // 上架NFT
        vm.startPrank(seller);
        nftContract.approve(address(nftMarket), tokenId1);
        nftMarket.list(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        // 购买NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), NFT_PRICE);
        
        vm.expectEmit(true, true, true, true);
        emit NFTPurchased(tokenId1, buyer, seller, NFT_PRICE, block.timestamp);
        nftMarket.buyNFT(tokenId1);
        
        vm.stopPrank();
    }

    // ========== 辅助函数 ==========
    
    function buyerPrivateKey() internal pure returns (uint256) {
        return 0x1234567890123456789012345678901234567890123456789012345678901234;
    }
    
    function sellerPrivateKey() internal pure returns (uint256) {
        return 0x2345678901234567890123456789012345678901234567890123456789012345;
    }
} 