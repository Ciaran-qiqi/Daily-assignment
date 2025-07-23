// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title InscriptionERC20
 * @dev 可初始化的ERC20铭文合约，支持铭文工厂批量部署
 */
contract InscriptionERC20 is ERC20 {
    address public factory;
    uint256 public maxSupply;
    uint256 public perMint;
    bool public initialized;
    // 自定义存储变量
    string private _customName;
    string private _customSymbol;

    constructor() ERC20("", "") {
        factory = msg.sender;
    }

    /**
     * @dev 初始化铭文参数，只能调用一次
     */
    function initialize(string memory name_, string memory symbol_, uint256 maxSupply_, uint256 perMint_) external {
        require(!initialized, "Already initialized");
        require(msg.sender == factory, "Only factory");
        _customName = name_;
        _customSymbol = symbol_;
        maxSupply = maxSupply_;
        perMint = perMint_;
        initialized = true;
    }

    /**
     * @dev 重写name/symbol函数，返回自定义值
     */
    function name() public view override returns (string memory) {
        return _customName;
    }
    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }

    /**
     * @dev 铭文铸造，单次最多perMint，且总量不超过maxSupply
     */
    function mint(address to, uint256 amount) external {
        require(initialized, "Not initialized");
        require(amount <= perMint, "Exceed perMint");
        require(totalSupply() + amount <= maxSupply, "Exceed maxSupply");
        _mint(to, amount);
    }
}

/**
 * @title InscriptionFactory
 * @dev 铭文工厂合约，支持最小代理批量部署ERC20铭文
 */
contract InscriptionFactory {
    // 铭文ERC20实现合约地址
    address public immutable implementation;
    // 记录所有已部署铭文ERC20地址
    address[] public allInscriptions;

    event InscriptionDeployed(address indexed inscription, string name, string symbol, uint256 maxSupply, uint256 perMint);
    event InscriptionMinted(address indexed inscription, address indexed to, uint256 amount);

    constructor() {
        // 部署一次实现合约，后续clone
        implementation = address(new InscriptionERC20());
    }

    /**
     * @dev 方法1：最小代理方式部署ERC20铭文
     * @param name 铭文名称
     * @param symbol 铭文符号
     * @param totalSupply 铭文总量
     * @param perMint 单次最大铸造量
     * @return cloneAddr 新部署的铭文ERC20地址
     */
    function deployInscription(string memory name, string memory symbol, uint256 totalSupply, uint256 perMint) external returns (address cloneAddr) {
        // 使用OpenZeppelin Clones库创建最小代理合约
        cloneAddr = Clones.clone(implementation);
        // 先记录，规避重入风险
        allInscriptions.push(cloneAddr);
        emit InscriptionDeployed(cloneAddr, name, symbol, totalSupply, perMint);
        // 再初始化铭文参数
        InscriptionERC20(cloneAddr).initialize(name, symbol, totalSupply, perMint);
    }

    /**
     * @dev 方法2：用户铸造指定铭文ERC20
     * @param tokenAddr 铭文ERC20地址
     */
    function mintInscription(address tokenAddr) external {
        // 默认每次铸造perMint数量
        uint256 perMint = InscriptionERC20(tokenAddr).perMint();
        InscriptionERC20(tokenAddr).mint(msg.sender, perMint);
        emit InscriptionMinted(tokenAddr, msg.sender, perMint);
    }

    /**
     * @dev 查询所有已部署铭文ERC20
     */
    function getAllInscriptions() external view returns (address[] memory) {
        return allInscriptions;
    }
} 