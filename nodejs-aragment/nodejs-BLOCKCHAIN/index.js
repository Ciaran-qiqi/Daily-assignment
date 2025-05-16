const crypto = require('crypto');

/**
 * 工作量证明(POW)函数
 * @param {string} nickname - 用户昵称
 * @param {number} prefixLength - 要求哈希值开头的0的个数
 * @returns {Object} 返回包含数据、哈希值、尝试次数和耗时信息的对象
 */
function findHashWithPrefix(nickname, prefixLength) {
  let nonce = 0;
  const startTime = Date.now();
  const targetPrefix = '0'.repeat(prefixLength);

  console.log(`\n开始寻找 ${targetPrefix} 开头的哈希...`);

  while (true) {
    const data = `${nickname}${nonce}`;
    const hash = crypto.createHash('sha256').update(data).digest('hex');

    if (hash.startsWith(targetPrefix)) {
      const endTime = Date.now();
      const timeSpent = (endTime - startTime) / 1000;

      console.log(`找到符合条件的哈希！`);
      console.log(`输入数据 : ${data}`);
      console.log(`哈希值   : ${hash}`);
      console.log(`尝试次数 : ${nonce}`);
      console.log(`耗时     : ${timeSpent} 秒`);

      return { data, hash, nonce, timeSpent };
    }

    nonce++;
  }
}

// 生成RSA密钥对
// 使用2048位密钥长度，这是目前推荐的安全长度
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
});

/**
 * 使用私钥对数据进行签名
 * @param {string} data - 要签名的数据
 * @param {string} privateKey - RSA私钥
 * @returns {string} 返回十六进制格式的签名
 */
function signData(data, privateKey) {
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(data);
  return sign.sign(privateKey, 'hex');
}

/**
 * 使用公钥验证签名
 * @param {string} data - 原始数据
 * @param {string} signature - 签名
 * @param {string} publicKey - RSA公钥
 * @returns {boolean} 返回签名是否有效
 */
function verifySignature(data, signature, publicKey) {
  const verify = crypto.createVerify('RSA-SHA256');
  verify.update(data);
  return verify.verify(publicKey, signature, 'hex');
}

// 设置用户昵称
const nickname = 'Alice';

// 任务1：实践POW工作量证明
// 分别查找4个0、5个0和6个0开头的哈希值
console.log('\n=========== POW工作量证明测试 ===========');
const result4zeros = findHashWithPrefix(nickname, 4);
const result5zeros = findHashWithPrefix(nickname, 5);
const result6zeros = findHashWithPrefix(nickname, 6);

// 任务2：实践RSA非对称加密
console.log('\n=========== 签名验证测试 ===========');
// 使用4个0开头的哈希结果进行签名验证
const dataToSign = `${nickname}${result4zeros.nonce}`;

// 使用私钥对数据进行签名
const signature = signData(dataToSign, privateKey);
console.log(`签名结果: ${signature.slice(0, 50)}...`);

// 使用公钥验证签名
const isValid = verifySignature(dataToSign, signature, publicKey);
console.log(`验证结果: ${isValid ? '✅ 签名有效' : '❌ 签名无效'}`);

/**
 * 区块类 - 定义区块链中的基本数据结构
 */
class Block {
  constructor(timestamp, data, previousHash = '') {
    this.timestamp = timestamp;        // 区块创建时间
    this.data = data;                 // 区块数据
    this.previousHash = previousHash;  // 前一个区块的哈希值
    this.nonce = 0;                   // 工作量证明的计数器
    this.hash = this.calculateHash(); // 当前区块的哈希值
  }

  /**
   * 计算区块的哈希值
   * 使用SHA256算法，将区块的所有属性组合后进行哈希
   */
  calculateHash() {
    return crypto.createHash('sha256')
      .update(this.previousHash + this.timestamp + JSON.stringify(this.data) + this.nonce)
      .digest('hex');
  }

  /**
   * 挖矿 - 实现工作量证明
   * @param {number} difficulty - 挖矿难度（要求哈希值开头的0的个数）
   */
  mineBlock(difficulty) {
    const target = '0'.repeat(difficulty);
    while (this.hash.substring(0, difficulty) !== target) {
      this.nonce++;
      this.hash = this.calculateHash();
    }
    console.log(`区块已挖出: ${this.hash}`);
  }
}

/**
 * 区块链类 - 管理整个区块链
 */
class Blockchain {
  constructor() {
    // 初始化区块链，创建创世区块
    this.chain = [this.createGenesisBlock()];
    this.difficulty = 4; // 设置挖矿难度
  }

  /**
   * 创建创世区块
   * 创世区块是区块链的第一个区块，previousHash设为0
   */
  createGenesisBlock() {
    return new Block(Date.now(), {
      prevHash: 0,
      nonce: 1,
      data: "创世区块"
    }, '0');
  }

  /**
   * 获取区块链中最新（最后一个）区块
   */
  getLatestBlock() {
    return this.chain[this.chain.length - 1];
  }

  /**
   * 添加新区块到区块链
   * @param {Object} newBlock - 要添加的新区块
   */
  addBlock(newBlock) {
    // 设置新区块的前一个区块的哈希值
    newBlock.previousHash = this.getLatestBlock().hash;
    // 挖矿（工作量证明）
    newBlock.mineBlock(this.difficulty);
    // 将新区块添加到链中
    this.chain.push(newBlock);
  }

  /**
   * 验证区块链是否有效
   * 检查每个区块的哈希值是否正确，以及区块之间的链接是否正确
   */
  isChainValid() {
    for (let i = 1; i < this.chain.length; i++) {
      const currentBlock = this.chain[i];
      const previousBlock = this.chain[i - 1];

      // 验证当前区块的哈希值是否正确
      if (currentBlock.hash !== currentBlock.calculateHash()) {
        return false;
      }

      // 验证区块是否指向正确的上一个区块
      if (currentBlock.previousHash !== previousBlock.hash) {
        return false;
      }
    }
    return true;
  }
}

// 测试区块链功能
console.log('\n=========== 区块链测试 ===========');

// 创建区块链实例
const myCoin = new Blockchain();

// 创建并添加第一个区块
console.log('\n创建第一个区块...');
const block1 = new Block(Date.now(), {
  from: 'Alice',
  to: 'Bob',
  amount: 100
});
myCoin.addBlock(block1);

// 创建并添加第二个区块
console.log('\n创建第二个区块...');
const block2 = new Block(Date.now(), {
  from: 'Bob',
  to: 'Charlie',
  amount: 50
});
myCoin.addBlock(block2);

// 打印区块链信息
console.log('\n区块链信息:');
console.log(JSON.stringify(myCoin.chain, null, 2));

// 验证区块链
console.log('\n验证区块链是否有效:', myCoin.isChainValid() ? '✅ 有效' : '❌ 无效');

