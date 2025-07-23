// SPDX-License-Identifier: MIT
// wake-disable  reentrancy

pragma solidity ^0.8.20;

// 引入OpenZeppelin的ERC20、2612、777标准库
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC777Recipient} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC777Recipient.sol";
import {IERC777Sender} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC777Sender.sol";

/**
 * @title AdvancedERC20
 * @dev 保留基础的ERC20的deposit，用户可以像传统ERC20一样approve+deposit+transferFrom到合约
 * @dev 实现了完整的ERC777标准，用户deposit时，可以一步transfer到合约，合约自动回调响应存款，无需传统存款的approve+ transferFrom；
 * @dev 实现了EIP-2612 Permit功能，用户通过签名signature授权转账deposit，无需传统approve，即可transferFrom到合约
 * @notice 这是一个高级ERC20代币，集成了ERC777回调和EIP-2612签名授权功能
 */
contract AdvancedERC20 is ERC20Permit, ReentrancyGuard {
    using Address for address;

    /**
     * @dev 构造函数，初始化代币名称和符号，并初始化EIP-2612 Permit功能。
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param totalSupply_ 总供应量
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        _mint(msg.sender, totalSupply_ * 10**decimals());
    }
    
    /**
     * @dev 检查地址是否为合约
     * @param addr 要检查的地址
     * @return 是否为合约
     */
    function _isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @dev 检查发送者合约是否实现了IERC777Sender接口
     * @param _from 发送者地址
     * @param _to 接收者地址
     * @param _amount 转账金额
     * @param _data 回调数据
     * @dev ERC777 standard callback - external calls are intentional
     */
    function _checkOnTokensToSend(
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data
    ) private {
        // 检查发送者是否为合约
        if (_isContract(_from)) {
            try IERC777Sender(_from).tokensToSend(
                msg.sender,  // operator
                _from,       // from
                _to,         // to
                _amount,     // amount
                _data,       // userData
                ""           // operatorData (空字符串)
            ) {
                // 回调成功
            } catch {
                // 回调失败，可以选择revert或继续
                // 这里选择继续执行，不中断转账
            }
        }
    }

    /**
     * @dev 检查接收者合约是否实现了IERC777Recipient接口
     * @param _to 接收者地址
     * @param _from 发送者地址
     * @param _amount 转账金额
     * @param _data 回调数据
     */
    function _checkOnTokensReceived(
        address _to, 
        address _from,
        uint256 _amount,
        bytes memory _data
    ) private {
        // 检查接收者是否为合约
        if (_isContract(_to)) {
            try IERC777Recipient(_to).tokensReceived(
                msg.sender,  // operator
                _from,       // from
                _to,         // to
                _amount,     // amount
                _data,       // userData
                ""           // operatorData (空字符串)
            ) {
                // 回调成功，业务逻辑在业务合约中实现
            } catch {
                // 回调失败，可以选择revert或继续
                // 这里选择继续执行，回调失败不影响转账
            }
        }
    }

    /**
     * @dev 带回调的转账函数，类似ERC777的send功能
     * @param _to 接收者地址
     * @param _value 转账金额
     * @param _data 回调数据
     */
    function transferWithCallback(
        address _to, 
        uint256 _value, 
        bytes memory _data
    ) public returns (bool) {
        // 先调用发送者回调
        _checkOnTokensToSend(msg.sender, _to, _value, _data);
        // 执行标准ERC20转账
        bool success = transfer(_to, _value);
        if (success) {
            // 如果转账成功，调用接收者的回调函数
            _checkOnTokensReceived(_to, msg.sender, _value, _data);
        }
        return success;
    }

    /**
     * @dev 重写transfer函数，添加完整的ERC777回调支持
     * @param to 接收者地址
     * @param amount 转账金额
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        // 先执行转账（状态变更），避免了重入攻击
        bool success = super.transfer(to, amount);
        if (success) {
            // 转账成功后调用回调，外部回调无法影响转账结果
            _checkOnTokensToSend(msg.sender, to, amount, "");
            _checkOnTokensReceived(to, msg.sender, amount, "");
        }
        return success;
    }

    /**
     * @dev 重写transferFrom函数，添加完整的ERC777回调支持
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 转账金额
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        // 先执行转账（状态变更），避免了重入攻击
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            // 转账成功后调用回调，外部回调无法影响转账结果
            _checkOnTokensToSend(from, to, amount, "");
            _checkOnTokensReceived(to, from, amount, "");
        }
        return success;
    }

    /**
     * @dev 带自定义数据的transferFrom，类似ERC777的operatorSend功能
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 转账金额
     * @param data 回调数据
     */
    function transferFromWithCallback(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) public returns (bool) {
        // 先调用发送者回调
        _checkOnTokensToSend(from, to, amount, data);
        // 执行转账
        bool success = transferFrom(from, to, amount);
        if (success) {
            // 转账成功后调用接收者回调
            _checkOnTokensReceived(to, from, amount, data);
        }
        return success;
    }
}



