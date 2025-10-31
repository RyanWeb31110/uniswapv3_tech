// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./BytesLib.sol";

/// @title 交换路径处理库
/// @notice 用于编码、解码和遍历多池交换路径
/// @dev 路径格式：token0 (20 bytes) + tickSpacing (3 bytes) + token1 (20 bytes) + ...
library Path {
    using BytesLib for bytes;

    // ========== 常量定义 ==========

    /// @dev 地址的字节长度
    uint256 private constant ADDR_SIZE = 20;

    /// @dev Tick spacing 的字节长度（uint24）
    uint256 private constant TICKSPACING_SIZE = 3;

    /// @dev 单个代币地址 + tick spacing 的偏移量
    /// 用于跳到下一个代币地址
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + TICKSPACING_SIZE;

    /// @dev 完整池子参数的偏移量（tokenIn + tickSpacing + tokenOut）
    /// 用于提取单个池子的完整参数
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;

    /// @dev 包含 2 个或更多池子的路径的最小长度
    /// 第一个池子 (46 bytes) + 下一个代币 + tick spacing (23 bytes)
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH = POP_OFFSET + NEXT_OFFSET;

    // ========== 功能函数 ==========

    /// @notice 计算路径中包含的池子数量
    /// @param path 编码的交换路径
    /// @return 池子数量
    /// @dev 计算公式：(路径总长度 - 最后一个地址) / (地址 + tick spacing)
    function numPools(bytes memory path) internal pure returns (uint256) {
        return (path.length - ADDR_SIZE) / NEXT_OFFSET;
    }

    /// @notice 判断路径是否包含多个池子
    /// @param path 编码的交换路径
    /// @return true 表示包含 2 个或更多池子，false 表示只有 1 个池子
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    /// @notice 提取路径中第一个池子的完整参数
    /// @param path 编码的交换路径
    /// @return 第一个池子的参数（tokenIn + tickSpacing + tokenOut，共 46 字节）
    function getFirstPool(bytes memory path)
        internal
        pure
        returns (bytes memory)
    {
        return path.slice(0, POP_OFFSET);
    }

    /// @notice 跳过当前代币和 tick spacing，移动到下一个池子
    /// @param path 编码的交换路径
    /// @return 移除第一个"地址 + tick spacing"后的剩余路径
    /// @dev 用于遍历多池路径时逐步前进
    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }

    /// @notice 解码第一个池子的详细参数
    /// @param path 编码的交换路径
    /// @return tokenIn 输入代币地址
    /// @return tokenOut 输出代币地址
    /// @return tickSpacing Tick 间距
    function decodeFirstPool(bytes memory path)
        internal
        pure
        returns (
            address tokenIn,
            address tokenOut,
            uint24 tickSpacing
        )
    {
        // 提取第一个地址（字节 0-19）
        tokenIn = path.toAddress(0);

        // 提取 tick spacing（字节 20-22）
        tickSpacing = path.toUint24(ADDR_SIZE);

        // 提取第二个地址（字节 23-42）
        tokenOut = path.toAddress(NEXT_OFFSET);
    }
}
