// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bank {
    struct Depositor {
        address addr;
        uint amount;
    }
    Depositor[3] public Top3;

    mapping(address => uint256) public balance;


        function deposit() public payable {
           
            balance[msg.sender] += msg.value;
            uint newAmount = balance[msg.sender];
            if (newAmount > Top3[2].amount) {
                _updateTop3(msg.sender, newAmount);
            }

        }

        function _updateTop3(address user, uint newAmount) private {
            for (uint i = 0; i < Top3.length; i++) {
                if (Top3[i].addr == user) {
                    Top3[i].amount = newAmount;
                    _sortTop3();
                    return;
                }
            }
            if (Top3[2].amount < newAmount) {
                Top3[2] = Depositor(user, newAmount);
                _sortTop3();
            }
    
        }

        function _sortTop3() private {
            for (uint i = 0; i < Top3.length - 1; i++) {
                for (uint j = 0; j < Top3.length -1 - i; j++) {
                    if (Top3[j].amount < Top3[j+1].amount) {
                        Depositor memory temp = Top3[j];
                        Top3[j] = Top3[j+1];
                        Top3[j+1] = temp;
                    }
                }
            }
        }

        function getTop3() public view returns (address[3] memory, uint[3] memory) {
            address[3] memory addrs;
            uint[3] memory amounts;
            for (uint i = 0; i < Top3.length; i++) {
                addrs[i] = Top3[i].addr;
                amounts[i] = Top3[i].amount;
            }
            return (addrs, amounts);
        }
    }



/**
 * TODO:
 * 1. 编写一个 BigBank 合约，要求：
 *    • 权限的控制做好
 *    • 不能使用标准库
 *    • 仅允许存款金额 > 0.001 ether（使用 modifier 权限控制）
 *    • 将管理员权限转移给 Ownable 合约，只有 Ownable 可以调用 BigBank 的 withdraw() 提款函数，
 *      所以只有这个合约的管理员可以提款
 */
