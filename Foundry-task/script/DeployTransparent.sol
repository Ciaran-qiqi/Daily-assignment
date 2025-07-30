// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TransparentProxy.sol";
import "../src/UpgradeableTokenV1.sol";


contract DeployTransparentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署实现合约
        UpgradeableTokenV1 implementation = new UpgradeableTokenV1();
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            UpgradeableTokenV1.initialize.selector,
            "Transparent Token",  // 名称
            "TKN",                // 符号
            1000000 * 10**18,    // 初始供应量 (1,000,000 tokens)
            deployer              // 初始所有者
        );

        // 部署透明代理合约
        TransparentProxy proxy = new TransparentProxy(
            address(implementation),
            deployer,  // 管理员
            initData
        );

        vm.stopBroadcast();

        console.log("Implementation address:", address(implementation));
        console.log("Proxy address:", address(proxy));
        console.log("Deployer address:", deployer);
        
        // 验证部署
        UpgradeableTokenV1 token = UpgradeableTokenV1(address(proxy));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        console.log("Deployer balance:", token.balanceOf(deployer));
        console.log("Token version:", token.version());
    }
} 