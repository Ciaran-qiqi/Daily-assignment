# 可升级NFT市场合约

这是一个可升级的NFT市场合约系统，支持从V1（普通版本）升级到V2（带离线签名功能）。

## 🚀 快速概览

### 核心特性
- 🔄 **可升级架构**：使用 ERC-1967 标准透明代理
- 🛡️ **双重管理员**：代理管理员 + 业务管理员
- 📝 **离线签名**：V2 支持 EIP-712 签名上架
- 💰 **手续费系统**：自动收取和分配手续费
- 🔒 **安全升级**：存储兼容性保证

### 技术亮点
- **透明代理模式**：符合 ERC-1967 标准
- **存储隔离设计**：代理和实现合约存储分离
- **升级兼容性**：V1→V2 升级时保持所有数据
- **权限分离**：升级权限和业务权限独立管理

### 部署状态
- ✅ **编译通过**：所有合约编译成功
- ✅ **测试通过**：核心功能测试通过
- ✅ **升级验证**：V1→V2 升级机制验证
- 🚀 **准备部署**：可以部署到测试网

## 合约架构

### 核心合约

1. **TP_ERC1967Proxy.sol** - ERC-1967 标准透明代理合约

   - 实现符合 ERC-1967 标准的可升级代理模式
   - 支持管理员升级实现合约
   - 使用标准 ERC-1967 存储槽位，避免存储冲突
2. **TP_NFTMarketV1.sol** - 第一版本实现（透明代理版本）

   - 基本的NFT上架和购买功能
   - 支持价格更新和下架
   - 手续费管理
3. **TP_NFTMarketV2.sol** - 第二版本实现（透明代理版本）

   - 继承V1的所有功能
   - 新增离线签名上架功能
   - 支持EIP-712签名验证

### 辅助合约

4. **BaseERC721.sol** - NFT合约

   - 标准的ERC721实现
   - 支持铸造和转移
5. **BaseERC20.sol** - 支付代币合约

   - 标准的ERC20实现
   - 用作市场支付货币

## 透明代理架构详解

### 代理结构图

```
┌─────────────────────────────────────────────────────────────┐
│                    TP_ERC1967Proxy                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 代理管理员 (ProxyAdmin)                             │   │
│  │ • 控制合约升级                                      │   │
│  │ • 调用 upgradeToAndCall()                          │   │
│  │ • 存储在 ERC-1967 标准槽位                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 实现合约 (Implementation)                          │   │
│  │ • V1: TP_NFTMarketV1                              │   │
│  │ • V2: TP_NFTMarketV2                              │   │
│  │ • 通过 delegatecall 执行                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 业务管理员 (Business Admin)                        │   │
│  │ • 控制业务逻辑                                      │   │
│  │ • 调用 setMarketplaceFee()                         │   │
│  │ • 调用 withdrawFees()                              │   │
│  │ • 存储在实现合约槽位                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 管理员控制机制

#### 1. 代理管理员 (ProxyAdmin)
- **作用**：控制代理合约的升级
- **权限**：调用 `upgradeToAndCall()` 升级实现合约
- **设置**：在代理合约部署时通过构造函数设置
- **存储**：使用 ERC-1967 标准存储槽位

#### 2. 业务管理员 (Business Admin)
- **作用**：控制实现合约的业务逻辑
- **权限**：调用 `setMarketplaceFee()`, `withdrawFees()` 等业务函数
- **设置**：在实现合约的 `initialize()` 函数中设置
- **存储**：使用实现合约的存储槽位

### 存储槽位一致性

#### ERC-1967 标准存储槽位 (代理合约)
```solidity
// 代理合约使用的标准槽位
bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
```

#### 实现合约存储槽位 (V1/V2 兼容)
```solidity
// V1 和 V2 共享的存储槽位
bytes32 private constant PAYMENT_TOKEN_SLOT = bytes32(uint256(2));
bytes32 private constant NFT_CONTRACT_SLOT = bytes32(uint256(3));
bytes32 private constant MARKETPLACE_FEE_SLOT = bytes32(uint256(4));
bytes32 private constant ACCUMULATED_FEES_SLOT = bytes32(uint256(5));
bytes32 private constant VERSION_SLOT = bytes32(uint256(6));
bytes32 private constant DOMAIN_SEPARATOR_SLOT = bytes32(uint256(7));

