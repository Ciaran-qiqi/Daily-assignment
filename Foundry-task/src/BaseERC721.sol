// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

/**
 * @title BaseERC721
 * @dev 一个基本的 ERC721 NFT 实现，包含标准 ERC721 接口的所有功能
 * @notice 这是一个教学用途的 NFT 合约，包含铸造、转移、授权等基本功能
 */
contract BaseERC721 is ERC721 {
    
    // 用于跟踪已铸造的 NFT 总数
    uint256 private _tokenIdCounter;
    
    /**
     * @dev 构造函数
     * @notice 初始化 NFT 合约，设置名称和符号
     */
    constructor() ERC721("BASE721", "BERC721") {
        // 合约初始化完成
    }
    
    /**
     * @dev 铸造新的 NFT
     * @param to 接收 NFT 的地址
     * @param tokenId NFT 的唯一标识符
     * @notice 任何人都可以调用此函数来铸造 NFT
     */
    function mint(address to, uint256 tokenId) public {
        require(to != address(0), "Cannot mint to zero address");
        require(_ownerOf(tokenId) == address(0), "Token already exists");
        
        _mint(to, tokenId);
        _tokenIdCounter++;
    }
    
    /**
     * @dev 批量铸造 NFT
     * @param to 接收 NFT 的地址
     * @param tokenIds NFT 的唯一标识符数组
     * @notice 一次性铸造多个 NFT
     */
    function batchMint(address to, uint256[] memory tokenIds) public {
        require(to != address(0), "Cannot mint to zero address");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_ownerOf(tokenIds[i]) == address(0), "Token already exists");
            _mint(to, tokenIds[i]);
            _tokenIdCounter++;
        }
    }
    
    /**
     * @dev 检查 NFT 是否存在
     * @param tokenId NFT 的唯一标识符
     * @return 如果 NFT 存在返回 true，否则返回 false
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    /**
     * @dev 获取合约中 NFT 的总数
     * @return 已铸造的 NFT 总数
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
} 