// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AirdopMerkleNFTMarket.sol";
import "../src-nft721/BaseERC20.sol";
import "../src-nft721/BaseERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

// 测试专用ERC20Permit，带mint功能
contract TestERC20Permit is ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20Permit(name) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract AirdopMerkleNFTMarketTest is Test {
    // 测试用ERC20Permit代币
    TestERC20Permit public token;
    // 测试用ERC721 NFT
    BaseERC721 public nft;
    // 被测合约
    AirdopMerkleNFTMarket public market;
    // 白名单相关
    bytes32 public merkleRoot;
    bytes32[] public merkleProof;
    address public user;
    uint256 public userPrivateKey;
    uint256 public tokenId = 1;

    function setUp() public {
        // 初始化用户
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);
        // 部署ERC20Permit代币，初始给user大量余额
        token = new TestERC20Permit("TestToken", "TTK");
        token.mint(user, 1000 ether);
        // 部署NFT合约
        nft = new BaseERC721();
        // 构造白名单（仅user）
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        merkleRoot = MerkleProof.processProof(new bytes32[](0), leaf); // 单个用户直接用leaf
        // 部署市场合约
        market = new AirdopMerkleNFTMarket(address(token), address(nft), merkleRoot);
        // NFT预mint到market合约
        nft.mint(address(market), tokenId);
    }

    function getPermitDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        // EIP-2612 Permit类型哈希
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        // 构造结构体哈希
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        // 获取EIP712域分隔符
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        // 构造EIP712 digest
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function testPermitPrePayAndClaimNFT() public {
        // 1. 用户签名permit授权（严格EIP-2612）
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;
        uint256 nonce = token.nonces(user);
        bytes32 digest = getPermitDigest(user, address(market), value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        // 2. 用户调用permitPrePay
        vm.prank(user);
        market.permitPrePay(user, address(market), value, deadline, v, r, s);
        // 3. 用户调用claimNFT
        bytes32[] memory proof = new bytes32[](0); // 单用户白名单无需proof
        vm.prank(user);
        market.claimNFT(user, tokenId, proof);
        // 4. 检查NFT归属
        assertEq(nft.ownerOf(tokenId), user);
        // 5. 检查Token扣除
        assertEq(token.balanceOf(user), 900 ether);
    }

    function testMulticallPermitAndClaim() public {
        // 1. 用户签名permit授权（严格EIP-2612）
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;
        uint256 nonce = token.nonces(user);
        bytes32 digest = getPermitDigest(user, address(market), value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        // 2. 构造permitPrePay和claimNFT的calldata
        bytes memory call1 = abi.encodeWithSelector(
            market.permitPrePay.selector,
            user, address(market), value, deadline, v, r, s
        );
        bytes memory call2 = abi.encodeWithSelector(
            market.claimNFT.selector,
            user, tokenId, new bytes32[](0)
        );
        bytes[] memory calls = new bytes[](2);
        calls[0] = call1;
        calls[1] = call2;
        // 3. 用户一次性multicall
        vm.prank(user);
        market.multicall(calls);
        // 4. 检查NFT归属
        assertEq(nft.ownerOf(tokenId), user);
        // 5. 检查Token扣除
        assertEq(token.balanceOf(user), 900 ether);
    }
} 