// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BaseERC20合约
 * @dev 一个基本的ERC20代币实现，包含标准ERC20接口的所有功能
 */
contract BaseERC20 {
    // 代币名称
    string public name;
    // 代币符号
    string public symbol;
    // 代币小数位数
    uint8 public decimals;

    // 代币总供应量
    uint256 public totalSupply;

    // 地址对应的代币余额
    mapping(address => uint256) balances;

    // 授权映射：所有者地址 => (被授权地址 => 授权数量)
    mapping(address => mapping(address => uint256)) allowances;

    // 转账事件：当代币被转移时触发
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件：当授权发生变更时触发
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev 构造函数，初始化代币基本信息并将所有代币分配给部署合约的地址
     */
    constructor() {
        /**
         * TODO:
         * 1. 设置 Token 名称（name）："BaseERC20"
              设置 Token 符号（symbol）："BERC20"
              设置 Token 小数位decimals：18
                设置 Token 总量（totalSupply）:100,000,000
         */
        // 设置代币基本信息
        name = "BaseERC20";           // 代币名称
        symbol = "BERC20";            // 代币符号
        decimals = 18;                // 代币小数位数
        totalSupply = 100000000 * 10**uint256(decimals);  // 代币总量：1亿个（含小数位）

        // 将所有代币分配给合约部署者
        balances[msg.sender] = totalSupply;
    }

    /**
     * @dev 查询指定地址的代币余额
     * @param _owner 要查询余额的地址
     * @return balance 该地址的代币余额
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        /**
         * TODO:
         * 1. 允许任何人查看任何地址的 Token 余额
         */
        // 返回指定地址的代币余额
        return balances[_owner];
    }

    /**
     * @dev 转移代币到指定地址
     * @param _to 接收代币的地址
     * @param _value 转移的代币数量
     * @return success 转账是否成功
     */
    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
       /**
        * TODO:
        * 允许 Token 的所有者将他们的 Token 发送给任何人（transfer）；转帐超出余额时抛出异常(require),并显示错误消息 "ERC20: transfer amount exceeds balance"。
        */
        // 检查发送者余额是否足够
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        
        // 安全数学运算：先减少发送者余额
        balances[msg.sender] -= _value;
        // 增加接收者余额
        balances[_to] += _value;

        // 触发转账事件
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev 从授权地址转移代币到指定地址
     * @param _from 代币所有者地址
     * @param _to 接收代币的地址
     * @param _value 转移的代币数量
     * @return success 转账是否成功
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        /**
         * TODO:
         * 允许被授权的地址消费他们被授权的 Token 数量（transferFrom）；
         * 转帐超出余额时抛出异常(require)，异常信息："ERC20: transfer amount exceeds balance"
         * 转帐超出授权数量时抛出异常(require)，异常消息："ERC20: transfer amount exceeds allowance"。
         */
        // 检查发送方余额是否足够
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        // 检查调用者的授权额度是否足够
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        
        // 减少发送方余额
        balances[_from] -= _value;
        // 增加接收方余额
        balances[_to] += _value;
        // 减少调用者的授权额度
        allowances[_from][msg.sender] -= _value;
        
        // 触发转账事件
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev 授权指定地址可以从调用者账户转移的代币数量
     * @param _spender 被授权的地址
     * @param _value 授权的代币数量
     * @return success 授权是否成功
     */
    function approve(
        address _spender,
        uint256 _value
    ) public returns (bool success) {
        /**
         * TODO:
         * 允许任何人授权给任何地址（approve），消费他们被授权的 Token 数量（_value）。
         * 如果授权数量为0，则取消授权。
         */
        // 设置授权金额
        allowances[msg.sender][_spender] = _value;
        
        // 触发授权事件
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev 查询所有者对指定地址的授权数量
     * @param _owner 代币所有者地址
     * @param _spender 被授权的地址
     * @return remaining 剩余的授权数量
     */
    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256 remaining) {
        /**
         * TODO:
         * 允许任何人查看任何地址的授权数量（allowance）。
         */
        // 返回授权数量
        return allowances[_owner][_spender];
    }
}
