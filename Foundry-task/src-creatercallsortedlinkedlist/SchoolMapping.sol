// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SchoolMapping
 * @dev 使用mapping实现学生管理，支持添加、删除、查询和获取所有学生名单
 */
contract SchoolMapping {
    // mapping存储学生是否存在
    mapping(address => bool) public isStudent;
    // 辅助数组存储所有学生地址
    address[] private studentList;
    // 地址到数组下标的映射，便于O(1)删除
    mapping(address => uint256) private studentIndex;

    /**
     * @dev 添加学生地址
     * @param student 学生地址
     */
    function addStudent(address student) external {
        require(!isStudent[student], "Already exists"); // 检查学生是否已存在
        isStudent[student] = true;
        studentIndex[student] = studentList.length;
        studentList.push(student);
    }

    /**
     * @dev 删除学生地址
     * @param student 学生地址
     */
    function removeStudent(address student) external {
        require(isStudent[student], "Not exists"); // 检查学生是否存在
        // O(1)删除：将要删除的地址与最后一个交换并pop
        uint256 idx = studentIndex[student];
        uint256 lastIdx = studentList.length - 1;
        if (idx != lastIdx) {
            address lastStudent = studentList[lastIdx];
            studentList[idx] = lastStudent;
            studentIndex[lastStudent] = idx;
        }
        studentList.pop();
        delete isStudent[student];
        delete studentIndex[student];
    }

    /**
     * @dev 查询某地址是否为学生
     * @param student 学生地址
     * @return 是否为学生
     */
    function isSchoolStudent(address student) external view returns (bool) {
        return isStudent[student];
    }

    /**
     * @dev 获取所有学生名单
     * @return 学生地址数组
     */
    function getAllStudents() external view returns (address[] memory) {
        return studentList;
    }
} 