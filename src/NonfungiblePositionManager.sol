// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IERC721Metadata.sol";
import "./lib/Strings.sol";
import "./lib/Base64.sol";

/// @title Uniswap V3 NFT 仓位管理器
/// @notice 将流动性仓位封装为 ERC721 NFT
/// @dev 实现了 ERC721Metadata 接口，支持链上 SVG 和元数据生成
contract NonfungiblePositionManager is IERC721Metadata {
    using Strings for uint256;

    // ============ 状态变量 ============

    /// @notice NFT 集合名称
    string public constant override name = "Uniswap V3 Positions NFT-V1";

    /// @notice NFT 集合符号
    string public constant override symbol = "UNI-V3-POS";

    /// @notice tokenId => 拥有者地址
    mapping(uint256 => address) private _owners;

    /// @notice 地址 => 拥有的代币数量
    mapping(address => uint256) private _balances;

    /// @notice tokenId => 授权的地址
    mapping(uint256 => address) private _tokenApprovals;

    /// @notice owner => (operator => 是否授权)
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /// @notice 下一个 tokenId（从 1 开始）
    uint256 private _nextId = 1;

    // ============ 仓位信息 ============

    /// @notice 仓位信息结构体
    struct Position {
        address pool;       // 所属池子地址
        int24 tickLower;    // 价格区间下限
        int24 tickUpper;    // 价格区间上限
        uint128 liquidity;  // 流动性数量
        uint256 feeGrowthInside0LastX128;  // 手续费累积快照（token0）
        uint256 feeGrowthInside1LastX128;  // 手续费累积快照（token1）
        uint128 tokensOwed0;  // 待领取的手续费（token0）
        uint128 tokensOwed1;  // 待领取的手续费（token1）
    }

    /// @notice tokenId => Position
    mapping(uint256 => Position) public positions;

    // ============ 错误定义 ============

    error InvalidTokenId();
    error NotAuthorized();
    error InvalidRecipient();
    error TokenAlreadyMinted();
    error NotTokenOwner();

    // ============ ERC721 核心函数 ============

    /// @notice 查询地址拥有的代币数量
    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "Invalid owner");
        return _balances[owner];
    }

    /// @notice 查询代币的拥有者
    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert InvalidTokenId();
        return owner;
    }

    /// @notice 安全转账
    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @notice 安全转账（带数据）
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory /* data */
    ) public override {
        transferFrom(from, to, tokenId);
        // TODO: 实现 onERC721Received 回调检查
    }

    /// @notice 普通转账
    function transferFrom(address from, address to, uint256 tokenId) public override {
        // 检查调用者权限
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();

        // 检查 from 是否是代币拥有者
        if (ownerOf(tokenId) != from) revert NotTokenOwner();

        // 检查 to 地址有效性
        if (to == address(0)) revert InvalidRecipient();

        // 清除授权
        _approve(address(0), tokenId);

        // 更新余额
        _balances[from] -= 1;
        _balances[to] += 1;

        // 转移所有权
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /// @notice 授权单个代币
    function approve(address to, uint256 tokenId) external override {
        address owner = ownerOf(tokenId);
        require(to != owner, "Approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "Not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /// @notice 授权或取消授权所有代币
    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "Approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice 查询单个代币的授权地址
    function getApproved(uint256 tokenId) public view override returns (address) {
        if (_owners[tokenId] == address(0)) revert InvalidTokenId();
        return _tokenApprovals[tokenId];
    }

    /// @notice 查询是否全局授权
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    // ============ ERC721 元数据函数 ============

    /// @notice 返回代币的元数据 URI
    /// @dev 生成链上 JSON 和 SVG
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        if (_owners[tokenId] == address(0)) revert InvalidTokenId();

        // 获取仓位信息
        Position memory position = positions[tokenId];

        // 生成 JSON 元数据
        string memory json = string(
            abi.encodePacked(
                '{"name":"Uniswap V3 Position #',
                tokenId.toString(),
                '","description":"This NFT represents a liquidity position in a Uniswap V3 pool.",',
                '"image":"data:image/svg+xml;base64,',
                _generateSVG(tokenId, position),
                '","attributes":[',
                '{"trait_type":"Pool","value":"',
                Strings.toHexString(position.pool),
                '"},',
                '{"trait_type":"Tick Lower","value":"',
                _int24ToString(position.tickLower),
                '"},',
                '{"trait_type":"Tick Upper","value":"',
                _int24ToString(position.tickUpper),
                '"},',
                '{"trait_type":"Liquidity","value":"',
                uint256(position.liquidity).toString(),
                '"}]}'
            )
        );

        // 返回 Data URI
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    // ============ 内部辅助函数 ============

    /// @notice 生成 SVG 图像（Base64 编码）
    function _generateSVG(uint256 tokenId, Position memory position) internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="290" height="500">',
                '<rect width="290" height="500" fill="#1a1a2e"/>',
                '<rect x="10" y="10" width="270" height="480" rx="15" fill="#16213e" stroke="#0f3460" stroke-width="2"/>',
                '<text x="145" y="60" text-anchor="middle" fill="#e94560" font-size="24" font-weight="bold">Uniswap V3</text>',
                '<text x="145" y="90" text-anchor="middle" fill="#ffffff" font-size="16">Position #',
                tokenId.toString(),
                "</text>",
                '<line x1="30" y1="110" x2="260" y2="110" stroke="#0f3460" stroke-width="1"/>',
                '<text x="30" y="140" fill="#00d9ff" font-size="14">Tick Lower:</text>',
                '<text x="260" y="140" text-anchor="end" fill="#ffffff" font-size="14">',
                _int24ToString(position.tickLower),
                "</text>",
                '<text x="30" y="170" fill="#00d9ff" font-size="14">Tick Upper:</text>',
                '<text x="260" y="170" text-anchor="end" fill="#ffffff" font-size="14">',
                _int24ToString(position.tickUpper),
                "</text>",
                '<text x="30" y="200" fill="#00d9ff" font-size="14">Liquidity:</text>',
                '<text x="260" y="200" text-anchor="end" fill="#ffffff" font-size="12">',
                uint256(position.liquidity).toString(),
                "</text>",
                "</svg>"
            )
        );

        return Base64.encode(bytes(svg));
    }

    /// @notice 将 int24 转换为字符串
    function _int24ToString(int24 value) internal pure returns (string memory) {
        if (value >= 0) {
            return uint256(int256(value)).toString();
        } else {
            return string(abi.encodePacked("-", uint256(int256(-value)).toString()));
        }
    }

    /// @notice 检查地址是否有权限操作代币
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /// @notice 内部授权函数
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /// @notice 内部铸造函数
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert InvalidRecipient();
        if (_owners[tokenId] != address(0)) revert TokenAlreadyMinted();

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    // ============ 仓位管理函数（待后续章节实现）============

    /// @notice 铸造新的仓位 NFT
    /// @dev 这里只是示例结构，具体实现将在后续章节完成
    function mint(address pool, int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
        returns (uint256 tokenId)
    {
        tokenId = _nextId++;
        _mint(msg.sender, tokenId);

        positions[tokenId] = Position({
            pool: pool,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
    }
}
