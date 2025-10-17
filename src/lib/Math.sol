// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";

/// @title Math 数学计算库
/// @notice 提供集中流动性相关的数学计算函数
/// @dev 基于 Uniswap V3 的数学库实现
library Math {
    // ============ 常量 ============
    
    /// @notice 2^96，用于 Q64.96 格式转换
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    // ============ 错误定义 ============
    
    error DivisionByZero();
    error Overflow();

    // ============ 数学计算函数 ============

    /// @notice 计算在给定价格区间内提供流动性所需的 Token0 数量
    /// @dev 基于集中流动性公式：Δx = L × (√P_u - √P_c) / (√P_u × √P_c)
    /// @param sqrtPriceAX96 价格区间的一个端点（Q64.96 格式）
    /// @param sqrtPriceBX96 价格区间的另一个端点（Q64.96 格式）
    /// @param liquidity 流动性数量
    /// @return amount0 所需的 Token0 数量
    function calcAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        // 确保价格按升序排列，避免减法下溢
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        // 确保价格不为零
        if (sqrtPriceAX96 == 0) revert DivisionByZero();

        // 计算 Token0 数量
        // 将流动性转换为 Q96.64 格式（乘以 2^96）
        // 然后按照公式进行两次除法以避免溢出
        amount0 = divRoundingUp(
            mulDivRoundingUp(
                (uint256(liquidity) << FixedPoint96.RESOLUTION),
                (sqrtPriceBX96 - sqrtPriceAX96),
                sqrtPriceBX96
            ),
            sqrtPriceAX96
        );
    }

    /// @notice 计算在给定价格区间内提供流动性所需的 Token1 数量
    /// @dev 基于集中流动性公式：Δy = L × (√P_c - √P_l)
    /// @param sqrtPriceAX96 价格区间的一个端点（Q64.96 格式）
    /// @param sqrtPriceBX96 价格区间的另一个端点（Q64.96 格式）
    /// @param liquidity 流动性数量
    /// @return amount1 所需的 Token1 数量
    function calcAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        // 确保价格按升序排列
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        // 计算 Token1 数量
        // 公式：Δy = L × (√P_u - √P_l) / 2^96
        amount1 = mulDivRoundingUp(
            liquidity,
            (sqrtPriceBX96 - sqrtPriceAX96),
            FixedPoint96.Q96
        );
    }

    // ============ 辅助数学函数 ============

    /// @notice 执行乘除运算并向上取整
    /// @dev 基于 PRBMath.mulDiv，但结果向上取整
    /// @param a 被乘数
    /// @param b 乘数
    /// @param denominator 除数
    /// @return result 向上取整的结果
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 先执行标准的乘除运算
        result = mulDiv(a, b, denominator);
        
        // 检查是否有余数，如果有则向上取整
        if (mulmod(a, b, denominator) > 0) {
            if (result == type(uint256).max) revert Overflow();
            result++;
        }
    }

    /// @notice 执行除法运算并向上取整
    /// @param a 被除数
    /// @param b 除数
    /// @return result 向上取整的结果
    function divRoundingUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = a / b;
        if (a % b > 0) {
            if (result == type(uint256).max) revert Overflow();
            result++;
        }
    }

    /// @notice 执行乘除运算，避免中间结果溢出
    /// @dev 使用 unchecked 块来处理溢出
    /// @param a 被乘数
    /// @param b 乘数
    /// @param denominator 除数
    /// @return result 乘除运算的结果
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 使用 unchecked 块来处理溢出
        // 在大多数情况下，这种实现是安全的
        unchecked {
            result = (a * b) / denominator;
        }
    }

    // ============ 价格计算函数 ============

    /// @notice 根据输入金额计算新的价格
    /// @dev 实现价格与交换金额的数学关系
    /// @param sqrtPriceX96 当前价格
    /// @param liquidity 可用流动性
    /// @param amountIn 输入金额
    /// @param zeroForOne 交换方向
    /// @return sqrtPriceNextX96 交换后的新价格
    function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        sqrtPriceNextX96 = zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96,
                liquidity,
                amountIn
            )
            : getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96,
                liquidity,
                amountIn
            );
    }

    /// @notice 根据 Token0 输入金额计算新价格
    /// @dev 实现公式：P_target = (L * √P) / (L + Δx * √P)
    /// @param sqrtPriceX96 当前价格
    /// @param liquidity 可用流动性
    /// @param amountIn Token0 输入金额
    /// @return 新的价格
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        // 根据 Uniswap V3 公式：P_target = (L * √P) / (L + Δx * √P)
        // 当用 token0 换取 token1 时，价格应该上升
        uint256 numerator = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 product = amountIn * sqrtPriceX96;

        // 检查是否会发生溢出
        if (product / amountIn == sqrtPriceX96) {
            uint256 denominator = numerator + product;
            if (denominator >= numerator) {
                return uint160(
                    mulDivRoundingUp(numerator, sqrtPriceX96, denominator)
                );
            }
        }

        // 使用替代公式避免溢出
        return uint160(
            divRoundingUp(numerator, (numerator / sqrtPriceX96) + amountIn)
        );
    }

    /// @notice 根据 Token1 输入金额计算新价格
    /// @dev 实现公式：P_target = √P + (Δy * 2^96) / L
    /// @param sqrtPriceX96 当前价格
    /// @param liquidity 可用流动性
    /// @param amountIn Token1 输入金额
    /// @return 新的价格
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        return sqrtPriceX96 + 
            uint160((amountIn << FixedPoint96.RESOLUTION) / liquidity);
    }
}
