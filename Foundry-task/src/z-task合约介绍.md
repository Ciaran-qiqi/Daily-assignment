# Foundry Task - 智能合约文档

## 项目概述

本项目实现了一个完整的DeFi生态系统，包含代币银行、NFT市场和高级ERC20代币。所有合约都支持EIP-712签名和EIP-2612 Permit功能，实现了现代化的Web3交互体验。

## 合约架构

```
src/
├── TokenBank.sol          # 代币银行合约
├── NFTMarket.sol          # NFT市场合约  
├── AdvancedERC20.sol      # 高级ERC20代币
├── BaseERC721.sol         # 基础ERC721 NFT
├── SigUtils.sol           # 签名工具库
├── utils/                 # 工具目录
├── library/               # 库目录
└── interface/             # 接口目录
```

## 核心合约详解

### 1. TokenBank.sol - 代币银行合约

**功能概述：**
- 支持多种ERC20代币的存款和取款
- 实现ERC777回调机制，自动处理存款
- 支持EIP-2612 Permit授权，无需提前approve
- 防重机制确保同一用户同一token同一区块只记账一次

**主要特性：**
- ✅ **多种存款方式**：传统approve+deposit、permit+deposit、ERC777直接转账
- ✅ **ERC777集成**：自动回调处理，支持高级代币功能
- ✅ **防重保护**：防止同一区块重复记账
- ✅ **批量查询**：支持批量查询用户余额
- ✅ **事件记录**：完整的存款和取款事件

**核心函数：**
```solidity
// 传统存款
function deposit(address token, uint256 amount) external

// Permit存款（EIP-2612）
function permitDeposit(address token, address spender, uint256 amount, 
                      uint256 deadline, uint8 v, bytes32 r, bytes32 s) external

// 取款
function withdraw(address contractAddress, uint256 amount) external

// 查询余额
function getBalance(address contractAddress, address user) external view returns (uint256)
```

**安全机制：**
- 防重映射：`mapping(address => mapping(address => mapping(uint256 => bool))) private _receivedInBlock`
- ERC777回调验证：确保只有指定代币合约可调用
- 余额检查：取款前验证用户余额

---

### 2. NFTMarket.sol - NFT市场合约

**功能概述：**
- 完整的NFT交易市场
- 支持EIP-2612 Permit购买，无需提前approve
- 支持EIP-712白名单签名购买
- 自动手续费收取和分配

**主要特性：**
- ✅ **多种购买方式**：传统approve+buy、permit+buy、permit+whitelist
- ✅ **白名单机制**：支持离线白名单签名验证
- ✅ **手续费管理**：自动收取和提现手续费
- ✅ **价格管理**：支持NFT价格更新
- ✅ **批量操作**：批量查询和上架

**核心函数：**
```solidity
// 上架NFT
function list(uint256 tokenId, uint256 price) external

// 传统购买
function buyNFT(uint256 tokenId) external

// Permit购买（EIP-2612）
function buyNFTWithPermit(uint256 tokenId, uint256 deadline, 
                         uint8 v, bytes32 r, bytes32 s) external

// Permit+白名单购买
function buyNFTWithPermitAndWhitelist(uint256 tokenId, uint256 deadline,
                                    uint8 v, bytes32 r, bytes32 s,
                                    uint8 buyV, bytes32 buyR, bytes32 buyS) external

// 手续费提现
function withdrawFees() external
```

**安全机制：**
- 所有权验证：确保只有NFT所有者可以上架
- 授权检查：验证NFT已授权给市场合约
- 签名验证：EIP-712签名验证防止重放攻击
- 余额检查：购买前验证买家余额

---

### 3. AdvancedERC20.sol - 高级ERC20代币

**功能概述：**
- 基于OpenZeppelin的ERC20实现
- 支持EIP-2612 Permit功能
- 支持ERC777回调机制
- 包含完整的EIP-712签名支持

**主要特性：**
- ✅ **EIP-2612 Permit**：支持离线授权，无需gas费
- ✅ **ERC777集成**：支持高级代币转账回调
- ✅ **EIP-712签名**：完整的结构化数据签名
- ✅ **标准ERC20**：完全兼容ERC20标准

