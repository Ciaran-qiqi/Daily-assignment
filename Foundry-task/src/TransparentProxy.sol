// SPDX-License-Identifier: MIT
// wake-disable unsafe-delegatecall


pragma solidity ^0.8.19;

/**
 * @title TransparentProxy
 * @dev 透明代理合约，自己实现代理逻辑
 * 使用存储槽来存储实现地址和管理员地址
 */
contract TransparentProxy {
    // 存储槽布局
    // 槽0: 实现地址 (address)
    // 槽1: 管理员地址 (address)
    
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(0));
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(1));
    
    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    
    /**
     * @dev 构造函数
     * @param _implementation 初始实现地址
     * @param _admin 管理员地址
     * @param _data 初始化数据
     */
    constructor(address _implementation, address _admin, bytes memory _data) {
        _setImplementation(_implementation);
        _setAdmin(_admin);
        
        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(_data);
            require(success, "TransparentProxy: initialization failed");
        }
    }
    
    /**
     * @dev 回退函数，将所有调用委托给实现合约
     */
    fallback() external payable {
        address implementation = _getImplementation();
        require(implementation != address(0), "TransparentProxy: implementation not set");
        
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
     * @dev 接收函数
     */
    receive() external payable {}
    
    /**
     * @dev 升级实现合约
     * @param newImplementation 新的实现地址
     */
    function upgradeTo(address newImplementation) external {
        require(msg.sender == _getAdmin(), "TransparentProxy: only admin can upgrade");
        require(newImplementation != address(0), "TransparentProxy: invalid implementation");
        
        address oldImplementation = _getImplementation();
        _setImplementation(newImplementation);
        
        emit Upgraded(newImplementation);
    }
    
    /**
     * @dev 更改管理员
     * @param newAdmin 新的管理员地址
     */
    function changeAdmin(address newAdmin) external {
        require(msg.sender == _getAdmin(), "TransparentProxy: only admin can change admin");
        require(newAdmin != address(0), "TransparentProxy: invalid admin");
        
        address oldAdmin = _getAdmin();
        _setAdmin(newAdmin);
        
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @dev 获取当前实现地址
     */
    function implementation() external view returns (address) {
        return _getImplementation();
    }
    
    /**
     * @dev 获取管理员地址
     */
    function admin() external view returns (address) {
        return _getAdmin();
    }
    
    /**
     * @dev 内部函数：获取实现地址
     */
    function _getImplementation() internal view returns (address) {
        address impl;
        assembly {
            impl := sload(0x0)
        }
        return impl;
    }
    
    /**
     * @dev 内部函数：设置实现地址
     */
    function _setImplementation(address newImplementation) internal {
        assembly {
            sstore(0x0, newImplementation)
        }
    }
    
    /**
     * @dev 内部函数：获取管理员地址
     */
    function _getAdmin() internal view returns (address) {
        address adminAddr;
        assembly {
            adminAddr := sload(0x1)
        }
        return adminAddr;
    }
    
    /**
     * @dev 内部函数：设置管理员地址
     */
    function _setAdmin(address newAdmin) internal {
        assembly {
            sstore(0x1, newAdmin)
        }
    }
} 