// V1 业务管理员槽位
bytes32 private constant ADMIN_SLOT = bytes32(uint256(1));

// V2 业务管理员槽位 (与 V1 兼容)
// 使用 assembly { admin := sload(0x1) } 读取相同槽位
```

### 升级时管理员保持

#### 升级流程
```
1. 代理管理员调用 upgradeToAndCall()
2. 代理合约改变实现地址 (V1 → V2)
3. 存储数据保持不变
4. V2 合约读取 V1 设置的业务管理员
```

#### 存储兼容性验证
- ✅ **V1 业务管理员**：存储在槽位 `bytes32(uint256(1))`
- ✅ **V2 业务管理员**：从槽位 `sload(0x1)` 读取
- ✅ **升级后保持**：业务管理员地址在升级后保持不变
- ✅ **权限继承**：V2 继承 V1 的所有业务管理员权限

### 调用流程示例

#### 业务函数调用
```
用户调用 setMarketplaceFee(300)
├── 代理合约 fallback()
├── delegatecall 到实现合约
├── 实现合约检查 _getAdmin() (业务管理员)
├── 如果通过，执行设置
└── 返回结果
```

#### 升级函数调用
```
代理管理员调用 upgradeToAndCall()
├── 代理合约检查 ERC1967Utils.getAdmin() (代理管理员)
├── 如果通过，执行升级
├── 改变实现地址
└── 保持所有存储数据
```

## 功能特性

### V1版本功能

- ✅ **NFT上架**：用户可以上架自己的NFT
- ✅ **NFT购买**：买家可以购买上架的NFT
- ✅ **价格管理**：卖家可以更新和下架NFT
- ✅ **手续费系统**：自动收取和分配手续费
- ✅ **批量查询**：支持批量获取上架信息

### V2版本新增功能

- 🔐 **离线签名上架**：支持使用EIP-712签名上架NFT
- 🛡️ **防重放保护**：使用nonce防止签名重放攻击
- ⏰ **过期时间**：签名支持过期时间设置
- 🔄 **向后兼容**：完全兼容V1的所有功能

## 部署信息

### 测试网部署地址

**代理合约地址：**
`0xb958F6e2434e98599ee5D4973f2300A5141748eb`
[Sepolia 区块链浏览器查看](https://sepolia.etherscan.io/address/0xb958F6e2434e98599ee5D4973f2300A5141748eb)

**实现合约地址：**
TP_NFTMarketV1:
`0x6968e67057a320DC8D9E3FCAEA05cc27dcbD86C6`
[Sepolia 区块链浏览器查看](https://sepolia.etherscan.io/address/0x6968e67057a320DC8D9E3FCAEA05cc27dcbD86C6)

TP_NFTMarketV2:
`0xe9F9081a549845b11C89DB0BDEdC4d73Acf9712E`
[Sepolia 区块链浏览器查看](https://sepolia.etherscan.io/address/0xe9F9081a549845b11C89DB0BDEdC4d73Acf9712E)

**辅助合约地址：**
BaseERC721:
`0x655d4Ed79a9B85Cf524bC765Fdac216629D0708E`
[Sepolia 区块链浏览器查看](https://sepolia.etherscan.io/address/0x655d4Ed79a9B85Cf524bC765Fdac216629D0708E)

BaseERC20:
`0xc2b92B5E9d840d66F4c38FfE3c1d0272441eFD70`
[Sepolia 区块链浏览器查看](https://sepolia.etherscan.io/address/0xc2b92B5E9d840d66F4c38FfE3c1d0272441eFD70)

## 使用方法

### 部署合约

```bash
# 设置环境变量
export PRIVATE_KEY="你的私钥"

# 部署NFT市场合约
forge script script/DeployTPNFTMarket.sol --rpc-url <你的RPC> --broadcast
```

### 升级到V2

```bash
# 设置代理合约地址
export PROXY_ADDRESS="代理合约地址"

