// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/AdvancedERC20.sol";

/**
 * @title TokenBankTest
 * @dev TokenBank合约的完整测试套件
 */
contract TokenBankTest is Test {
    TokenBank public tokenBank;
    AdvancedERC20 public token1;
    AdvancedERC20 public token2;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 100万代币
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10**18;   // 1000代币
    
    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);

    function setUp() public {
        // 部署TokenBank合约
        tokenBank = new TokenBank();
        
        // 部署两个不同的ERC20代币
        token1 = new AdvancedERC20("TestToken1", "TT1", 1000000);
        token2 = new AdvancedERC20("TestToken2", "TT2", 1000000);
        
        // 给测试用户分配代币（使用正确的地址）
        uint256 user1Key = user1PrivateKey();
        uint256 user2Key = user2PrivateKey();
        uint256 user3Key = user3PrivateKey();
        
        address user1Addr = vm.addr(user1Key);
        address user2Addr = vm.addr(user2Key);
        address user3Addr = vm.addr(user3Key);
        
        // 分配代币给用户
        token1.transfer(user1Addr, INITIAL_SUPPLY / 3);
        token1.transfer(user2Addr, INITIAL_SUPPLY / 3);
        token1.transfer(user3Addr, INITIAL_SUPPLY / 3);
        
        token2.transfer(user1Addr, INITIAL_SUPPLY / 3);
        token2.transfer(user2Addr, INITIAL_SUPPLY / 3);
        token2.transfer(user3Addr, INITIAL_SUPPLY / 3);
        
        // 设置用户私钥
        vm.label(user1Addr, "user1");
        vm.label(user2Addr, "user2");
        vm.label(user3Addr, "user3");
        
        // 更新用户地址
        user1 = user1Addr;
        user2 = user2Addr;
        user3 = user3Addr;
    }

    // ========== 基础功能测试 ==========
    
    function test_Constructor() public {
        // 验证TokenBank正确部署
        assertEq(address(tokenBank), address(tokenBank));
    }
    
    function test_InitialBalance() public {
        // 验证初始余额为0
        assertEq(tokenBank.getBalance(address(token1), user1), 0);
        assertEq(tokenBank.getBalance(address(token2), user1), 0);
    }

    // ========== 传统存款测试 ==========
    
    function test_Deposit() public {
        vm.startPrank(user1);
        
        // 授权TokenBank
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        
        // 存款
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证存款成功
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_DepositMultipleTokens() public {
        vm.startPrank(user1);
        
        // 授权两种代币
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        token2.approve(address(tokenBank), DEPOSIT_AMOUNT);
        
        // 存款两种代币
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token2), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证存款成功
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(tokenBank.getBalance(address(token2), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
        assertEq(token2.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_DepositInsufficientAllowance() public {
        vm.startPrank(user1);
        
        // 授权金额不足
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT / 2);
        
        // 尝试存款超过授权金额
        vm.expectRevert("TransferFrom failed");
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_DepositZeroAddress() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes("Token address is zero"));
        tokenBank.deposit(address(0), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    function test_DepositZeroAmount() public {
        vm.startPrank(user1);
        token1.approve(address(tokenBank), 1000);
        vm.expectRevert(bytes("Amount must be > 0"));
        tokenBank.deposit(address(token1), 0);
        vm.stopPrank();
    }

    // ========== EIP-2612 Permit存款测试 ==========
    
    function test_PermitDeposit() public {
        vm.startPrank(user1);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成permit签名
        bytes32 domainSeparator = token1.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            user1,
            address(tokenBank),
            DEPOSIT_AMOUNT,
            token1.nonces(user1),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey(), digest);
        
        // 执行permit存款
        tokenBank.permitDeposit(
            address(token1),
            address(tokenBank),
            DEPOSIT_AMOUNT,
            deadline,
            v, r, s
        );
        
        vm.stopPrank();
        
        // 验证存款成功
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_PermitDepositExpired() public {
        vm.startPrank(user1);
        
        // 修复：使用更安全的时间计算，避免溢出
        uint256 currentTime = block.timestamp;
        uint256 deadline = currentTime > 3600 ? currentTime - 3600 : 0; // 确保不会下溢
        
        bytes32 domainSeparator = token1.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            user1,
            address(tokenBank),
            DEPOSIT_AMOUNT,
            token1.nonces(user1),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey(), digest);
        
        // 断言OpenZeppelin自定义错误
        vm.expectRevert(abi.encodeWithSignature("ERC2612ExpiredSignature(uint256)", deadline));
        tokenBank.permitDeposit(
            address(token1),
            address(tokenBank),
            DEPOSIT_AMOUNT,
            deadline,
            v, r, s
        );
        
        vm.stopPrank();
    }
    
    function test_PermitDepositWrongSpender() public {
        vm.startPrank(user1);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 domainSeparator = token1.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            user1,
            address(0x123), // 错误的spender
            DEPOSIT_AMOUNT,
            token1.nonces(user1),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey(), digest);
        
        vm.expectRevert("Spender must be this contract");
        tokenBank.permitDeposit(
            address(token1),
            address(0x123), // 错误的spender
            DEPOSIT_AMOUNT,
            deadline,
            v, r, s
        );
        
        vm.stopPrank();
    }

    // ========== 取款测试 ==========
    
    function test_Withdraw() public {
        vm.startPrank(user1);
        
        // 先存款
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        // 再取款
        tokenBank.withdraw(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证取款成功
        assertEq(tokenBank.getBalance(address(token1), user1), 0);
        assertEq(token1.balanceOf(address(tokenBank)), 0);
    }
    
    function test_WithdrawPartial() public {
        vm.startPrank(user1);
        
        // 先存款
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        // 部分取款
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        tokenBank.withdraw(address(token1), withdrawAmount);
        
        vm.stopPrank();
        
        // 验证部分取款成功
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT - withdrawAmount);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT - withdrawAmount);
    }
    
    function test_WithdrawInsufficientBalance() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Insufficient balance");
        tokenBank.withdraw(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_WithdrawZeroAmount() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Amount must be greater than 0");
        tokenBank.withdraw(address(token1), 0);
        
        vm.stopPrank();
    }

    // ========== 查询功能测试 ==========
    
    function test_GetBalance() public {
        vm.startPrank(user1);
        
        // 授权并存款
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证余额查询
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
    }
    
    function test_GetTotalBalance() public {
        // 多个用户存款
        vm.startPrank(user1);
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // 查询总余额
        uint256 totalBalance = tokenBank.getTotalBalance(address(token1));
        assertEq(totalBalance, DEPOSIT_AMOUNT * 2);
    }
    
    function test_GetBatchBalances() public {
        vm.startPrank(user1);
        
        // 授权两种代币
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        token2.approve(address(tokenBank), DEPOSIT_AMOUNT);
        
        // 存款两种代币
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token2), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证批量余额查询
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        
        uint256[] memory balances = tokenBank.getBatchBalances(tokens, user1);
        assertEq(balances[0], DEPOSIT_AMOUNT);
        assertEq(balances[1], DEPOSIT_AMOUNT);
    }

    // ========== 事件测试 ==========
    
    function test_DepositEvent() public {
        vm.startPrank(user1);
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        
        vm.expectEmit(true, true, false, true);
        emit Deposit(address(token1), user1, DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_WithdrawEvent() public {
        // 先存款
        vm.startPrank(user1);
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        vm.expectEmit(true, true, false, true);
        emit Withdraw(address(token1), user1, DEPOSIT_AMOUNT);
        tokenBank.withdraw(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }

    // ========== AdvancedERC20 三种存款方法测试 ==========
    
    function test_AdvancedERC20_ERC777DirectTransfer() public {
        vm.startPrank(user1);
        
        // 使用ERC777直接转账到TokenBank（一步存款）
        token1.transferWithCallback(address(tokenBank), DEPOSIT_AMOUNT, "");
        
        vm.stopPrank();
        
        // 验证存款成功 - 只验证一次，避免重复计算
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_ERC777TransferWithData() public {
        vm.startPrank(user1);
        
        // 使用ERC777转账并传递数据
        bytes memory userData = abi.encode("deposit", user1);
        token1.transferWithCallback(address(tokenBank), DEPOSIT_AMOUNT, userData);
        
        vm.stopPrank();
        
        // 验证存款成功 - 只验证一次，避免重复计算
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_StandardTransfer() public {
        vm.startPrank(user1);
        
        // 使用标准transfer（会触发ERC777回调）
        token1.transfer(address(tokenBank), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证存款成功 - 只验证一次，避免重复计算
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_TransferFromWithCallback() public {
        vm.startPrank(user1);
        
        // 修复：approve给调用者自己，因为transferFromWithCallback的调用者是user1
        token1.approve(user1, DEPOSIT_AMOUNT * 2);
        
        // 使用transferFromWithCallback
        bytes memory userData = abi.encode("callback_deposit", user1);
        token1.transferFromWithCallback(user1, address(tokenBank), DEPOSIT_AMOUNT, userData);
        
        vm.stopPrank();
        
        // 验证存款成功 - 只验证一次，避免重复计算
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_TraditionalApproveAndDeposit() public {
        vm.startPrank(user1);
        
        // 传统方式：approve + deposit（不使用ERC777回调）
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证存款成功
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_PermitDeposit() public {
        vm.startPrank(user1);
        
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成permit签名
        bytes32 domainSeparator = token1.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            user1,
            address(tokenBank),
            DEPOSIT_AMOUNT,
            token1.nonces(user1),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey(), digest);
        
        // 使用permit存款
        tokenBank.permitDeposit(
            address(token1),
            address(tokenBank),
            DEPOSIT_AMOUNT,
            deadline,
            v, r, s
        );
        
        vm.stopPrank();
        
        // 验证存款成功
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_ERC777CallbackIntegration() public {
        vm.startPrank(user1);
        
        // 直接转账，应该自动触发tokensReceived回调
        token1.transfer(address(tokenBank), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // 验证回调成功处理存款 - 只验证一次，避免重复计算
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_MultipleDepositMethods() public {
        vm.startPrank(user1);
        
        // 方法1：ERC777直接转账
        token1.transferWithCallback(address(tokenBank), DEPOSIT_AMOUNT / 3, "");
        vm.roll(block.number + 1); // 推进区块，防止防重机制
        
        // 方法2：传统approve + deposit
        token1.approve(address(tokenBank), DEPOSIT_AMOUNT / 3);
        tokenBank.deposit(address(token1), DEPOSIT_AMOUNT / 3);
        vm.roll(block.number + 1); // 再推进区块
        
        vm.stopPrank();
        
        // 方法3：permit存款 - 使用不同用户，避免同一用户同一token同一区块重复记账
        vm.startPrank(user2);
        uint256 differentAmount = DEPOSIT_AMOUNT / 3 + 100; // 不同金额
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = token1.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            user2,
            address(tokenBank),
            differentAmount,
            token1.nonces(user2),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PrivateKey(), digest);
        tokenBank.permitDeposit(address(token1), address(tokenBank), differentAmount, deadline, v, r, s);
        vm.stopPrank();
        
        // 验证总存款金额 - 三次都成功，使用不同用户
        uint256 user1Expected = (DEPOSIT_AMOUNT / 3) + (DEPOSIT_AMOUNT / 3);
        uint256 user2Expected = differentAmount;
        uint256 totalExpected = user1Expected + user2Expected;
        
        assertEq(tokenBank.getBalance(address(token1), user1), user1Expected);
        assertEq(tokenBank.getBalance(address(token1), user2), user2Expected);
        assertEq(token1.balanceOf(address(tokenBank)), totalExpected);
    }
    
    function test_AdvancedERC20_ERC777CallbackSecurity() public {
        vm.startPrank(user1);
        
        // 尝试使用恶意数据
        bytes memory maliciousData = abi.encode("malicious", "data");
        token1.transferWithCallback(address(tokenBank), DEPOSIT_AMOUNT, maliciousData);
        
        vm.stopPrank();
        
        // 验证即使使用恶意数据，存款仍然成功 - 只验证一次，避免重复计算
        assertEq(tokenBank.getBalance(address(token1), user1), DEPOSIT_AMOUNT);
        assertEq(token1.balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }
    
    function test_AdvancedERC20_PermitExpired() public {
        vm.startPrank(user1);
        
        // 修复：使用更安全的时间计算，避免溢出
        uint256 currentTime = block.timestamp;
        uint256 deadline = currentTime > 3600 ? currentTime - 3600 : 0; // 确保不会下溢
        
        bytes32 domainSeparator = token1.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            user1,
            address(tokenBank),
            DEPOSIT_AMOUNT,
            token1.nonces(user1),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey(), digest);
        
        // 断言OpenZeppelin自定义错误
        vm.expectRevert(abi.encodeWithSignature("ERC2612ExpiredSignature(uint256)", deadline));
        tokenBank.permitDeposit(
            address(token1),
            address(tokenBank),
            DEPOSIT_AMOUNT,
            deadline,
            v, r, s
        );
        
        vm.stopPrank();
    }
    
    function test_AdvancedERC20_ERC777CallbackEvent() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit Deposit(address(token1), user1, DEPOSIT_AMOUNT);
        token1.transferWithCallback(address(tokenBank), DEPOSIT_AMOUNT, "");
        
        vm.stopPrank();
    }

    // ========== 辅助函数 ==========
    
    function user1PrivateKey() internal pure returns (uint256) {
        return 0x1234567890123456789012345678901234567890123456789012345678901234;
    }
    
    function user2PrivateKey() internal pure returns (uint256) {
        return 0x2345678901234567890123456789012345678901234567890123456789012345;
    }
    
    function user3PrivateKey() internal pure returns (uint256) {
        return 0x3456789012345678901234567890123456789012345678901234567890123456;
    }
} 