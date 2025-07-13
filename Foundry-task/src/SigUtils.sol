// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SigUtils
 * @dev EIP-712 签名工具合约，提供结构体hash、签名验证等常用方法。
 * 适用于ERC20Permit、NFT离线白名单等场景。
 */
library SigUtils {
    /**
     * @dev 计算EIP-712结构体的hash。
     * @param typeHash 结构体类型hash（如Permit类型hash）
     * @param encodedData abi.encode后的结构体数据
     * @return structHash 结构体hash
     */
    function structHash(bytes32 typeHash, bytes memory encodedData) internal pure returns (bytes32) {
        // 结构体hash = keccak256(abi.encode(typeHash, ...fields))
        return keccak256(abi.encodePacked(typeHash, encodedData));
    }

    /**
     * @dev 恢复签名者地址（EIP-712签名）。
     * @param digest EIP-712消息摘要
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return signer 签名者地址
     */
    function recoverSigner(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // 使用ecrecover恢复签名者地址
        return ecrecover(digest, v, r, s);
    }
} 