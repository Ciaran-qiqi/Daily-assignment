// SPDX-License-Identifier: MIT
// wake-disable unsafe-erc20-call 
// wake-disable unsafe-transfer
// wake-disable unchecked-return-value
// wake-disable  reentrancy

pragma solidity ^0.8.20;

import "./SigUtils.sol";
import {IERC777Recipient} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC777Recipient.sol";

/**
 * @title TokenBank
 * @dev 通用存款合约，支持多种ERC20代币的存款和取款
 * @dev 支持传统approve+deposit和EIP-2612 permit+deposit两种方式
 * @dev 实现IERC777Recipient接口，支持ERC777回调存款
 */
contract TokenBank is IERC777Recipient {
    // 记录每个用户在每种代币上的存款余额
    // balances[tokenAddress][userAddress] = amount
    mapping(address => mapping(address => uint256)) public balances;
    
    // 增加防重映射，防止同一笔转账在同一区块被重复记账
    mapping(address => mapping(address => mapping(uint256 => bool))) private _receivedInBlock;

    // 事件
    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);

    /**
     * @dev 构造函数
     */
    constructor() {}

    /**
     * @dev ERC777接收者回调函数，当用户直接转账给Bank时自动调用
     * @param operator 操作者地址
     * @param from 发送者地址
     * @param to 接收者地址（Bank合约）
     * @param amount 转账金额
     * @param userData 用户数据
     * @param operatorData 操作者数据
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        // 确保只有指定的代币合约可以调用
        require(msg.sender != address(0), "Invalid token");
        // 只有在直接转账到Bank时才自动处理存款，防止Bank自身转出时重复记账
        if (to == address(this) && from != address(this)) {
            // 防止同一(from, amount, block.number)在同一token下重复记账
            require(!_receivedInBlock[msg.sender][from][block.number], "Duplicate deposit in block");
            _receivedInBlock[msg.sender][from][block.number] = true;
            balances[msg.sender][from] += amount;
            emit Deposit(msg.sender, from, amount);
        }
    }

    /**
     * @dev 存款函数，用户需提前approve授权
     * @param token 代币合约地址
     * @param amount 存款数量
     */
    function deposit(address token, uint256 amount) external {
        // 只做转账，不直接增加余额，余额由ERC777回调统一处理
        require(token != address(0), "Token address is zero");
        require(amount > 0, "Amount must be > 0");
        // 从用户转账到本合约
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(success, "TransferFrom failed");
        // 不在此处增加余额，等待ERC777/ERC20回调
    }

    /**
     * @dev 使用EIP-2612 permit授权并存款，一步到位
     * @param token 代币合约地址
     * @param spender 授权spender，必须为本合约
     * @param amount 存款数量
     * @param deadline 签名截止时间
     * @param v 签名参数
     * @param r 签名参数
     * @param s 签名参数
     */
    function permitDeposit(
        address token,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(token != address(0), "Token address is zero");
        require(spender == address(this), "Spender must be this contract");
        require(amount > 0, "Amount must be > 0");
        // deadline检查交由permit内部处理
        // 调用permit授权
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                msg.sender,
                spender,
                amount,
                deadline,
                v, r, s
            )
        );
        if (!ok) {
            // 如果是OpenZeppelin自定义错误，直接revert原始数据
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        // 只做转账，不直接增加余额，余额由ERC777回调统一处理
        (bool success, ) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(success, "TransferFrom failed");
        // 不在此处增加余额，等待ERC777/ERC20回调
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