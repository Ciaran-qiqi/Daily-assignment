// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SchoolSortedLinkedList
 * @dev 基于可迭代链表实现的按分数排序的学生名单管理
 */
contract SchoolSortedLinkedList {
    struct Student {
        address addr;
        uint256 score;
        address prev;
        address next;
        bool exists;
    }

    // 头结点（分数最高）
    address public head;
    // 尾结点（分数最低）
    address public tail;
    // 学生信息映射
    mapping(address => Student) public students;
    // 学生总数
    uint256 public studentCount;

    /**
     * @dev 添加新学生，按分数插入有序链表
     * @param student 学生地址
     * @param score 初始分数
     */
    function addStudent(address student, uint256 score) external {
        require(!students[student].exists, "Already exists");
        Student memory newStu = Student(student, score, address(0), address(0), true);
        // 空链表直接插入
        if (head == address(0)) {
            head = student;
            tail = student;
            students[student] = newStu;
            studentCount++;
            return;
        }
        // 找到插入位置（分数从高到低）
        address curr = head;
        while (curr != address(0) && students[curr].score >= score) {
            curr = students[curr].next;
        }
        if (curr == head) {
            // 插入到头部
            newStu.next = head;
            students[head].prev = student;
            head = student;
        } else if (curr == address(0)) {
            // 插入到尾部
            newStu.prev = tail;
            students[tail].next = student;
            tail = student;
        } else {
            // 插入到curr前
            address prev = students[curr].prev;
            newStu.prev = prev;
            newStu.next = curr;
            students[prev].next = student;
            students[curr].prev = student;
        }
        students[student] = newStu;
        studentCount++;
    }

    /**
     * @dev 提高学生分数，并自动上移
     * @param student 学生地址
     * @param delta 增加分数
     */
    function increaseScore(address student, uint256 delta) external {
        require(students[student].exists, "Not exists");
        students[student].score += delta;
        _moveUp(student);
    }

    /**
     * @dev 降低学生分数，并自动下移
     * @param student 学生地址
     * @param delta 减少分数
     */
    function decreaseScore(address student, uint256 delta) external {
        require(students[student].exists, "Not exists");
        require(students[student].score >= delta, "Score underflow");
        students[student].score -= delta;
        _moveDown(student);
    }

    /**
     * @dev 删除学生
     * @param student 学生地址
     */
    function removeStudent(address student) external {
        require(students[student].exists, "Not exists");
        address prev = students[student].prev;
        address next = students[student].next;
        if (prev != address(0)) {
            students[prev].next = next;
        } else {
            head = next;
        }
        if (next != address(0)) {
            students[next].prev = prev;
        } else {
            tail = prev;
        }
        delete students[student];
        studentCount--;
    }

    /**
     * @dev 获取前K名学生名单
     * @param k 前K名
     * @return 前K名学生地址数组
     */
    function getTopK(uint256 k) external view returns (address[] memory) {
        uint256 n = k > studentCount ? studentCount : k;
        address[] memory topList = new address[](n);
        address curr = head;
        for (uint256 i = 0; i < n && curr != address(0); i++) {
            topList[i] = curr;
            curr = students[curr].next;
        }
        return topList;
    }

    /**
     * @dev 分页获取学生名单
     * @param start 起始学生地址（第一页用head，下一页用上次返回的nextStart）
     * @param pageSize 每页数量
     * @return studentsPage 当前页学生地址数组
     * @return nextStart 下一页起始地址（为address(0)表示已到末尾）
     */
    function getStudentsPage(address start, uint256 pageSize) external view returns (address[] memory studentsPage, address nextStart) {
        studentsPage = new address[](pageSize);
        address curr = start;
        uint256 count = 0;
        while (curr != address(0) && count < pageSize) {
            studentsPage[count] = curr;
            curr = students[curr].next;
            count++;
        }
        // 如果不足pageSize，截断数组长度
        if (count < pageSize) {
            assembly { mstore(studentsPage, count) }
        }
        nextStart = curr; // 下一页的起始地址
    }

    // 内部函数：分数上升时自动上移
    function _moveUp(address student) internal {
        while (students[student].prev != address(0) && students[students[student].prev].score < students[student].score) {
            _swapWithPrev(student);
        }
    }
    // 内部函数：分数下降时自动下移
    function _moveDown(address student) internal {
        while (students[student].next != address(0) && students[students[student].next].score > students[student].score) {
            _swapWithNext(student);
        }
    }
    // 内部：与前一个节点交换
    function _swapWithPrev(address student) internal {
        address prev = students[student].prev;
        address prevPrev = students[prev].prev;
        address next = students[student].next;
        // 断开原有连接
        if (prevPrev != address(0)) {
            students[prevPrev].next = student;
        } else {
            head = student;
        }
        students[student].prev = prevPrev;
        students[student].next = prev;
        students[prev].prev = student;
        students[prev].next = next;
        if (next != address(0)) {
            students[next].prev = prev;
        } else {
            tail = prev;
        }
    }
    // 内部：与后一个节点交换
    function _swapWithNext(address student) internal {
        address next = students[student].next;
        address nextNext = students[next].next;
        address prev = students[student].prev;
        // 断开原有连接
        if (prev != address(0)) {
            students[prev].next = next;
        } else {
            head = next;
        }
        students[next].prev = prev;
        students[next].next = student;
        students[student].prev = next;
        students[student].next = nextNext;
        if (nextNext != address(0)) {
            students[nextNext].prev = student;
        } else {
            tail = student;
        }
    }
} 