**核心函数：**
```solidity
// Permit授权（EIP-2612）
function permit(address owner, address spender, uint256 value,
               uint256 deadline, uint8 v, bytes32 r, bytes32 s) external

// ERC777转账
function transferWithCallback(address to, uint256 amount, bytes calldata data) external

// 标准ERC20转账
function transfer(address to, uint256 amount) external override returns (bool)
```

**安全机制：**
- 签名过期检查：确保permit签名未过期
- 重放保护：使用nonce防止签名重放
- 回调验证：ERC777回调安全处理

---

### 4. BaseERC721.sol - 基础ERC721 NFT

**功能概述：**
- 基于OpenZeppelin的ERC721实现
- 提供基本的NFT铸造功能
- 完全兼容ERC721标准

**主要特性：**
- ✅ **标准ERC721**：完全兼容ERC721接口
- ✅ **铸造功能**：支持NFT铸造
- ✅ **所有权管理**：完整的NFT所有权转移

**核心函数：**
```solidity
// 铸造NFT
function mint(address to, uint256 tokenId) public
```

---

### 5. SigUtils.sol - 签名工具库

**功能概述：**
- EIP-712签名工具库
- 提供结构体hash计算和签名验证
- 适用于各种签名场景

**主要特性：**
- ✅ **EIP-712支持**：完整的结构化数据签名
- ✅ **签名恢复**：从签名中恢复签名者地址
- ✅ **通用工具**：可复用于多个合约

**核心函数：**
```solidity
// 计算结构体hash
function structHash(bytes32 typeHash, bytes memory encodedData) internal pure returns (bytes32)

// 恢复签名者地址
function recoverSigner(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address)
```

## 技术栈

### 标准支持
- **EIP-20**: ERC20代币标准
- **EIP-721**: NFT标准
- **EIP-777**: 高级代币标准
- **EIP-2612**: Permit授权标准
- **EIP-712**: 结构化数据签名标准

### 开发框架
- **Foundry**: 智能合约开发框架
- **OpenZeppelin**: 安全合约库
- **Solidity 0.8.20**: 最新稳定版本

## 测试覆盖

### TokenBank测试 (30个测试)
- ✅ 基础功能测试
- ✅ ERC777回调测试
- ✅ Permit授权测试
- ✅ 防重机制测试
- ✅ 边界条件测试

### NFTMarket测试 (31个测试)
- ✅ 上架/下架测试
- ✅ 购买功能测试
- ✅ Permit购买测试
- ✅ 白名单购买测试
- ✅ 手续费管理测试

## 部署说明

### 环境要求
- Foundry 0.2.0+
- Solidity 0.8.20+
- Node.js 16+

### 部署步骤
```bash
# 安装依赖
forge install

# 编译合约
forge build

# 运行测试
forge test

# 部署合约（需要配置网络）
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## 安全特性

### 防重放攻击
- 使用nonce机制防止签名重放
- 时间戳验证防止过期签名

### 权限控制
- 所有权验证确保操作权限
- 授权检查防止未授权操作

### 余额安全
- 转账前余额检查
- 防重机制防止重复记账

### 签名安全
- EIP-712结构化数据签名
- 完整的签名验证流程

## 使用示例

### TokenBank使用
```solidity
// 传统存款
token.approve(address(tokenBank), amount);
tokenBank.deposit(address(token), amount);

// Permit存款
tokenBank.permitDeposit(address(token), address(tokenBank), amount, deadline, v, r, s);

// 查询余额
uint256 balance = tokenBank.getBalance(address(token), user);
```

### NFTMarket使用
```solidity
// 上架NFT
nft.approve(address(nftMarket), tokenId);
nftMarket.list(tokenId, price);

// 传统购买
paymentToken.approve(address(nftMarket), price);
nftMarket.buyNFT(tokenId);

// Permit购买
nftMarket.buyNFTWithPermit(tokenId, deadline, v, r, s);
```

## 许可证

MIT License - 详见LICENSE文件

## 贡献

欢迎提交Issue和Pull Request来改进项目。

## 联系方式

如有问题或建议，请通过GitHub Issues联系。
