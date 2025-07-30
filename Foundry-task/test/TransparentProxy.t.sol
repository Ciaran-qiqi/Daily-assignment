// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TransparentProxy.sol";
import "../src/UpgradeableTokenV1.sol";
import "../src/UpgradeableTokenV2.sol";

contract TransparentProxyTest is Test {
    TransparentProxy public proxy;
    UpgradeableTokenV1 public implementationV1;
    UpgradeableTokenV2 public implementationV2;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public user2 = address(0x3);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Upgraded(address indexed implementation);

    function setUp() public {
        // 部署实现合约
        implementationV1 = new UpgradeableTokenV1();
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            UpgradeableTokenV1.initialize.selector,
            "Test Token",
            "TEST",
            1000000 * 10**18,
            owner
        );

        // 部署代理合约
        proxy = new TransparentProxy(
            address(implementationV1),
            owner,
            initData
        );
    }

    function testInitialization() public {
        UpgradeableTokenV1 token = UpgradeableTokenV1(address(proxy));
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), 1000000 * 10**18);
        assertEq(token.balanceOf(owner), 1000000 * 10**18);
        assertEq(token.owner(), owner);
        assertEq(token.version(), "1.0.0");
    }

    function testTransfer() public {
        UpgradeableTokenV1 token = UpgradeableTokenV1(address(proxy));
        uint256 transferAmount = 1000 * 10**18;
        uint256 initialOwnerBalance = token.balanceOf(owner);
        uint256 initialUserBalance = token.balanceOf(user);
        
        vm.prank(owner);
        token.transfer(user, transferAmount);
        
        assertEq(token.balanceOf(owner), initialOwnerBalance - transferAmount);
        assertEq(token.balanceOf(user), initialUserBalance + transferAmount);
    }

    function testMint() public {
        UpgradeableTokenV1 token = UpgradeableTokenV1(address(proxy));
        uint256 mintAmount = 1000 * 10**18;
        uint256 initialBalance = token.balanceOf(user);
        
        vm.prank(owner);
        token.mint(user, mintAmount);
        
        assertEq(token.balanceOf(user), initialBalance + mintAmount);
        assertEq(token.totalSupply(), 1000000 * 10**18 + mintAmount);
    }

    function testMintOnlyOwner() public {
        UpgradeableTokenV1 token = UpgradeableTokenV1(address(proxy));
        vm.prank(user);
        vm.expectRevert("Token: only owner can mint");
        token.mint(user, 1000 * 10**18);
    }

    function testBurn() public {
        UpgradeableTokenV1 token = UpgradeableTokenV1(address(proxy));
        uint256 burnAmount = 1000 * 10**18;
        uint256 initialBalance = token.balanceOf(owner);
        uint256 initialSupply = token.totalSupply();
        
        vm.prank(owner);
        token.burn(owner, burnAmount);
        
        assertEq(token.balanceOf(owner), initialBalance - burnAmount);
        assertEq(token.totalSupply(), initialSupply - burnAmount);
    }

    function testUpgradeToV2() public {
        // 部署V2实现合约
        implementationV2 = new UpgradeableTokenV2();
        
        // 升级代理合约
        vm.prank(owner);
        proxy.upgradeTo(address(implementationV2));
        
        // 验证升级
        UpgradeableTokenV2 tokenV2 = UpgradeableTokenV2(address(proxy));
        assertEq(tokenV2.version(), "1.0.0"); // 版本号保持不变，因为存储槽没有改变
        assertEq(tokenV2.paused(), false);
        
        // 测试V2的新功能
        vm.prank(owner);
        tokenV2.pause();
        assertEq(tokenV2.paused(), true);
        
        vm.prank(owner);
        tokenV2.unpause();
        assertEq(tokenV2.paused(), false);
    }

    function testUpgradeOnlyAdmin() public {
        implementationV2 = new UpgradeableTokenV2();
        
        vm.prank(user);
        vm.expectRevert("TransparentProxy: only admin can upgrade");
        proxy.upgradeTo(address(implementationV2));
    }

    function testChangeAdmin() public {
        vm.prank(owner);
        proxy.changeAdmin(user);
        
        assertEq(proxy.admin(), user);
    }

    function testChangeAdminOnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert("TransparentProxy: only admin can change admin");
        proxy.changeAdmin(user2);
    }

    function testBatchTransfer() public {
        // 先升级到V2
        implementationV2 = new UpgradeableTokenV2();
        vm.prank(owner);
        proxy.upgradeTo(address(implementationV2));
        
        UpgradeableTokenV2 tokenV2 = UpgradeableTokenV2(address(proxy));
        
        // 给用户一些代币
        vm.prank(owner);
        tokenV2.mint(user, 10000 * 10**18);
        
        // 准备批量转账数据
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = address(0x4);
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000 * 10**18;
        amounts[1] = 2000 * 10**18;
        
        vm.prank(user);
        tokenV2.batchTransfer(recipients, amounts);
        
        assertEq(tokenV2.balanceOf(user2), 1000 * 10**18);
        assertEq(tokenV2.balanceOf(address(0x4)), 2000 * 10**18);
    }

    function testPauseAndUnpause() public {
        // 升级到V2
        implementationV2 = new UpgradeableTokenV2();
        vm.prank(owner);
        proxy.upgradeTo(address(implementationV2));
        
        UpgradeableTokenV2 tokenV2 = UpgradeableTokenV2(address(proxy));
        
        // 暂停合约
        vm.prank(owner);
        tokenV2.pause();
        assertEq(tokenV2.paused(), true);
        
        // 尝试转账应该失败
        vm.prank(owner);
        vm.expectRevert("Token: token is paused");
        tokenV2.transfer(user, 1000 * 10**18);
        
        // 恢复合约
        vm.prank(owner);
        tokenV2.unpause();
        assertEq(tokenV2.paused(), false);
        
        // 转账应该成功
        vm.prank(owner);
        tokenV2.transfer(user, 1000 * 10**18);
        assertEq(tokenV2.balanceOf(user), 1000 * 10**18);
    }

    function testProxyAdminFunctions() public {
        assertEq(proxy.implementation(), address(implementationV1));
        assertEq(proxy.admin(), owner);
    }
} 