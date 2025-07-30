// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TP_NFTMarketV1.sol";
import "../src/BaseERC721.sol";
import "../src/BaseERC20.sol";

contract SimpleTest is Test {
    TP_NFTMarketV1 public market;
    BaseERC721 public nftContract;
    BaseERC20 public paymentToken;
    
    address public owner = address(0x1);
    address public seller = address(0x2);
    
    function setUp() public {
        // 直接部署 V1 合约（不使用代理）
        nftContract = new BaseERC721();
        paymentToken = new BaseERC20("Market Token", "MTK", 18, 1000000);
        market = new TP_NFTMarketV1();
        
        // 初始化
        market.initialize(address(paymentToken), address(nftContract));
        
        // 给测试用户一些代币和NFT
        paymentToken.transfer(seller, 1000 * 10**18);
        nftContract.mint(seller, 1);
    }

    function testSimpleList() public {
        vm.startPrank(seller);
        nftContract.approve(address(market), 1);
        
        // 测试直接调用（不使用代理）
        market.list(1, 100 * 10**18);
        
        (address listingSeller, uint256 price, uint256 timestamp, bool active) = market.getListing(1);
        assertEq(listingSeller, seller);
        assertEq(price, 100 * 10**18);
        assertTrue(active);
        vm.stopPrank();
    }

    function testSimpleStorage() public {
        // 测试简单的存储操作
        vm.prank(owner);
        
        // 只测试一个简单的映射存储
        market.setMarketplaceFee(300);
        assertEq(market.marketplaceFee(), 300);
    }
} 