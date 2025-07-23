// SPDX-License-Identifier: MIT
// wake-disable unsafe-erc20-call 
// wake-disable unsafe-transfer
// wake-disable unchecked-return-value

// 引入OpenZeppelin的MerkleProof库用于默克尔树白名单校验
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
// 引入IERC20接口（需支持permit）
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// 引入IERC721接口
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
// 引入IERC20Permit接口（用于permit授权）
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title AirdopMerkleNFTMarket
 * @dev 结合Multicall、Merkle树白名单、ERC20 permit授权，实现白名单优惠价购买NFT
 */
contract AirdopMerkleNFTMarket {
    // ERC20代币合约地址（需支持permit）
    IERC20 public immutable token;
    // NFT合约地址
    IERC721 public immutable nft;
    // 默克尔树根节点
    bytes32 public immutable merkleRoot;
    // 优惠价格（单位：Token）
    uint256 public constant DISCOUNT_PRICE = 100 * 1e18;
    // 记录已领取NFT的地址，防止重复领取
    mapping(address => bool) public hasClaimed;

    /**
     * @dev 构造函数，初始化Token、NFT、MerkleRoot
     * @param _token ERC20合约地址
     * @param _nft NFT合约地址
     * @param _merkleRoot 默克尔树根节点
     */
    constructor(address _token, address _nft, bytes32 _merkleRoot) {
        token = IERC20(_token);
        nft = IERC721(_nft);
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev permit预授权，允许本合约支配用户100 Token
     * @param owner 授权人地址
     * @param spender 被授权人（本合约）
     * @param value 授权金额（应为100 Token）
     * @param deadline 授权截止时间
     * @param v,r,s 签名参数
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 调用ERC20的permit方法，完成链上授权，无需owner提前approve
        // 这里假设token合约实现了IERC20Permit接口
        IERC20Permit(address(token)).permit(owner, spender, value, deadline, v, r, s);
    }

    /**
     * @dev 白名单用户领取NFT，需校验MerkleProof并支付100 Token
     * @param to NFT接收者
     * @param tokenId NFT编号
     * @param merkleProof 默克尔树证明
     */
    function claimNFT(address to, uint256 tokenId, bytes32[] calldata merkleProof) external {
        // 校验是否已领取
        require(!hasClaimed[to], "Already claimed");
        // 校验白名单
        bytes32 leaf = keccak256(abi.encodePacked(to));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Not in whitelist");
        // 支付100 Token（需提前permit授权）
        // 用户需先用permit授权本合约支配100 Token
        token.transferFrom(to, address(this), DISCOUNT_PRICE);
        // 发放NFT，真正将NFT转给用户
        nft.safeTransferFrom(address(this), to, tokenId);
        // 标记已领取，防止重复领取
        hasClaimed[to] = true;
    }

    /**
     * @dev Multicall，允许用户一次性调用多个方法（如permitPrePay和claimNFT）
     * @param data 调用数据数组
     * @return results 每次调用的返回结果
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            // 使用delegatecall调用本合约方法，实现原子性
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall: call failed");
            results[i] = result;
        }
    }
}
