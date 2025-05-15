// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Ownable 合约，用于管理管理员权限
contract Ownable {
    address private _owner; // 合约管理员地址

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner); // 管理员变更事件

    constructor() {
        _owner = msg.sender; // 部署合约的地址为初始管理员
        emit OwnershipTransferred(address(0), _owner);
    }

    // 仅允许管理员调用的修饰符
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    // 获取当前管理员地址
    function owner() public view returns (address) {
        return _owner;
    }

    // 转移管理员权限
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// BigBank 合约，继承 Ownable
contract BigBank is Ownable {
    // 存款人结构体，包含地址和存款金额
    struct Depositor {
        address addr;
        uint amount;
    }
    Depositor[3] public Top3; // 存储存款金额最大的前三名用户

    mapping(address => uint256) public balance; // 每个地址的存款余额

    // 限制存款金额必须大于 0.001 ether 的修饰符
    modifier onlyAboveThreshold() {
        require(msg.value > 0.001 ether, "Deposit must be greater than 0.001 ether");
        _;
    }

    // 存款函数，只有存款金额大于 0.001 ether 时才能调用
    function deposit() public payable onlyAboveThreshold {
        balance[msg.sender] += msg.value; // 更新用户余额
        uint newAmount = balance[msg.sender];
        if (newAmount > Top3[2].amount) { // 如果存款金额大于当前第三名
            _updateTop3(msg.sender, newAmount); // 更新 Top3
        }
    }

    // 更新 Top3 的私有函数
    function _updateTop3(address user, uint newAmount) private {
        for (uint i = 0; i < Top3.length; i++) {
            if (Top3[i].addr == user) { // 如果用户已经在 Top3 中
                Top3[i].amount = newAmount; // 更新存款金额
                _sortTop3(); // 重新排序
                return;
            }
        }
        if (Top3[2].amount < newAmount) { // 如果用户不在 Top3 中且存款金额大于第三名
            Top3[2] = Depositor(user, newAmount); // 替换第三名
            _sortTop3(); // 重新排序
        }
    }

    // 冒泡排序函数，用于对 Top3 按存款金额从大到小排序
    function _sortTop3() private {
        for (uint i = 0; i < Top3.length - 1; i++) {
            for (uint j = 0; j < Top3.length - 1 - i; j++) {
                if (Top3[j].amount < Top3[j + 1].amount) { // 如果前一个存款金额小于后一个
                    Depositor memory temp = Top3[j];
                    Top3[j] = Top3[j + 1];
                    Top3[j + 1] = temp; // 交换位置
                }
            }
        }
    }

    // 获取当前 Top3 的地址和存款金额
    function getTop3() public view returns (address[3] memory, uint[3] memory) {
        address[3] memory addrs;
        uint[3] memory amounts;
        for (uint i = 0; i < Top3.length; i++) {
            addrs[i] = Top3[i].addr;
            amounts[i] = Top3[i].amount;
        }
        return (addrs, amounts);
    }

    // 提款函数，仅管理员可以调用
    function withdraw(uint amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance"); // 检查合约余额是否足够
        payable(msg.sender).transfer(amount); // 转账给管理员
    }
}