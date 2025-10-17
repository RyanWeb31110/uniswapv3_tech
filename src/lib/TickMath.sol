// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";

/// @title TickMath
/// @notice 提供 Tick 和价格之间的转换函数
/// @dev 基于 Uniswap V3 的 TickMath 实现
library TickMath {
    // ============ 常量 ============
    
    /// @notice 最小 Tick 索引
    int24 internal constant MIN_TICK = -887272;
    /// @notice 最大 Tick 索引
    int24 internal constant MAX_TICK = -MIN_TICK;
    
    /// @notice 最小价格（对应 MIN_TICK）
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @notice 最大价格（对应 MAX_TICK）
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    // ============ 错误定义 ============
    
    error TickOutOfRange();
    error PriceOutOfRange();

    // ============ 转换函数 ============

    /// @notice 根据 Tick 索引计算对应的平方根价格
    /// @dev 使用公式：sqrtPrice = sqrt(1.0001^tick) * 2^96
    /// @param tick Tick 索引
    /// @return sqrtPriceX96 对应的平方根价格（Q64.96 格式）
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        // 检查 Tick 是否在有效范围内
        if (tick < MIN_TICK || tick > MAX_TICK) revert TickOutOfRange();
        
        // 简化实现：对于学习目的，我们使用一个更保守的实现
        // 当 tick = 0 时，价格应该是 1.0，即 sqrtPriceX96 = 2^96
        
        if (tick == 0) {
            sqrtPriceX96 = uint160(1 << 96); // 2^96
        } else if (tick > 0) {
            // 正 tick：价格 > 1.0
            // 使用简单的线性近似：每增加 1 tick，价格增加约 0.01%
            uint256 priceMultiplier = 10000 + uint256(uint24(tick)); // 基础 10000 + tick
            sqrtPriceX96 = uint160((1 << 96) * priceMultiplier / 10000);
        } else {
            // 负 tick：价格 < 1.0
            // 使用简单的线性近似：每减少 1 tick，价格减少约 0.01%
            uint256 priceMultiplier = 10000 - uint256(uint24(-tick)); // 基础 10000 - |tick|
            if (priceMultiplier == 0) priceMultiplier = 1; // 避免除零
            sqrtPriceX96 = uint160((1 << 96) * priceMultiplier / 10000);
        }
        
        // 确保结果在有效范围内
        if (sqrtPriceX96 < MIN_SQRT_RATIO) sqrtPriceX96 = MIN_SQRT_RATIO;
        if (sqrtPriceX96 >= MAX_SQRT_RATIO) sqrtPriceX96 = MAX_SQRT_RATIO - 1;
    }

    /// @notice 根据平方根价格计算对应的 Tick 索引
    /// @dev 使用简化算法
    /// @param sqrtPriceX96 平方根价格（Q64.96 格式）
    /// @return tick 对应的 Tick 索引
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        // 检查价格是否在有效范围内
        if (sqrtPriceX96 < MIN_SQRT_RATIO || sqrtPriceX96 >= MAX_SQRT_RATIO) revert PriceOutOfRange();
        
        // 简化实现：使用近似计算
        // 对于学习目的，我们使用一个简化的实现
        
        // 计算价格（从 Q64.96 格式转换）
        uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> (96 * 2);
        
        // 使用对数近似计算 Tick
        // ln(price) / ln(1.0001) ≈ tick
        // ln(1.0001) ≈ 0.00009999500033330835
        
        if (price == 0) {
            tick = MIN_TICK;
        } else {
            // 计算 ln(price) 的近似值
            int256 logPrice = 0;
            uint256 temp = price;
            
            // 使用位运算计算对数的近似值
            while (temp > 1) {
                temp >>= 1;
                logPrice += 693147180559945309417; // ln(2) * 1e18
            }
            
            // 计算 Tick
            tick = int24(logPrice / 9999500033330835); // 除以 ln(1.0001)
        }
        
        // 确保结果在有效范围内
        if (tick < MIN_TICK) tick = MIN_TICK;
        if (tick > MAX_TICK) tick = MAX_TICK;
    }
}
