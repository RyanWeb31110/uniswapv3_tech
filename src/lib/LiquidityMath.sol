// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";

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

    /// @notice 添加流动性变化量
    /// @dev 处理流动性的增减变化
    /// @param x 现有流动性
    /// @param y 流动性变化量
    /// @return z 变化后的流动性
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            // 如果 y 是负数，相当于减去流动性
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            // 如果 y 是正数，直接添加流动性
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }

    /// @notice 根据代币数量计算流动性
    /// @dev 基于价格区间和期望投入的代币数量，反推流动性值
    /// @param sqrtPriceX96 当前平方根价格（Q64.96 格式）
    /// @param sqrtPriceAX96 价格区间下界的平方根价格
    /// @param sqrtPriceBX96 价格区间上界的平方根价格
    /// @param amount0 期望投入的 token0 数量
    /// @param amount1 期望投入的 token1 数量
    /// @return liquidity 计算得出的流动性
    function getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        // 确保价格 A < 价格 B
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        if (sqrtPriceX96 <= sqrtPriceAX96) {
            // 当前价格在区间下方，只需要 token0
            liquidity = getLiquidityForAmount0(sqrtPriceAX96, sqrtPriceBX96, amount0);
        } else if (sqrtPriceX96 < sqrtPriceBX96) {
            // 当前价格在区间内，需要两种代币
            // 在当前价格下，添加流动性需要按特定比例投入两种代币。
            // 但用户提供的 amount0Desired 和 amount1Desired 可能不是这个完美比例
            uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtPriceBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceX96, amount1);

            // 取较小值，确保两种代币都足够
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            // 当前价格在区间上方，只需要 token1
            liquidity = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceBX96, amount1);
        }
    }

    /// @notice 根据 token0 数量计算流动性
    /// @dev 公式：L = (Δx × √P_u × √P_l) / (√P_u - √P_l)
    /// @param sqrtPriceAX96 价格区间的一个端点
    /// @param sqrtPriceBX96 价格区间的另一个端点
    /// @param amount0 token0 的数量
    /// @return liquidity 计算得出的流动性
    function getLiquidityForAmount0(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        // 确保 A < B
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        uint256 intermediate = (uint256(sqrtPriceAX96) * uint256(sqrtPriceBX96)) / FixedPoint96.Q96;
        liquidity = uint128((amount0 * intermediate) / (sqrtPriceBX96 - sqrtPriceAX96));
    }

    /// @notice 根据 token1 数量计算流动性
    /// @dev 公式：L = Δy / (√P_u - √P_l)
    /// @param sqrtPriceAX96 价格区间的一个端点
    /// @param sqrtPriceBX96 价格区间的另一个端点
    /// @param amount1 token1 的数量
    /// @return liquidity 计算得出的流动性
    function getLiquidityForAmount1(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        // 确保 A < B
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        liquidity = uint128((amount1 * FixedPoint96.Q96) / (sqrtPriceBX96 - sqrtPriceAX96));
    }
}
