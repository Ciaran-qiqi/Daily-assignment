// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title BaseERC20
 * @dev 一个基本的 ERC20 代币实现，包含标准 ERC20 接口的所有功能
 * @notice 这是一个教学用途的代币合约，包含铸造、转移、授权等基本功能
 */
contract BaseERC20 is ERC20 {
    
    /**
     * @dev 构造函数
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _decimals 代币小数位数
     * @param _totalSupply 代币总供应量
     * @notice 部署时自动将总供应量铸造给部署者
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {
        // 计算实际的总供应量（考虑小数位数）
        uint256 actualSupply = _totalSupply * 10 ** _decimals;
        
        // 将总供应量铸造给合约部署者
        _mint(msg.sender, actualSupply);
    }
    
    /**
     * @dev 铸造新代币
     * @param to 接收代币的地址
     * @param amount 铸造的代币数量
     * @notice 任何人都可以调用此函数来铸造代币
     */
    function mint(address to, uint256 amount) public {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁代币
     * @param amount 要销毁的代币数量
     * @notice 调用者销毁自己的代币
     */
    function burn(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev 从指定地址销毁代币
     * @param from 要销毁代币的地址
     * @param amount 要销毁的代币数量
     * @notice 需要先授权才能销毁
     */
    function burnFrom(address from, uint256 amount) public {
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount, "Insufficient allowance");
        
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }
    
    /**
     * @dev 获取代币总供应量
     * @return 代币总供应量
     */
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }
    
    /**
     * @dev 获取指定地址的代币余额
     * @param account 要查询的地址
     * @return 该地址的代币余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }
    
    /**
     * @dev 获取授权额度
     * @param owner 代币所有者
     * @param spender 被授权者
     * @return 授权额度
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return super.allowance(owner, spender);
    }
} 