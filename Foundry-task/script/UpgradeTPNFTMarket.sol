// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/TP_ERC1967Proxy.sol";
import "../src/TP_NFTMarketV2.sol";

contract UpgradeTPNFTMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 从环境变量获取代理合约地址和新业务管理员地址
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address newBusinessAdmin = vm.envAddress("NEW_BUSINESS_ADMIN");

        vm.startBroadcast(deployerPrivateKey);

        // 部署新的实现合约
        TP_NFTMarketV2 newImplementation = new TP_NFTMarketV2();

        // ABI 编码 changeBusinessAdmin(address)
        bytes memory data = abi.encodeWithSelector(
            TP_NFTMarketV2.changeBusinessAdmin.selector,
            newBusinessAdmin
        );

        // 升级代理合约并切换业务管理员
        TP_ERC1967Proxy proxy = TP_ERC1967Proxy(payable(proxyAddress));
        proxy.upgradeToAndCall(address(newImplementation), data);

        vm.stopBroadcast();

        console.log("New implementation address:", address(newImplementation));
        console.log("Proxy address:", proxyAddress);
        console.log("Upgrade completed successfully!");
        console.log("Business admin changed to:", newBusinessAdmin);

        // 验证升级
        TP_NFTMarketV2 market = TP_NFTMarketV2(proxyAddress);
        console.log("Market version after upgrade:", market.version());
        console.log("Domain separator:", uint256(market.DOMAIN_SEPARATOR()));
    }
} 