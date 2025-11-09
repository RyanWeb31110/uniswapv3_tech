// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC721.sol";

/// @title ERC721 元数据扩展接口
/// @notice 定义 NFT 元数据的标准接口
/// @dev 扩展了 ERC721，添加了 name、symbol 和 tokenURI
interface IERC721Metadata is IERC721 {
    /// @notice 返回代币集合的名称
    /// @return 代币集合名称
    function name() external view returns (string memory);

    /// @notice 返回代币集合的符号
    /// @return 代币集合符号
    function symbol() external view returns (string memory);

    /// @notice 返回代币的元数据 URI
    /// @dev 可以返回 HTTP 链接（链下存储）或 Data URI（链上存储）
    /// @param tokenId 代币的唯一 ID
    /// @return uri 元数据的链接或内联数据
    function tokenURI(uint256 tokenId) external view returns (string memory uri);
}
