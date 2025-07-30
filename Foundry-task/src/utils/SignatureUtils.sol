// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SignatureUtils
 * @dev 签名工具库，用于生成和验证EIP-712签名
 */
library SignatureUtils {
    bytes32 public constant LIST_TYPEHASH = keccak256("ListNFT(uint256 tokenId,uint256 price,uint256 nonce)");
    
    /**
     * @dev 构建EIP-712域名分隔符
     * @param name 合约名称
     * @param version 版本号
     * @param chainId 链ID
     * @param verifyingContract 验证合约地址
     * @return 域名分隔符
     */
    function buildDomainSeparator(
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
    }
    
    /**
     * @dev 构建结构化数据哈希
     * @param tokenId NFT的ID
     * @param price 价格
     * @param nonce 用户nonce
     * @return 结构化数据哈希
     */
    function buildStructHash(
        uint256 tokenId,
        uint256 price,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(LIST_TYPEHASH, tokenId, price, nonce));
    }
    
    /**
     * @dev 构建完整的消息哈希
     * @param domainSeparator 域名分隔符
     * @param structHash 结构化数据哈希
     * @return 完整的消息哈希
     */
    function buildMessageHash(
        bytes32 domainSeparator,
        bytes32 structHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
    
    /**
     * @dev 验证签名
     * @param messageHash 消息哈希
     * @param v 签名v值
     * @param r 签名r值
     * @param s 签名s值
     * @param expectedSigner 期望的签名者地址
     * @return 签名是否有效
     */
    function verifySignature(
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address expectedSigner
    ) internal pure returns (bool) {
        address signer = ecrecover(messageHash, v, r, s);
        return signer == expectedSigner;
    }
    
    /**
     * @dev 从签名中恢复签名者地址
     * @param messageHash 消息哈希
     * @param v 签名v值
     * @param r 签名r值
     * @param s 签名s值
     * @return 签名者地址
     */
    function recoverSigner(
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        return ecrecover(messageHash, v, r, s);
    }
} 