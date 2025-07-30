/**
 * NFT市场签名工具
 * 用于生成和验证EIP-712签名
 */

const ethers = require('ethers');

class NFTMarketSignatureHelper {
    constructor(marketAddress, chainId) {
        this.marketAddress = marketAddress;
        this.chainId = chainId;
        this.domain = {
            name: 'NFTMarketV2',
            version: '1',
            chainId: chainId,
            verifyingContract: marketAddress
        };
        this.types = {
            ListNFT: [
                { name: 'tokenId', type: 'uint256' },
                { name: 'price', type: 'uint256' },
                { name: 'nonce', type: 'uint256' }
            ]
        };
    }

    /**
     * 生成上架NFT的签名
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格（wei）
     * @param {number} nonce 用户nonce
     * @param {ethers.Signer} signer 签名者
     * @returns {Promise<Object>} 签名结果
     */
    async generateListSignature(tokenId, price, nonce, signer) {
        const value = {
            tokenId: tokenId,
            price: price,
            nonce: nonce
        };

        try {
            const signature = await signer._signTypedData(this.domain, this.types, value);
            const { v, r, s } = ethers.utils.splitSignature(signature);
            
            return {
                v: v,
                r: r,
                s: s,
                signature: signature
            };
        } catch (error) {
            throw new Error(`签名生成失败: ${error.message}`);
        }
    }

    /**
     * 验证签名
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格
     * @param {number} nonce 用户nonce
     * @param {number} v 签名v值
     * @param {string} r 签名r值
     * @param {string} s 签名s值
     * @param {string} expectedSigner 期望的签名者地址
     * @returns {boolean} 签名是否有效
     */
    verifySignature(tokenId, price, nonce, v, r, s, expectedSigner) {
        const value = {
            tokenId: tokenId,
            price: price,
            nonce: nonce
        };

        const recoveredAddress = ethers.utils.verifyTypedData(
            this.domain,
            this.types,
            value,
            { v, r, s }
        );

        return recoveredAddress.toLowerCase() === expectedSigner.toLowerCase();
    }

    /**
     * 从签名中恢复签名者地址
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格
     * @param {number} nonce 用户nonce
     * @param {number} v 签名v值
     * @param {string} r 签名r值
     * @param {string} s 签名s值
     * @returns {string} 签名者地址
     */
    recoverSigner(tokenId, price, nonce, v, r, s) {
        const value = {
            tokenId: tokenId,
            price: price,
            nonce: nonce
        };

        return ethers.utils.verifyTypedData(
            this.domain,
            this.types,
            value,
            { v, r, s }
        );
    }

    /**
     * 获取域名分隔符
     * @returns {string} 域名分隔符
     */
    getDomainSeparator() {
        return ethers.utils._TypedDataEncoder.hashDomain(this.domain);
    }

    /**
     * 获取结构化数据哈希
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格
     * @param {number} nonce 用户nonce
     * @returns {string} 结构化数据哈希
     */
    getStructHash(tokenId, price, nonce) {
        const value = {
            tokenId: tokenId,
            price: price,
            nonce: nonce
        };

        return ethers.utils._TypedDataEncoder.encode(this.domain, this.types, value);
    }
}

/**
 * NFT市场交互工具类
 */
class NFTMarketHelper {
    constructor(marketContract, nftContract, paymentToken) {
        this.marketContract = marketContract;
        this.nftContract = nftContract;
        this.paymentToken = paymentToken;
    }

    /**
     * 上架NFT（普通方式）
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格
     * @param {ethers.Signer} signer 签名者
     * @returns {Promise<ethers.ContractTransaction>} 交易结果
     */
    async listNFT(tokenId, price, signer) {
        // 先授权市场合约操作NFT
        const approveTx = await this.nftContract.connect(signer).approve(
            this.marketContract.address,
            tokenId
        );
        await approveTx.wait();

        // 上架NFT
        return await this.marketContract.connect(signer).list(tokenId, price);
    }

    /**
     * 使用签名上架NFT
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格
     * @param {number} deadline 过期时间
     * @param {number} v 签名v值
     * @param {string} r 签名r值
     * @param {string} s 签名s值
     * @param {ethers.Signer} signer 签名者
     * @returns {Promise<ethers.ContractTransaction>} 交易结果
     */
    async listNFTWithSignature(tokenId, price, deadline, v, r, s, signer) {
        // 先授权市场合约操作NFT
        const approveTx = await this.nftContract.connect(signer).approve(
            this.marketContract.address,
            tokenId
        );
        await approveTx.wait();

        // 使用签名上架NFT
        return await this.marketContract.connect(signer).listWithSignature(
            tokenId,
            price,
            deadline,
            v,
            r,
            s
        );
    }

    /**
     * 购买NFT
     * @param {number} tokenId NFT的ID
     * @param {string} price 价格
     * @param {ethers.Signer} signer 买家
     * @returns {Promise<ethers.ContractTransaction>} 交易结果
     */
    async buyNFT(tokenId, price, signer) {
        // 授权市场合约使用代币
        const approveTx = await this.paymentToken.connect(signer).approve(
            this.marketContract.address,
            price
        );
        await approveTx.wait();

        // 购买NFT
        return await this.marketContract.connect(signer).buyNFT(tokenId, price);
    }

    /**
     * 下架NFT
     * @param {number} tokenId NFT的ID
     * @param {ethers.Signer} signer 卖家
     * @returns {Promise<ethers.ContractTransaction>} 交易结果
     */
    async delistNFT(tokenId, signer) {
        return await this.marketContract.connect(signer).delist(tokenId);
    }

    /**
     * 更新NFT价格
     * @param {number} tokenId NFT的ID
     * @param {string} newPrice 新价格
     * @param {ethers.Signer} signer 卖家
     * @returns {Promise<ethers.ContractTransaction>} 交易结果
     */
    async updatePrice(tokenId, newPrice, signer) {
        return await this.marketContract.connect(signer).updatePrice(tokenId, newPrice);
    }

    /**
     * 获取NFT上架信息
     * @param {number} tokenId NFT的ID
     * @returns {Promise<Object>} 上架信息
     */
    async getListing(tokenId) {
        const listing = await this.marketContract.getListing(tokenId);
        return {
            seller: listing[0],
            price: listing[1],
            active: listing[2],
            listedAt: listing[3]
        };
    }

    /**
     * 获取用户nonce
     * @param {string} userAddress 用户地址
     * @returns {Promise<number>} nonce值
     */
    async getNonce(userAddress) {
        return await this.marketContract.nonces(userAddress);
    }

    /**
     * 获取市场版本
     * @returns {Promise<string>} 版本号
     */
    async getVersion() {
        return await this.marketContract.version();
    }
}

module.exports = {
    NFTMarketSignatureHelper,
    NFTMarketHelper
}; 