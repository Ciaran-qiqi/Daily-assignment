// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TransparentProxy.sol";
import "../src/UpgradeableTokenV2.sol";

contract UpgradeTransparentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 从环境变量获取代理合约地址
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署新的实现合约
        UpgradeableTokenV2 newImplementation = new UpgradeableTokenV2();
        
        // 升级代理合约
        TransparentProxy proxy = TransparentProxy(payable(proxyAddress));
        proxy.upgradeTo(address(newImplementation));

        vm.stopBroadcast();

        console.log("New implementation address:", address(newImplementation));
        console.log("Proxy address:", proxyAddress);
        console.log("Upgrade completed successfully!");
        
        // 验证升级
        UpgradeableTokenV2 token = UpgradeableTokenV2(proxyAddress);
        console.log("Token version after upgrade:", token.version());
        console.log("Token paused status:", token.paused());
    }
} 