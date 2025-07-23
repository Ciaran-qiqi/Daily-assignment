// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
/**
 * @title BaseERC721合约
 * @dev 一个基本的ERC721 NFT实现，包含标准ERC721接口的所有功能
 * @notice 这是一个教学用途的NFT合约，包含铸造、转移、授权等基本功能
 */
contract BaseERC721 is ERC721 {
    constructor() ERC721("BASE721", "BERC721") {
    }
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

}