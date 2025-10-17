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

    /// @notice 计算单次交换步骤
    /// @dev 计算在给定价格区间内的交换金额
    /// @param sqrtPriceCurrentX96 当前价格
    /// @param sqrtPriceTargetX96 目标价格
    /// @param liquidity 可用流动性
    /// @param amountRemaining 剩余输入金额
    /// @return sqrtPriceNextX96 交换后的新价格
    /// @return amountIn 实际使用的输入金额
    /// @return amountOut 计算出的输出金额
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountRemaining
    )
        internal
        pure
        returns (
            uint160 sqrtPriceNextX96,
            uint256 amountIn,
            uint256 amountOut
        )
    {
        // 确定交换方向
        bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;

        // 计算交换后的新价格
        sqrtPriceNextX96 = Math.getNextSqrtPriceFromInput(
            sqrtPriceCurrentX96,
            liquidity,
            amountRemaining,
            zeroForOne
        );

        // 确保新价格不会超过目标价格
        if (zeroForOne) {
            if (sqrtPriceNextX96 < sqrtPriceTargetX96) {
                sqrtPriceNextX96 = sqrtPriceTargetX96;
            }
        } else {
            if (sqrtPriceNextX96 > sqrtPriceTargetX96) {
                sqrtPriceNextX96 = sqrtPriceTargetX96;
            }
        }

        // 计算输入和输出金额
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

        // 如果计算出的 amountIn 超过了剩余金额，则调整
        if (amountIn > amountRemaining) {
            amountIn = amountRemaining;
            // 重新计算 amountOut
            if (zeroForOne) {
                sqrtPriceNextX96 = Math.getNextSqrtPriceFromAmount0RoundingUp(
                    sqrtPriceCurrentX96,
                    liquidity,
                    amountIn
                );
                amountOut = Math.calcAmount1Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity
                );
            } else {
                sqrtPriceNextX96 = Math.getNextSqrtPriceFromAmount1RoundingDown(
                    sqrtPriceCurrentX96,
                    liquidity,
                    amountIn
                );
                amountOut = Math.calcAmount0Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity
                );
            }
        }
    }
}
