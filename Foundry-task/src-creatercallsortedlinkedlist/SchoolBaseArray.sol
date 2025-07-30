// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SchoolBaseArray
 * @dev 使用纯数组实现学生管理，支持添加、删除、查询和获取所有学生名单
 */
contract SchoolBaseArray {
    // 存储所有学生地址
    address[] private studentList;

    /**
     * @dev 添加学生地址
     * @param student 学生地址
     */
    function addStudent(address student) external {
        require(!isSchoolStudent(student), "Already exists"); // 检查学生是否已存在
        studentList.push(student);
    }

    /**
     * @dev 删除学生地址
     * @param student 学生地址
     */
    function removeStudent(address student) external {
        uint256 len = studentList.length;
        for (uint256 i = 0; i < len; i++) {
            if (studentList[i] == student) {
                // 将要删除的地址与最后一个交换并pop
                studentList[i] = studentList[len - 1];
                studentList.pop();
                return;
            }
        }
        revert("Not exists"); // 学生不存在
    }

    /**
     * @dev 查询某地址是否为学生
     * @param student 学生地址
     * @return 是否为学生
     */
    function isSchoolStudent(address student) public view returns (bool) {
        uint256 len = studentList.length;
        for (uint256 i = 0; i < len; i++) {
            if (studentList[i] == student) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev 获取所有学生名单
     * @return 学生地址数组
     */
    function getAllStudents() external view returns (address[] memory) {
        return studentList;
    }
} 