// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./Math.sol";
import "./FixedPoint96.sol";

/// @title SwapMath 交换数学库
/// @notice 提供交换相关的数学计算函数
/// @dev 基于 Uniswap V3 的交换数学库实现
library SwapMath {
    // ============ 错误定义 ============
    
    error DivisionByZero();
    error Overflow();

    // ============ 交换计算函数 ============

    /// @notice 计算单步交换的输入输出金额和下一个价格
    /// @param sqrtPriceCurrentX96 当前价格的平方根
    /// @param sqrtPriceTargetX96 目标价格的平方根
    /// @param liquidity 当前流动性
    /// @param amountRemaining 剩余交换金额
    /// @param zeroForOne 交换方向，true表示用token0换token1
    /// @return sqrtPriceNextX96 交换后的价格平方根
    /// @return amountIn 实际输入金额
    /// @return amountOut 实际输出金额
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96, uint256 amountIn, uint256 amountOut) {
        // 计算当前价格区间能够满足的最大输入金额
        uint256 amountInMax = zeroForOne
            ? Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity
            )
            : Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity
            );

        // 判断当前区间是否有足够流动性满足整个交换
        if (amountRemaining >= amountInMax) {
            // 当前区间流动性不足，使用整个区间的流动性
            sqrtPriceNextX96 = sqrtPriceTargetX96;
        } else {
            // 当前区间流动性充足，计算实际能达到的价格
            sqrtPriceNextX96 = Math.getNextSqrtPriceFromInput(
                sqrtPriceCurrentX96,
                liquidity,
                amountRemaining,
                zeroForOne
            );
        }

        // 重新计算实际的输入输出金额
        if (zeroForOne) {
            amountIn = Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity
            );
            amountOut = Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity
            );
        } else {
            amountIn = Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity
            );
            amountOut = Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity
            );
        }
    }
}
