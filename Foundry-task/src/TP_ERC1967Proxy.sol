// SPDX-License-Identifier: MIT
// wake-disable unsafe-delegatecall

pragma solidity ^0.8.19;

import {IERC1967} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol";
import {ERC1967Utils} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

/**
 * @title TP_ERC1967Proxy
 * @dev 符合 ERC-1967 标准的透明代理合约，专门用于 NFT 市场系统
 * 使用标准的 ERC-1967 存储槽位，避免存储冲突
 */
contract TP_ERC1967Proxy {
    /**
     * @dev 代理调用被拒绝
     */
    error ProxyDeniedAdminAccess();

    /**
     * @dev 升级事件
     */
    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /**
     * @dev 构造函数
     * @param _implementation 初始实现地址
     * @param _admin 管理员地址
     * @param _data 初始化数据
     */
    constructor(address _implementation, address _admin, bytes memory _data) {
        ERC1967Utils.upgradeToAndCall(_implementation, _data);
        ERC1967Utils.changeAdmin(_admin);
    }

    /**
     * @dev 回退函数，将所有调用委托给实现合约
     * 如果调用者是管理员，则处理升级逻辑
     */
    fallback() external payable {
        address admin = ERC1967Utils.getAdmin();
        
        if (msg.sender == admin) {
            // 管理员调用，处理升级逻辑
            if (msg.sig == this.upgradeToAndCall.selector) {
                _dispatchUpgradeToAndCall();
            } else {
                revert ProxyDeniedAdminAccess();
            }
        } else {
            // 普通用户调用，转发到实现合约
            _fallback();
        }
    }

    /**
     * @dev 接收函数
     */
    receive() external payable {}

    /**
     * @dev 升级实现合约并调用初始化函数
     * @param newImplementation 新的实现地址
     * @param data 初始化数据
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable {
        address admin = ERC1967Utils.getAdmin();
        require(msg.sender == admin, "TP_ERC1967Proxy: only admin can upgrade");
        
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }

    /**
     * @dev 更改管理员
     * @param newAdmin 新的管理员地址
     */
    function changeAdmin(address newAdmin) external {
        address admin = ERC1967Utils.getAdmin();
        require(msg.sender == admin, "TP_ERC1967Proxy: only admin can change admin");
        
        address oldAdmin = admin;
        ERC1967Utils.changeAdmin(newAdmin);
        
        emit AdminChanged(oldAdmin, newAdmin);
    }

    /**
     * @dev 获取当前实现地址
     * @return 当前实现地址
     */
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @dev 获取当前管理员地址
     * @return 当前管理员地址
     */
    function admin() external view returns (address) {
        return ERC1967Utils.getAdmin();
    }

    /**
     * @dev 内部回退函数，转发调用到实现合约
     */
    function _fallback() internal {
        address implementation = ERC1967Utils.getImplementation();
        require(implementation != address(0), "TP_ERC1967Proxy: implementation not set");
        
        (bool success, bytes memory returndata) = implementation.delegatecall(msg.data);
        
        if (success) {
            assembly {
                return(add(returndata, 0x20), mload(returndata))
            }
        } else {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(returndata, 0x20), returndata_size)
            }
        }
    }

    /**
     * @dev 分发升级调用
     */
    function _dispatchUpgradeToAndCall() internal {
        (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
        address admin = ERC1967Utils.getAdmin();
        require(msg.sender == admin, "TP_ERC1967Proxy: only admin can upgrade");
        
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }
} 