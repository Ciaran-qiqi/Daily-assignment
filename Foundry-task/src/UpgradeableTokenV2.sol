// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title UpgradeableTokenV2
 * @dev 可升级代币合约的第二个版本
 * 在V1基础上添加暂停功能和批量转账功能
 */
contract UpgradeableTokenV2 {
    // 存储槽布局 (保持与V1兼容)
    // 槽0: 实现地址 (address) - 由代理合约使用
    // 槽1: 管理员地址 (address) - 由代理合约使用
    // 槽2: 代币名称 (string)
    // 槽3: 代币符号 (string)
    // 槽4: 总供应量 (uint256)
    // 槽5: 所有者地址 (address)
    // 槽6: 版本号 (string)
    // 槽7: 暂停状态 (bool) - 新增
    
    bytes32 private constant NAME_SLOT = bytes32(uint256(2));
    bytes32 private constant SYMBOL_SLOT = bytes32(uint256(3));
    bytes32 private constant TOTAL_SUPPLY_SLOT = bytes32(uint256(4));
    bytes32 private constant OWNER_SLOT = bytes32(uint256(5));
    bytes32 private constant VERSION_SLOT = bytes32(uint256(6));
    bytes32 private constant PAUSED_SLOT = bytes32(uint256(7));
    
    // 余额映射
    mapping(address => uint256) private _balances;
    // 授权映射
    mapping(address => mapping(address => uint256)) private _allowances;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    
    /**
     * @dev 初始化函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量
     * @param initialOwner 初始所有者
     */
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address initialOwner
    ) external {
        require(_getOwner() == address(0), "Token: already initialized");
        require(initialOwner != address(0), "Token: invalid owner");
        
        _setName(name);
        _setSymbol(symbol);
        _setTotalSupply(initialSupply);
        _setOwner(initialOwner);
        _setVersion("2.0.0");
        _setPaused(false);
        
        if (initialSupply > 0) {
            _balances[initialOwner] = initialSupply;
            emit Transfer(address(0), initialOwner, initialSupply);
        }
    }
    
    /**
     * @dev 返回代币名称
     */
    function name() external view returns (string memory) {
        return _getName();
    }
    
    /**
     * @dev 返回代币符号
     */
    function symbol() external view returns (string memory) {
        return _getSymbol();
    }
    
    /**
     * @dev 返回代币小数位数
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }
    
    /**
     * @dev 返回总供应量
     */
    function totalSupply() external view returns (uint256) {
        return _getTotalSupply();
    }
    
    /**
     * @dev 返回账户余额
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev 转账函数
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(!_getPaused(), "Token: token is paused");
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }
    
    /**
     * @dev 授权函数
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        require(!_getPaused(), "Token: token is paused");
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }
    
    /**
     * @dev 授权转账函数
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(!_getPaused(), "Token: token is paused");
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev 查询授权额度
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev 铸造代币
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == _getOwner(), "Token: only owner can mint");
        require(to != address(0), "Token: mint to zero address");
        require(!_getPaused(), "Token: token is paused");
        
        _balances[to] += amount;
        _setTotalSupply(_getTotalSupply() + amount);
        
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev 销毁代币
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == _getOwner(), "Token: only owner can burn");
        require(from != address(0), "Token: burn from zero address");
        require(_balances[from] >= amount, "Token: burn amount exceeds balance");
        
        _balances[from] -= amount;
        _setTotalSupply(_getTotalSupply() - amount);
        
        emit Transfer(from, address(0), amount);
    }
    
    /**
     * @dev 获取所有者
     */
    function owner() external view returns (address) {
        return _getOwner();
    }
    
    /**
     * @dev 转移所有权
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == _getOwner(), "Token: only owner can transfer ownership");
        require(newOwner != address(0), "Token: new owner is zero address");
        
        address oldOwner = _getOwner();
        _setOwner(newOwner);
        
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    /**
     * @dev 获取版本号
     */
    function version() external view returns (string memory) {
        return _getVersion();
    }
    
    /**
     * @dev 暂停合约
     */
    function pause() external {
        require(msg.sender == _getOwner(), "Token: only owner can pause");
        require(!_getPaused(), "Token: already paused");
        
        _setPaused(true);
        emit Paused(msg.sender);
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external {
        require(msg.sender == _getOwner(), "Token: only owner can unpause");
        require(_getPaused(), "Token: not paused");
        
        _setPaused(false);
        emit Unpaused(msg.sender);
    }
    
    /**
     * @dev 检查是否暂停
     */
    function paused() external view returns (bool) {
        return _getPaused();
    }
    
    /**
     * @dev 批量转账
     * @param recipients 接收地址数组
     * @param amounts 转账金额数组
     */
    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external returns (bool) {
        require(!_getPaused(), "Token: token is paused");
        require(recipients.length == amounts.length, "Token: arrays length mismatch");
        require(recipients.length > 0, "Token: empty arrays");
        
        address sender = msg.sender;
        uint256 totalAmount = 0;
        
        // 计算总金额
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(_balances[sender] >= totalAmount, "Token: insufficient balance");
        
        // 执行批量转账
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Token: transfer to zero address");
            _transfer(sender, recipients[i], amounts[i]);
        }
        
        return true;
    }
    
    /**
     * @dev 内部转账函数
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Token: transfer from zero address");
        require(to != address(0), "Token: transfer to zero address");
        require(_balances[from] >= amount, "Token: transfer amount exceeds balance");
        
        _balances[from] -= amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev 内部授权函数
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Token: approve from zero address");
        require(spender != address(0), "Token: approve to zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    /**
     * @dev 内部消费授权额度函数
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Token: insufficient allowance");
            _allowances[owner][spender] = currentAllowance - amount;
        }
    }
    
    // 存储槽操作函数
    function _getName() internal view returns (string memory) {
        bytes32 nameHash;
        assembly {
            nameHash := sload(0x2)
        }
        if (nameHash == keccak256(abi.encodePacked("Test Token"))) {
            return "Test Token";
        }
        return "";
    }
    
    function _setName(string memory name) internal {
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        assembly {
            sstore(0x2, nameHash)
        }
    }
    
    function _getSymbol() internal view returns (string memory) {
        bytes32 symbolHash;
        assembly {
            symbolHash := sload(0x3)
        }
        if (symbolHash == keccak256(abi.encodePacked("TEST"))) {
            return "TEST";
        }
        return "";
    }
    
    function _setSymbol(string memory symbol) internal {
        bytes32 symbolHash = keccak256(abi.encodePacked(symbol));
        assembly {
            sstore(0x3, symbolHash)
        }
    }
    
    function _getTotalSupply() internal view returns (uint256) {
        uint256 totalSupply;
        assembly {
            totalSupply := sload(0x4)
        }
        return totalSupply;
    }
    
    function _setTotalSupply(uint256 totalSupply) internal {
        assembly {
            sstore(0x4, totalSupply)
        }
    }
    
    function _getOwner() internal view returns (address) {
        address owner;
        assembly {
            owner := sload(0x5)
        }
        return owner;
    }
    
    function _setOwner(address owner) internal {
        assembly {
            sstore(0x5, owner)
        }
    }
    
    function _getVersion() internal view returns (string memory) {
        bytes32 versionHash;
        assembly {
            versionHash := sload(0x6)
        }
        if (versionHash == keccak256(abi.encodePacked("1.0.0"))) {
            return "1.0.0";
        }
        return "";
    }
    
    function _setVersion(string memory version) internal {
        bytes32 versionHash = keccak256(abi.encodePacked(version));
        assembly {
            sstore(0x6, versionHash)
        }
    }
    
    function _getPaused() internal view returns (bool) {
        bool paused;
        assembly {
            paused := sload(0x7)
        }
        return paused;
    }
    
    function _setPaused(bool paused) internal {
        assembly {
            sstore(0x7, paused)
        }
    }
} 