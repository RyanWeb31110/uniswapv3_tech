// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";
import "prb-math/Common.sol" as PRBMath;

/// @title LiquidityAmounts
/// @notice 流动性数量计算库,用于根据代币数量和价格区间计算流动性
/// @dev 使用 PRBMath 库来处理高精度数学运算,避免溢出
library LiquidityAmounts {

    /// @notice 根据代币0的数量计算流动性
    /// @dev 当价格区间在当前价格下方时使用此函数
    /// @param sqrtPriceAX96 价格区间下限的平方根价格（Q64.96格式）
    /// @param sqrtPriceBX96 价格区间上限的平方根价格（Q64.96格式）
    /// @param amount0 代币0的数量
    /// @return liquidity 计算得到的流动性
    function getLiquidityForAmount0(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        // 确保 sqrtPriceA <= sqrtPriceB
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        // 计算中间值: sqrt(P_lower) * sqrt(P_upper) / Q96
        // 这对应公式中的分子部分
        uint256 intermediate = PRBMath.mulDiv(
            sqrtPriceAX96,
            sqrtPriceBX96,
            FixedPoint96.Q96
        );

        // 计算流动性: amount0 * intermediate / (sqrtPriceB - sqrtPriceA)
        // 公式: L = (Δx · √P_u · √P_l) / (√P_u - √P_l)
        liquidity = uint128(
            PRBMath.mulDiv(
                amount0,
                intermediate,
                sqrtPriceBX96 - sqrtPriceAX96
            )
        );
    }

    /// @notice 根据代币1的数量计算流动性
    /// @dev 当价格区间在当前价格上方时使用此函数
    /// @param sqrtPriceAX96 价格区间下限的平方根价格（Q64.96格式）
    /// @param sqrtPriceBX96 价格区间上限的平方根价格（Q64.96格式）
    /// @param amount1 代币1的数量
    /// @return liquidity 计算得到的流动性
    function getLiquidityForAmount1(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        // 确保 sqrtPriceA <= sqrtPriceB
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        // 计算流动性: amount1 * Q96 / (sqrtPriceB - sqrtPriceA)
        // 公式: L = Δy / (√P_u - √P_l)
        liquidity = uint128(
            PRBMath.mulDiv(
                amount1,
                FixedPoint96.Q96,
                sqrtPriceBX96 - sqrtPriceAX96
            )
        );
    }

    /// @notice 根据当前价格和代币数量计算流动性
    /// @dev 根据当前价格的位置选择不同的计算方法
    /// @param sqrtPriceX96 当前的平方根价格（Q64.96格式）
    /// @param sqrtPriceAX96 价格区间下限的平方根价格（Q64.96格式）
    /// @param sqrtPriceBX96 价格区间上限的平方根价格（Q64.96格式）
    /// @param amount0 用户提供的代币0数量
    /// @param amount1 用户提供的代币1数量
    /// @return liquidity 计算得到的流动性
    function getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        // 确保价格区间有序
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        // 情况1: 当前价格 < 价格区间下限
        // 只需要代币0（X）,因为价格在区间下方
        if (sqrtPriceX96 <= sqrtPriceAX96) {
            liquidity = getLiquidityForAmount0(
                sqrtPriceAX96,
                sqrtPriceBX96,
                amount0
            );
        }
        // 情况2: 价格区间下限 <= 当前价格 <= 价格区间上限
        // 需要两种代币,选择较小的流动性
        else if (sqrtPriceX96 <= sqrtPriceBX96) {
            // 基于代币0计算流动性
            uint128 liquidity0 = getLiquidityForAmount0(
                sqrtPriceX96,      // 使用当前价格作为下限
                sqrtPriceBX96,     // 使用区间上限
                amount0
            );

            // 基于代币1计算流动性
            uint128 liquidity1 = getLiquidityForAmount1(
                sqrtPriceAX96,     // 使用区间下限
                sqrtPriceX96,      // 使用当前价格作为上限
                amount1
            );

            // 选择较小的流动性,确保两种代币都足够
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
        // 情况3: 当前价格 > 价格区间上限
        // 只需要代币1（Y）,因为价格在区间上方
        else {
            liquidity = getLiquidityForAmount1(
                sqrtPriceAX96,
                sqrtPriceBX96,
                amount1
            );
        }
    }
}
