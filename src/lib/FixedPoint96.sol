// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title FixedPoint96
/// @notice 提供 Q64.96 定点数格式的常量
/// @dev 用于价格和流动性计算
library FixedPoint96 {
    /// @notice Q64.96 格式的精度（2^96）
    uint8 internal constant RESOLUTION = 96;
    
    /// @notice Q64.96 格式的基数（2^96）
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
