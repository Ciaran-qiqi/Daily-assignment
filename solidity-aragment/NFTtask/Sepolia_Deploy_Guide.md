# 🚀 Sepolia测试网完整部署指南

## 📋 任务目标

✅ 发行一个ERC721 Token
✅ 铸造几个NFT，在测试网上发行，在OpenSea上查看
✅ 编写一个市场合约：使用自己发行的ERC20 Token来买卖NFT
✅ NFT持有者可上架NFT（list设置价格）
✅ 编写购买NFT方法buyNFT(uint tokenID, uint amount)

## 🛠️ 准备工作

### 1. 获取Sepolia测试ETH（主流水龙头需要钱包主链eth0.001才能过）

- 访问 [Sepolia Faucet](https://sepoliafaucet.com/)
- 或者 [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
- 获取至少0.1 ETH用于部署和测试

### 2. 配置MetaMask

- 添加Sepolia网络
- 网络名称：Sepolia

## 🎯 部署步骤

### 第一步：部署BaseERC20合约

1. **在Remix中打开BaseERC20.sol**
2. **编译设置**：
   - Compiler版本：0.8.20
   - EVM版本：默认
3. **部署**：
   - 选择"Injected Provider - MetaMask"
   - 确保选择Sepolia网络
   - 点击Deploy（无需参数）
4. **记录地址**：例如 `0x1234567890123456789012345678901234567890`

**验证部署**：

```solidity
// 调用这些函数验证
name() // 应返回 "BaseERC20"
symbol() // 应返回 "BERC20"
totalSupply() // 应返回 100000000000000000000000000
balanceOf(你的地址) // 应返回全部代币
```

### 第二步：部署BaseERC721合约

1. **在Remix中打开BaseERC721.sol**
2. **编译并部署**（无需参数）
3. **记录地址**：例如 `0xabcdefabcdefabcdefabcdefabcdefabcdefabcd`

**验证部署**：

```solidity
// 调用这些函数验证
name() // 应返回 "BaseNFT"
symbol() // 应返回 "BNFT"
owner() // 应返回你的地址
totalSupply() // 应返回 0
```

### 第三步：部署Bank合约

1. **在Remix中打开Bank.sol**
2. **部署参数**：
   - `_tokenAddress`: BaseERC20合约地址
3. **部署并记录地址**

### 第四步：部署NFTMarketplace合约

1. **在Remix中打开NFTMarketplace.sol**
2. **部署参数**：
   - `_paymentToken`: BaseERC20合约地址
   - `_nftContract`: BaseERC721合约地址
3. **部署并记录地址**

## 🎨 铸造NFT

### 准备元数据文件

1. **上传图片到IPFS**：

   - 使用 [Pinata](https://pinata.cloud/) 或 [IPFS Desktop](https://ipfs.io/)
   - 获得图片IPFS链接：`https://ipfs.io/ipfs/QmYourImageHash`
2. **创建元数据JSON**：

```json
{
  "name": "My Awesome NFT #1",
  "description": "这是我在Sepolia测试网上铸造的第一个NFT",
  "image": "https://ipfs.io/ipfs/QmYourImageHash",
  "attributes": [
    {
      "trait_type": "Color",
      "value": "Blue"
    },
    {
      "trait_type": "Rarity",
      "value": "Common"
    }
  ]
}
```

3. **上传元数据到IPFS**：
   - 获得元数据IPFS链接：`https://ipfs.io/ipfs/QmYourMetadataHash`

### 铸造NFT

在Remix中调用BaseERC721合约的mint函数：

```solidity
// 铸造NFT #0
mint("你的地址", "https://ipfs.io/ipfs/QmYourMetadataHash1")

// 铸造NFT #1
mint("你的地址", "https://ipfs.io/ipfs/QmYourMetadataHash2")

// 铸造NFT #2
mint("你的地址", "https://ipfs.io/ipfs/QmYourMetadataHash3")
```

**验证铸造**：

```solidity
totalSupply() // 应该返回 3
ownerOf(0) // 应该返回你的地址
tokenURI(0) // 应该返回元数据URI
```

## 🏪 测试NFT市场

### 1. 上架NFT

**步骤1：授权NFT给市场合约**

```solidity
// 在BaseERC721合约中调用
approve("NFTMarketplace合约地址", 0)
```

**步骤2：上架NFT**

```solidity
// 在NFTMarketplace合约中调用
// 以100个ERC20代币的价格上架NFT #0
list(0, "100000000000000000000") // 100 * 10^18
```

**验证上架**：

```solidity
isListed(0) // 应该返回 true
getListing(0) // 返回上架信息
```

### 2. 购买NFT（使用第二个账户测试）

**步骤1：转移一些ERC20代币给买家**

```solidity
// 在BaseERC20合约中调用（使用部署者账户）
transfer("买家地址", "1000000000000000000000") // 1000个代币
```

**步骤2：买家授权代币给市场**

```solidity
// 切换到买家账户，在BaseERC20合约中调用
approve("NFTMarketplace合约地址", "100000000000000000000")
```

**步骤3：买家购买NFT**

```solidity
// 在NFTMarketplace合约中调用
buyNFT(0, "100000000000000000000") // 购买NFT #0
```

**验证购买**：

```solidity
// 在BaseERC721合约中验证
ownerOf(0) // 应该返回买家地址

// 在NFTMarketplace合约中验证
isListed(0) // 应该返回 false
```

## 🌊 在OpenSea上查看NFT

### 1. 访问OpenSea测试网

- 打开 [OpenSea Testnets](https://testnets.opensea.io/)
- 连接你的MetaMask钱包
- 确保选择Sepolia网络

### 2. 查看你的NFT集合

- 方法1：直接访问 `https://testnets.opensea.io/assets/sepolia/你的BaseERC721合约地址/0`
- 方法2：在OpenSea搜索框输入你的BaseERC721合约地址
- 方法3：查看你的个人资料页面

### 3. 设置集合信息（可选）

- 点击你的NFT集合
- 点击"Edit"设置集合头像、描述等信息
- 添加集合描述和社交媒体链接

## 📊 完整测试流程

### 测试脚本示例

```javascript
// 1. 部署所有合约
const erc20Address = "0x你的ERC20地址";
const erc721Address = "0x你的ERC721地址"; 
const marketplaceAddress = "0x你的市场地址";

// 2. 铸造NFT
await baseERC721.mint(yourAddress, "ipfs://QmHash1");
await baseERC721.mint(yourAddress, "ipfs://QmHash2");
await baseERC721.mint(yourAddress, "ipfs://QmHash3");

// 3. 上架NFT
await baseERC721.approve(marketplaceAddress, 0);
await marketplace.list(0, ethers.utils.parseEther("100"));

// 4. 购买NFT
await baseERC20.approve(marketplaceAddress, ethers.utils.parseEther("100"));
await marketplace.buyNFT(0, ethers.utils.parseEther("100"));
```

## 🔗 重要链接记录表

```
=== Sepolia部署记录 ===
部署时间: ___________
部署者地址: ___________

BaseERC20合约:
地址: ___________
Etherscan: https://sepolia.etherscan.io/address/___________

BaseERC721合约:
地址: ___________
Etherscan: https://sepolia.etherscan.io/address/___________
OpenSea: https://testnets.opensea.io/assets/sepolia/___________

Bank合约:
地址: ___________
Etherscan: https://sepolia.etherscan.io/address/___________

NFTMarketplace合约:
地址: ___________
Etherscan: https://sepolia.etherscan.io/address/___________

NFT元数据IPFS:
NFT #0: https://ipfs.io/ipfs/___________
NFT #1: https://ipfs.io/ipfs/___________
NFT #2: https://ipfs.io/ipfs/___________
```

## 🚨 常见问题解决

### 1. 合约部署失败

- 检查Gas费用是否足够
- 确保Sepolia网络连接正常
- 验证合约编译无误

### 2. NFT在OpenSea上不显示

- 等待1-2分钟让OpenSea索引
- 检查元数据URI是否可访问
- 确保JSON格式正确

### 3. 交易失败

- 检查授权是否正确
- 确认账户余额足够
- 验证合约地址正确

### 4. 元数据显示问题

- 确保IPFS链接可访问
- 检查JSON结构符合OpenSea标准
- 图片链接格式正确

## 🎉 成功标志

完成以下步骤即表示任务成功：

- ✅ ERC20代币成功部署并可转账
- ✅ ERC721合约成功部署并可铸造NFT
- ✅ 成功铸造了多个NFT
- ✅ NFT在OpenSea测试网上可见
- ✅ 市场合约成功部署
- ✅ 可以使用`list`函数上架NFT
- ✅ 可以使用`buyNFT`函数购买NFT
- ✅ ERC20代币作为支付货币正常工作

恭喜您完成了完整的NFT市场生态系统！🎊
