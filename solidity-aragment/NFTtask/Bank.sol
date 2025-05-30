// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeERC20库
 * @dev 安全的ERC20调用库，处理不规范的ERC20实现
 */
library SafeERC20 {
    using Address for address;
    
    function safeTransfer(BaseERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(BaseERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(BaseERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @title Address库
 * @dev 地址相关的实用函数
 */
library Address {
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @title BaseERC20接口
 * @dev 定义与BaseERC20代币交互所需的基本函数，与您的BaseERC20.sol合约完全匹配
 */
interface BaseERC20 {
    // 查询账户余额函数（参数名匹配BaseERC20.sol）
    function balanceOf(address _owner) external view returns (uint256 balance);
    // 转账函数（参数名匹配BaseERC20.sol）
    function transfer(address _to, uint256 _value) external returns (bool success);
    // 从授权账户转账函数（参数名匹配BaseERC20.sol）
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    // 授权函数
    function approve(address _spender, uint256 _value) external returns (bool success);
    // 查询授权额度函数
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    // 基础信息函数
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
}

/**
 * @title 银行合约
 * @dev 允许用户存取ERC20代币的银行系统
 * @notice 此合约实现了一个基本的代币银行功能，包括存款、取款和管理员提款
 * @author 智能合约开发者
 */
contract Bank {
    using SafeERC20 for BaseERC20;
    
    // 代币合约地址，存储BaseERC20接口的实例，用于与代币合约交互
    BaseERC20 public token;
    
    // 合约拥有者/管理员地址，在部署时设置为合约部署者
    address public owner;
    
    // 记录每个用户存款金额的映射，key为用户地址，value为存款金额
    mapping(address => uint256) public userDeposits;
    
    // 银行总存款量，记录所有用户存款的总和
    uint256 public totalDeposits;
    
    // 管理员手续费累计（新增）
    uint256 public accumulatedFees;
    
    // 手续费率（基点，100 = 1%）（新增）
    uint256 public depositFee = 25; // 0.25%
    uint256 public withdrawFee = 25; // 0.25%
    
    // 事件定义，用于记录重要操作并方便前端应用跟踪
    // 存款事件：记录用户地址和存款金额
    event Deposit(address indexed user, uint256 amount, uint256 fee);
    // 取款事件：记录用户地址和取款金额
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    // 管理员提款事件：记录管理员地址和提款金额（修改为手续费提取）
    event FeeWithdrawn(address indexed admin, uint256 amount);
    // 手续费率更新事件（新增）
    event FeeRateUpdated(uint256 newDepositFee, uint256 newWithdrawFee);
    
    /**
     * @dev 修饰器：只有合约拥有者才能调用
     * @notice 用于限制某些函数只能由管理员调用，提供安全控制
     */
    modifier onlyOwner() {
        // 检查调用者是否为合约拥有者
        require(msg.sender == owner, "Only owner can call this function");
        // 执行函数主体
        _;
    }
    
    /**
     * @dev 构造函数，设置代币地址和合约拥有者
     * @param _tokenAddress 要使用的ERC20代币合约地址
     * @notice 部署合约时需要提供一个有效的ERC20代币合约地址
     */
    constructor(address _tokenAddress) {
        // 确保提供的代币地址不是零地址
        require(_tokenAddress != address(0), "Token address cannot be zero");
        // 将代币地址赋值给token变量
        token = BaseERC20(_tokenAddress);
        // 设置合约部署者为拥有者
        owner = msg.sender;
    }
    
    /**
     * @dev 用户存款函数
     * @param _amount 存款金额
     * @notice 用户调用此函数将代币存入银行，收取小量手续费
     * @notice 用户必须先调用代币合约的approve函数授权银行合约转移代币
     */
    function deposit(uint256 _amount) external {
        // 检查存款金额是否大于0
        require(_amount > 0, "Deposit amount must be greater than 0");
        
        // 检查用户是否有足够的代币余额
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // 计算手续费和实际存款金额
        uint256 fee = (_amount * depositFee) / 10000;
        uint256 depositAmount = _amount - fee;
        
        // 将代币从用户转移到银行合约
        // 注意：用户需要事先调用token的approve函数，授权银行合约转移代币
        // 这里使用safeTransferFrom函数，确保安全转账
        token.safeTransferFrom(msg.sender, address(this), _amount);
        
        // 更新用户存款记录（不包含手续费）
        userDeposits[msg.sender] += depositAmount;
        // 更新总存款量（不包含手续费）
        totalDeposits += depositAmount;
        
        // 累计手续费
        accumulatedFees += fee;
        
        // 触发存款事件，记录此次操作
        emit Deposit(msg.sender, depositAmount, fee);
    }
    
    /**
     * @dev 用户取款函数
     * @param _amount 取款金额
     * @notice 用户调用此函数从银行取出自己存入的代币，收取小量手续费
     */
    function withdraw(uint256 _amount) external {
        // 检查取款金额是否大于0
        require(_amount > 0, "Withdraw amount must be greater than 0");
        // 检查用户存款余额是否足够
        require(userDeposits[msg.sender] >= _amount, "Insufficient deposit balance");
        
        // 计算手续费和实际取款金额
        uint256 fee = (_amount * withdrawFee) / 10000;
        uint256 withdrawAmount = _amount - fee;
        
        // 更新用户存款记录，减去取款金额
        userDeposits[msg.sender] -= _amount;
        // 更新总存款量，减去取款金额
        totalDeposits -= _amount;
        
        // 累计手续费
        accumulatedFees += fee;
        
        // 将代币从银行合约转移到用户（扣除手续费）
        // 这里使用safeTransfer函数，确保安全转账
        token.safeTransfer(msg.sender, withdrawAmount);
        
        // 触发取款事件，记录此次操作
        emit Withdraw(msg.sender, withdrawAmount, fee);
    }
    
    /**
     * @dev 管理员提取累计的手续费（安全替换原adminWithdrawAll）
     * @notice 只有合约拥有者才能调用此函数
     * @notice 此函数只能提取手续费，不能动用户本金
     */
    function withdrawFees() external onlyOwner {
        require(accumulatedFees > 0, "No fees to withdraw");
        
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        
        // 将手续费转移给管理员
        token.safeTransfer(owner, fees);
        
        // 触发手续费提取事件
        emit FeeWithdrawn(owner, fees);
    }
    
    /**
     * @dev 更新手续费率（有合理限制）
     * @param _depositFee 新的存款手续费率（基点，100 = 1%）
     * @param _withdrawFee 新的取款手续费率（基点，100 = 1%）
     * @notice 只有合约拥有者才能调用，且手续费率有上限保护
     */
    function updateFeeRates(uint256 _depositFee, uint256 _withdrawFee) external onlyOwner {
        require(_depositFee <= 200, "Deposit fee too high"); // 最大2%
        require(_withdrawFee <= 200, "Withdraw fee too high"); // 最大2%
        
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
        
        emit FeeRateUpdated(_depositFee, _withdrawFee);
    }
    
    /**
     * @dev 查询用户的存款余额
     * @param _user 用户地址
     * @return 用户的存款余额
     * @notice 任何人都可以查询任何用户的存款余额
     */
    function getBalance(address _user) external view returns (uint256) {
        // 返回指定用户的存款余额
        return userDeposits[_user];
    }
    
    /**
     * @dev 查询银行合约中的代币余额
     * @return 银行合约中的代币余额
     * @notice 返回银行合约中实际持有的代币数量
     * @notice 此值应该等于totalDeposits + accumulatedFees
     */
    function getBankBalance() external view returns (uint256) {
        // 返回合约中的代币余额
        return token.balanceOf(address(this));
    }
    
    /**
     * @dev 查询累计的手续费
     * @return 可提取的手续费金额
     * @notice 管理员可以通过此函数查看可提取的手续费
     */
    function getAccumulatedFees() external view returns (uint256) {
        return accumulatedFees;
    }
    
    /**
     * @dev 查询当前手续费率
     * @return depositFeeRate 存款手续费率（基点）
     * @return withdrawFeeRate 取款手续费率（基点）
     */
    function getFeeRates() external view returns (uint256 depositFeeRate, uint256 withdrawFeeRate) {
        return (depositFee, withdrawFee);
    }
} 