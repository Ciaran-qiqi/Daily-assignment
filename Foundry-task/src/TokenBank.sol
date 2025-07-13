// SPDX-License-Identifier: MIT
// wake-disable unsafe-erc20-call 
// wake-disable unsafe-transfer
// wake-disable unchecked-return-value
// wake-disable  reentrancy

pragma solidity ^0.8.20;

/**
 * @title TokenBank
 * @dev 通用存款合约，支持多种ERC20代币的存款和取款，支持动态调用任何代币合约的函数，无需实现任何接口
 * @dev 支持传统approve+deposit和EIP-2612 permit+deposit两种方式
 */
contract TokenBank {
    // 记录每个用户在每种代币上的存款余额
    // balances[tokenAddress][userAddress] = amount
    mapping(address => mapping(address => uint256)) public balances;
    
    // 事件
    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);

    /**
     * @dev 构造函数
     */
    constructor() {}

    /**
     * @dev 传统存款方式，需要用户先approve
     * @param contractAddress ERC20代币合约地址
     * @param _value 存款数量
     * @return 是否成功
     */
    function deposit(address contractAddress, uint256 _value) public returns (bool) {
        require(_value > 0, "Amount must be greater than 0");
        require(contractAddress != address(0), "Token address zero");
        
        // 动态调用transferFrom
        (bool successTransferFrom,) = contractAddress.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                _value
            )
        );
        require(successTransferFrom, "TransferFrom failed");
        
        // 更新用户余额
        balances[contractAddress][msg.sender] += _value;
        emit Deposit(contractAddress, msg.sender, _value);
        return successTransferFrom;
    }

    /**
     * @dev 通过EIP-2612 Permit签名授权并存款
     * @param contractAddress ERC20代币合约地址
     * @param spender 授权地址（本合约）
     * @param amount 存款数量
     * @param deadline 签名有效截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permitDeposit(
        address contractAddress,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(amount > 0, "Amount must be greater than 0");
        require(contractAddress != address(0), "Token address zero");
        require(spender == address(this), "Spender must be this contract");
        
        // 1. 调用代币合约的permit函数
        (bool successPermit,) = contractAddress.call(
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                msg.sender,
                spender,
                amount,
                deadline,
                v,
                r,
                s
            )
        );
        require(successPermit, "Permit failed");
        
        // 2. 调用deposit函数完成存款
        deposit(contractAddress, amount);
    }

    /**
     * @dev 用户取款，将存款token返还给用户
     * @param contractAddress ERC20代币合约地址
     * @param amount 取款数量
     */
    function withdraw(address contractAddress, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(contractAddress != address(0), "Token address zero");
        require(balances[contractAddress][msg.sender] >= amount, "Insufficient balance");
        
        // 更新用户余额
        balances[contractAddress][msg.sender] -= amount;
        
        // 动态调用transfer
        (bool successTransfer,) = contractAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                amount
            )
        );
        require(successTransfer, "Transfer failed");
        
        emit Withdraw(contractAddress, msg.sender, amount);
    }

    /**
     * @dev 查询用户在指定代币上的存款余额
     * @param contractAddress ERC20代币合约地址
     * @param user 用户地址
     * @return 存款余额
     */
    function getBalance(address contractAddress, address user) external view returns (uint256) {
        return balances[contractAddress][user];
    }

    /**
     * @dev 查询合约中指定代币的总余额
     * @param contractAddress ERC20代币合约地址
     * @return 合约中代币总余额
     */
    function getTotalBalance(address contractAddress) external view returns (uint256) {
        // 动态调用balanceOf
        (bool success, bytes memory data) = contractAddress.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(success, "BalanceOf call failed");
        return abi.decode(data, (uint256));
    }

    /**
     * @dev 批量查询用户在多种代币上的余额
     * @param contractAddresses 代币合约地址数组
     * @param user 用户地址
     * @return 余额数组
     */
    function getBatchBalances(address[] calldata contractAddresses, address user) external view returns (uint256[] memory) {
        uint256 length = contractAddresses.length;
        uint256[] memory userBalances = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            userBalances[i] = balances[contractAddresses[i]][user];
        }
        
        return userBalances;
    }
} 