// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ERC721 非同质化代币标准接口
/// @notice 定义 NFT 合约的标准接口
/// @dev 参考 EIP-721 标准：https://eips.ethereum.org/EIPS/eip-721
interface IERC721 {
    /// @notice 代币转移事件
    /// @param from 转出地址
    /// @param to 转入地址
    /// @param tokenId 代币 ID
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @notice 授权事件
    /// @param owner 代币拥有者
    /// @param approved 被授权的地址
    /// @param tokenId 代币 ID
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /// @notice 全局授权事件
    /// @param owner 代币拥有者
    /// @param operator 操作者地址
    /// @param approved 是否授权
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice 查询地址拥有的代币数量
    /// @param owner 地址
    /// @return balance 代币数量
    function balanceOf(address owner) external view returns (uint256 balance);

    /// @notice 查询代币的拥有者
    /// @param tokenId 代币的唯一 ID
    /// @return owner 代币拥有者的地址
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /// @notice 安全转账（推荐使用）
    /// @dev 转账后会调用接收方的 onERC721Received 回调
    /// @param from 转出地址
    /// @param to 转入地址
    /// @param tokenId 代币 ID
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /// @notice 安全转账（带数据）
    /// @param from 转出地址
    /// @param to 转入地址
    /// @param tokenId 代币 ID
    /// @param data 附加数据
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /// @notice 普通转账
    /// @param from 转出地址
    /// @param to 转入地址
    /// @param tokenId 代币 ID
    function transferFrom(address from, address to, uint256 tokenId) external;

    /// @notice 授权单个代币
    /// @param to 被授权的地址
    /// @param tokenId 代币 ID
    function approve(address to, uint256 tokenId) external;

    /// @notice 授权或取消授权所有代币
    /// @param operator 操作者地址
    /// @param approved 是否授权
    function setApprovalForAll(address operator, bool approved) external;

    /// @notice 查询单个代币的授权地址
    /// @param tokenId 代币 ID
    /// @return operator 被授权的地址
    function getApproved(uint256 tokenId) external view returns (address operator);

    /// @notice 查询是否全局授权
    /// @param owner 代币拥有者
    /// @param operator 操作者地址
    /// @return 是否已授权
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
