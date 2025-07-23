# AirdopMerkleNFTMarket 任务说明文档

## 一、功能目标概述
本合约实现了如下功能的组合：
- **Multicall（delegateCall）**：允许用户一次性原子调用多个合约方法，提升交互效率。
- **Merkle Tree 白名单**：通过默克尔树实现链上高效白名单校验，节省gas。
- **ERC20 Permit 授权**：用户通过签名离线授权，无需提前approve，节省gas。
- **优惠价格（100 Token）白名单购买**：白名单用户可用100 Token优惠价购买NFT。
- **Multicall调用流程**：用户可一次性完成permit授权和NFT领取。

---

## 二、核心方法说明
### 1. permitPrePay
- 功能：用户通过EIP-2612 permit签名，授权本合约支配其100 Token，无需提前approve。
- 优势：省gas，提升用户体验。

### 2. claimNFT
- 功能：
  - 校验用户是否在白名单（MerkleProof验证）。
  - 校验未重复领取。
  - 使用permitPrePay授权的额度，transferFrom用户100 Token到合约。
  - 将NFT安全转账给用户。
- 安全性：每个用户只能领取一次，且只有白名单用户可领取。

### 3. multicall
- 功能：允许用户一次性调用permitPrePay和claimNFT，提升交互原子性和效率。
- 实现：通过delegateCall循环调用，保证所有操作要么全部成功要么全部回滚。

---

## 三、白名单实现方式对比
### 1. 可迭代链表/映射（mapping(address => bool) public whitelist;）
- 优点：实现简单，链上直接查验，适合名单较小场景。
- 缺点：名单大时部署和存储成本高，不适合大规模空投。

### 2. 后台离线签名（EIP-712/自定义签名）
- 优点：省gas，灵活，名单可动态调整。
- 缺点：有一定中心化，需要用户从后端获取签名，依赖后端安全。

### 3. 默克尔树（Merkle Tree）
- 优点：链上校验高效，名单大时极大节省gas，安全性高。
- 缺点：用户需自行保存proof，前端需配合生成proof。
- 本合约采用此方式，适合大规模白名单场景。

---

## 四、关键调用流程
1. **用户通过前端生成permit签名**，调用`permitPrePay`，链上完成授权。
2. **用户通过前端生成Merkle Proof**，调用`claimNFT`，链上校验白名单并完成支付+发NFT。
3. **推荐用法：用户通过multicall一次性调用permitPrePay和claimNFT**，提升体验和原子性。

### 代码调用示例
```solidity
// 用户先离线签名permit
market.permitPrePay(user, address(market), 100e18, deadline, v, r, s);
// 用户提交Merkle Proof领取NFT
market.claimNFT(user, tokenId, proof);
// 推荐：一次性multicall
market.multicall([
    abi.encodeWithSelector(market.permitPrePay.selector, user, address(market), 100e18, deadline, v, r, s),
    abi.encodeWithSelector(market.claimNFT.selector, user, tokenId, proof)
]);
```

---

## 五、流程安全性与gas优化说明
- **permit授权**：用户无需提前approve，省一次链上交易。
- **Merkle Tree**：大名单场景下极大节省链上存储和校验gas。
- **Multicall**：提升交互原子性，防止部分操作失败导致用户资产损失。

---

## 六、总结
本合约通过组合使用Multicall、Merkle Tree、ERC20 Permit等现代DeFi常用技术，实现了高效、安全、低gas的白名单优惠NFT购买流程。适合大规模空投、白名单销售等场景。

如需进一步扩展或集成其他白名单方案，可参考本合约结构灵活调整。 