# Solidity合约创建方式与InscriptionFactory设计说明

## 一、Solidity合约创建的常见方式

### 1. 直接new关键字
- 语法：`C c = new C(...);`
- 说明：在合约内部直接用new关键字部署新合约。
- 特点：简单直观，适合小规模、无需复用逻辑的场景。

### 2. 外部部署
- 方式：通过Remix、Hardhat、Truffle、Foundry等开发工具，或Web3.js/Ethers.js/viem.js等前端库进行部署。
- 说明：适合链下批量部署、自动化脚本、前端一键部署等场景。
- 特点：灵活、可批量、适合开发和测试。

### 3. 最小代理合约（Minimal Proxy/Clone/EIP-1167）
- 方式：使用OpenZeppelin Clones库或手写EIP-1167字节码，批量部署轻量代理合约，所有代理共用同一份实现逻辑。
- 语法示例：
  ```solidity
  address clone = Clones.clone(implementation);
  ```
- 特点：极大节省gas和部署成本，适合大规模批量部署、逻辑完全一致的场景。
- 资料：
  - [EIP-1167: Minimal Proxy Contract](https://eips.ethereum.org/EIPS/eip-1167)
  - [OpenZeppelin Clones库](https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones)
  - [clone-factory github](https://github.com/optionality/clone-factory)

### 4. Create2（可预测地址部署）
- 语法：`C c = new C{salt: _salt}();`
- 说明：结合new关键字和salt参数，允许提前预测合约地址，适合钱包工厂、批量部署等场景。
- 特点：可预测性强，适合需要提前知道合约地址的业务。

---

## 二、InscriptionFactory合约方法设计说明

### 方法1：deployInscription
- 作用：用最小代理（EIP-1167）方式批量部署ERC20铭文合约。
- 知识点：
  - 体现了合约工厂+最小代理的组合用法。
  - 通过Clones库极大节省部署gas，所有铭文合约共用一份实现逻辑。
  - 适合大规模批量部署、逻辑一致的ERC20场景。

### 方法2：mintInscription
- 作用：用户可调用该方法，铸造指定ERC20铭文合约的Token。
- 知识点：
  - 体现了工厂合约对所有子合约的统一管理和交互。
  - 用户无需关心合约实现细节，只需通过工厂即可完成铸造。

---

## 三、各种合约创建方式对比
| 方式         | 优点                   | 缺点                   | 适用场景           |
|--------------|------------------------|------------------------|--------------------|
| new关键字    | 简单直观，易理解       | 不节省gas，无法复用    | 小规模、单一逻辑   |
| 外部部署     | 灵活、可批量           | 需链下脚本或前端配合   | 自动化、测试、前端 |
| 最小代理     | 极省gas、批量高效      | 逻辑不可变，升级复杂   | 大规模批量部署     |
| Create2      | 可预测地址、灵活       | 代码复杂度略高         | 钱包工厂、批量场景 |

---

## 四、相关资料
- [EIP-1167: Minimal Proxy Contract](https://eips.ethereum.org/EIPS/eip-1167)
- [OpenZeppelin Clones库](https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones)
- [clone-factory github](https://github.com/optionality/clone-factory)
- [Create2官方文档](https://docs.soliditylang.org/en/v0.8.20/control-structures.html#salted-contract-creations-create2)

---

## 五、总结
本合约通过工厂+最小代理的方式，既节省了部署成本，又方便了批量管理和统一铸造，适合大规模ERC20铭文场景。理解这些合约创建方式，有助于开发者根据实际业务需求选择最优方案。 