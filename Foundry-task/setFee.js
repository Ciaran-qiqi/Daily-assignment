// setFee.js
// 通过代理合约地址+V2 ABI 设置和查询 NFT 市场手续费
// 使用方法：node setFee.js

const { ethers } = require("ethers");

// ====== 配置参数 ======
const proxyAddress = "0xb958F6e2434e98599ee5D4973f2300A5141748eb"; // 代理合约地址
const privateKey = "0x"; // 业务管理员私钥（请替换）
const rpcUrl = ""; // RPC节点（请替换）
const newFee = 100; // 1%，你要设置的fee（单位：基点，100=1%）

// ====== V2 ABI（只需包含你要用的函数） ======
const abi = [
  "function setMarketplaceFee(uint256 newFee) external",
  "function marketplaceFee() external view returns (uint256)"
];

// ====== 初始化 provider 和 signer ======
const provider = new ethers.JsonRpcProvider(rpcUrl);  // v6 写法
const signer = new ethers.Wallet(privateKey, provider);

// ====== 连接代理合约（用V2 ABI） ======
const market = new ethers.Contract(proxyAddress, abi, signer);

async function main() {
  // 查询当前手续费率
  const oldFee = await market.marketplaceFee();
  console.log("当前手续费率:", oldFee.toString());

  // 设置新手续费率
  const tx = await market.setMarketplaceFee(newFee);
  console.log("设置手续费交易已发送，hash:", tx.hash);
  await tx.wait();
  console.log("手续费设置成功！");

  // 再次查询
  const fee = await market.marketplaceFee();
  console.log("最新手续费率:", fee.toString());
}

main().catch(console.error);