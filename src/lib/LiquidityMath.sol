// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title LiquidityMath
/// @notice 流动性数学计算库
/// @dev 提供流动性的加减运算，处理溢出和精度问题
library LiquidityMath {
    /// @notice 添加流动性
    /// @dev 将新的流动性添加到现有流动性中
    /// @param x 现有流动性
    /// @param y 要添加的流动性
    /// @return z 添加后的流动性
    function addLiquidity(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            // 如果 y 是负数，相当于减去流动性
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            // 如果 y 是正数，直接添加流动性
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }
}
