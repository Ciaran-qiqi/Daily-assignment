// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TP_ERC1967Proxy.sol";
import "../src/TP_NFTMarketV1.sol";
import "../src/BaseERC721.sol";
import "../src/BaseERC20.sol";

contract DeployTPNFTMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署NFT合约
        BaseERC721 nftContract = new BaseERC721();
        console.log("NFT Contract deployed at:", address(nftContract));
        
        // 部署支付代币合约
        BaseERC20 paymentToken = new BaseERC20("Market Token", "MTK", 18, 1000000);
        console.log("Payment Token deployed at:", address(paymentToken));
        
        // 部署V1实现合约
        TP_NFTMarketV1 implementationV1 = new TP_NFTMarketV1();
        console.log("TP-NFTMarketV1 Implementation deployed at:", address(implementationV1));
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            TP_NFTMarketV1.initialize.selector,
            address(paymentToken),  // 支付代币地址
            address(nftContract)    // NFT合约地址
        );

        // 部署 ERC-1967 透明代理合约
        TP_ERC1967Proxy proxy = new TP_ERC1967Proxy(
            address(implementationV1),
            deployer,  // 管理员
            initData
        );

        vm.stopBroadcast();

        console.log("NFTMarket Proxy deployed at:", address(proxy));
        console.log("Deployer address:", deployer);
        
        // 验证部署
        TP_NFTMarketV1 market = TP_NFTMarketV1(address(proxy));
        console.log("Market version:", market.version());
        console.log("Payment token:", market.paymentToken());
        console.log("NFT contract:", market.nftContract());
        console.log("Marketplace fee:", market.marketplaceFee());
        
        // 给部署者一些代币用于测试
        vm.startBroadcast(deployerPrivateKey);
        paymentToken.transfer(deployer, 10000 * 10**18);
        console.log("Transferred 10,000 tokens to deployer");
        vm.stopBroadcast();
    }
} 