# 升级到V2
forge script script/UpgradeTPNFTMarket.sol --rpc-url <你的RPC> --broadcast
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-contract TP_NFTMarketTest -vv

# 运行详细测试
forge test --match-contract TP_NFTMarketTest -vvvv
```

### 测试覆盖范围

#### 基础功能测试
- ✅ **初始化测试**：验证合约正确初始化
- ✅ **NFT上架测试**：验证上架功能正常
- ✅ **NFT购买测试**：验证购买功能正常
- ✅ **价格更新测试**：验证价格更新功能
- ✅ **下架测试**：验证下架功能正常
- ✅ **手续费测试**：验证手续费收取和提取

#### 升级功能测试
- ✅ **升级到V2**：验证代理升级机制
- ✅ **V2功能测试**：验证V2新增功能
- ✅ **离线签名测试**：验证EIP-712签名功能
- ✅ **管理员权限测试**：验证权限控制机制

#### 存储兼容性测试
- ✅ **V1存储测试**：验证V1存储布局
- ✅ **V2存储测试**：验证V2存储布局
- ✅ **升级兼容性**：验证V1→V2升级兼容性

## 离线签名上架流程

### 1. 用户授权

```javascript
// 用户需要先授权市场合约操作NFT
await nftContract.setApprovalForAll(marketAddress, true);
```

### 2. 创建签名

```javascript
// 签名数据结构
const domain = {
    name: 'NFTMarketV2',
    version: '1',
    chainId: chainId,
    verifyingContract: marketAddress
};

const types = {
    ListNFT: [
        { name: 'tokenId', type: 'uint256' },
        { name: 'price', type: 'uint256' },
        { name: 'nonce', type: 'uint256' }
    ]
};

const value = {
    tokenId: tokenId,
    price: price,
    nonce: nonce
};

// 创建签名
const signature = await signer._signTypedData(domain, types, value);
```

### 3. 调用合约

```javascript
// 解析签名
const { v, r, s } = ethers.utils.splitSignature(signature);

// 调用合约
await marketContract.listWithSignature(
    tokenId,
    price,
    deadline,
    v,
    r,
    s
);
```

## 技术架构

### 代理模式设计

#### 透明代理 vs UUPS
- **透明代理 (Transparent Proxy)**：升级逻辑在代理合约中
- **UUPS (Universal Upgradeable Proxy Standard)**：升级逻辑在实现合约中
- **本项目**：使用透明代理模式，符合 ERC-1967 标准

#### 存储隔离设计
```
代理合约存储 (ERC-1967 标准)
├── 实现地址 (implementation)
└── 代理管理员 (proxyAdmin)

实现合约存储 (业务数据)
├── 业务管理员 (businessAdmin)
├── 支付代币地址 (paymentToken)
├── NFT合约地址 (nftContract)
├── 市场手续费率 (marketplaceFee)
├── 累计手续费 (accumulatedFees)
├── 版本号 (version)
└── 域名分隔符 (domainSeparator) - V2新增
```

### 升级兼容性保证

#### 存储布局兼容性
- ✅ **V1 → V2 升级**：所有存储槽位保持一致
- ✅ **业务管理员保持**：升级后管理员权限不变
- ✅ **数据完整性**：所有业务数据在升级后保持完整

#### 函数接口兼容性
- ✅ **V1 函数**：在 V2 中完全保留
- ✅ **V2 新增**：`listWithSignature()` 等新功能
- ✅ **事件兼容**：所有事件定义保持一致

### 安全特性

- 🔒 **代理模式**：使用透明代理确保升级安全
- 🛡️ **权限控制**：只有管理员可以升级合约
- 🔐 **签名验证**：使用EIP-712标准进行签名验证
- ⚡ **防重放**：使用nonce防止签名重放攻击
- 💰 **手续费保护**：安全的手续费收取和分配机制
- 🛡️ **重入保护**：使用 Checks-Effects-Interactions 模式

## 技术栈

- **Solidity**: ^0.8.19
- Solc：0.8.22
- **Foundry**: 测试和部署框架
- **OpenZeppelin**: 标准合约库
- **EIP-712**: 结构化数据签名标准

## 许可证

MIT License
