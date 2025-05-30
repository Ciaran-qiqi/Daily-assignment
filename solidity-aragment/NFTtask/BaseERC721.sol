// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BaseERC721合约
 * @dev 一个基本的ERC721 NFT实现，包含标准ERC721接口的所有功能
 * @notice 这是一个教学用途的NFT合约，包含铸造、转移、授权等基本功能
 */
contract BaseERC721 {
    // NFT集合名称
    string public name;
    // NFT集合符号
    string public symbol;
    
    // 当前NFT的总数量，也用作下一个NFT的ID
    uint256 public totalSupply;
    
    // NFT ID对应的所有者地址
    mapping(uint256 => address) private _owners;
    
    // 地址对应的NFT数量
    mapping(address => uint256) private _balances;
    
    // NFT ID对应的被授权地址（单个NFT的授权）
    mapping(uint256 => address) private _tokenApprovals;
    
    // 所有者对操作员的全部授权（所有NFT的授权）
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    // NFT的元数据URI映射
    mapping(uint256 => string) private _tokenURIs;
    
    // 合约拥有者，用于控制铸造权限
    address public owner;
    
    // 事件定义
    // 转移事件：当NFT被转移时触发
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    // 授权事件：当单个NFT被授权时触发
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    // 全部授权事件：当所有NFT被授权给操作员时触发
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    /**
     * @dev 修饰器：只有合约拥有者才能调用
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev 构造函数，初始化NFT集合基本信息
     */
    constructor() {
        // 设置NFT集合基本信息
        name = "BaseNFT";           // NFT集合名称
        symbol = "BNFT";            // NFT集合符号
        owner = msg.sender;         // 设置合约部署者为拥有者
        totalSupply = 0;            // 初始总供应量为0
    }
    
    /**
     * @dev 查询指定地址拥有的NFT数量
     * @param _owner 要查询的地址
     * @return 该地址拥有的NFT数量
     */
    function balanceOf(address _owner) public view returns (uint256) {
        require(_owner != address(0), "ERC721: balance query for the zero address");
        return _balances[_owner];
    }
    
    /**
     * @dev 查询指定NFT的所有者
     * @param tokenId NFT的ID
     * @return 该NFT的所有者地址
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "ERC721: owner query for nonexistent token");
        return tokenOwner;
    }
    
    /**
     * @dev 查询指定NFT的元数据URI
     * @param tokenId NFT的ID
     * @return 该NFT的元数据URI
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
    
    /**
     * @dev 授权指定地址操作特定NFT
     * @param to 被授权的地址
     * @param tokenId NFT的ID
     */
    function approve(address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: approval to current owner");
        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );
        
        _approve(to, tokenId);
    }
    
    /**
     * @dev 查询指定NFT的被授权地址
     * @param tokenId NFT的ID
     * @return 被授权的地址
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }
    
    /**
     * @dev 设置或取消对操作员的全部授权
     * @param operator 操作员地址
     * @param approved 是否授权
     */
    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    /**
     * @dev 查询是否已授权操作员操作所有NFT
     * @param _owner NFT所有者地址
     * @param operator 操作员地址
     * @return 是否已授权
     */
    function isApprovedForAll(address _owner, address operator) public view returns (bool) {
        return _operatorApprovals[_owner][operator];
    }
    
    /**
     * @dev 转移NFT
     * @param from 发送方地址
     * @param to 接收方地址
     * @param tokenId NFT的ID
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }
    
    /**
     * @dev 安全转移NFT
     * @param from 发送方地址
     * @param to 接收方地址
     * @param tokenId NFT的ID
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    /**
     * @dev 安全转移NFT（带数据）
     * @param from 发送方地址
     * @param to 接收方地址
     * @param tokenId NFT的ID
     * @param _data 附加数据
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
    
    /**
     * @dev 铸造新的NFT（只有拥有者可以调用）
     * @param to 接收NFT的地址
     * @param tokenURI_ NFT的元数据URI
     * @return tokenId 新铸造的NFT ID
     */
    function mint(address to, string memory tokenURI_) public onlyOwner returns (uint256) {
        uint256 tokenId = totalSupply;
        totalSupply++;
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        
        return tokenId;
    }
    
    /**
     * @dev 批量铸造NFT（只有拥有者可以调用）
     * @param to 接收NFT的地址
     * @param tokenURIs NFT的元数据URI数组
     * @return tokenIds 新铸造的NFT ID数组
     */
    function batchMint(address to, string[] memory tokenURIs) public onlyOwner returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](tokenURIs.length);
        
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = totalSupply;
            totalSupply++;
            
            _mint(to, tokenId);
            _setTokenURI(tokenId, tokenURIs[i]);
            
            tokenIds[i] = tokenId;
        }
        
        return tokenIds;
    }
    
    /**
     * @dev 检查NFT是否存在
     * @param tokenId NFT的ID
     * @return 是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }
    
    /**
     * @dev 检查地址是否有权限操作NFT
     * @param spender 操作者地址
     * @param tokenId NFT的ID
     * @return 是否有权限
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner || getApproved(tokenId) == spender || isApprovedForAll(tokenOwner, spender));
    }
    
    /**
     * @dev 内部铸造函数
     * @param to 接收NFT的地址
     * @param tokenId NFT的ID
     */
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId);
    }
    
    /**
     * @dev 内部转移函数
     * @param from 发送方地址
     * @param to 接收方地址
     * @param tokenId NFT的ID
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        
        // 清除授权
        _approve(address(0), tokenId);
        
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    /**
     * @dev 内部授权函数
     * @param to 被授权的地址
     * @param tokenId NFT的ID
     */
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    
    /**
     * @dev 安全转移函数
     * @param from 发送方地址
     * @param to 接收方地址
     * @param tokenId NFT的ID
     * @param _data 附加数据
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    
    /**
     * @dev 设置NFT的元数据URI
     * @param tokenId NFT的ID
     * @param _tokenURI 元数据URI
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "ERC721: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    /**
     * @dev 检查接收方是否能接收ERC721代币
     * @param from 发送方地址
     * @param to 接收方地址
     * @param tokenId NFT的ID
     * @param _data 附加数据
     * @return 是否能接收
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}

/**
 * @title ERC721接收器接口
 * @dev 合约必须实现此接口才能接收ERC721代币
 */
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
} 