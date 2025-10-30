// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import {TickMath} from "../src/lib/TickMath.sol";
import {FixedPoint96} from "../src/lib/FixedPoint96.sol";
import {UniswapV3Factory} from "../src/UniswapV3Factory.sol";
import {UniswapV3Pool} from "../src/UniswapV3Pool.sol";

/// @title 测试辅助函数库
/// @notice 提供价格和 Tick 之间的转换工具
/// @dev 用于测试代码，提高可读性和可维护性
library TestHelper {
    /// @notice 将价格转换为 Tick 值
    /// @dev 假设价格没有小数部分
    /// @param price 价格值（例如：5000 表示 1 token0 = 5000 token1）
    /// @return tick_ 对应的 Tick 索引
    function tick(uint256 price) internal pure returns (int24 tick_) {
        tick_ = TickMath.getTickAtSqrtRatio(
            uint160(
                int160(
                    // 步骤 1: 将价格转换为 Q64.64 格式并计算平方根
                    ABDKMath64x64.sqrt(int128(int256(price << 64))) <<
                        // 步骤 2: 将 Q64.64 转换为 Q64.96 格式
                        (FixedPoint96.RESOLUTION - 64)
                )
            )
        );
    }

    /// @notice 将价格转换为 sqrtPriceX96 格式
    /// @param price 价格值
    /// @return 对应的 sqrtPriceX96 值
    function sqrtP(uint256 price) internal pure returns (uint160) {
        return uint160(
            int160(
                ABDKMath64x64.sqrt(int128(int256(price << 64))) <<
                    (FixedPoint96.RESOLUTION - 64)
            )
        );
    }

    /// @notice 将带小数的价格转换为 Tick
    /// @param priceNumerator 价格分子（例如：42.1337 表示为 421337）
    /// @param priceDenominator 价格分母（例如：42.1337 的分母为 10000）
    /// @return tick_ 对应的 Tick 索引
    function tickWithDecimals(
        uint256 priceNumerator,
        uint256 priceDenominator
    ) internal pure returns (int24 tick_) {
        // 计算 (priceNumerator / priceDenominator) 的 Q64.64 表示
        int128 priceQ64x64 = ABDKMath64x64.divu(
            priceNumerator,
            priceDenominator
        );

        // 计算平方根并转换为 Q64.96
        tick_ = TickMath.getTickAtSqrtRatio(
            uint160(
                int160(
                    ABDKMath64x64.sqrt(priceQ64x64) <<
                        (FixedPoint96.RESOLUTION - 64)
                )
            )
        );
    }

    /// @notice 将带小数的价格转换为 sqrtPriceX96
    /// @param priceNumerator 价格分子
    /// @param priceDenominator 价格分母
    /// @return 对应的 sqrtPriceX96 值
    function sqrtPWithDecimals(
        uint256 priceNumerator,
        uint256 priceDenominator
    ) internal pure returns (uint160) {
        // 计算 (priceNumerator / priceDenominator) 的 Q64.64 表示
        int128 priceQ64x64 = ABDKMath64x64.divu(
            priceNumerator,
            priceDenominator
        );

        // 计算平方根并转换为 Q64.96
        return uint160(
            int160(
                ABDKMath64x64.sqrt(priceQ64x64) <<
                    (FixedPoint96.RESOLUTION - 64)
            )
        );
    }

    /// @notice 将整数转换为 Q64.96 格式
    /// @param value 整数值
    /// @return 对应的 Q64.96 格式值
    function toQ96(uint256 value) internal pure returns (uint256) {
        return value << 96;
    }

    /// @notice 将 Q64.96 格式转换为整数（向下取整）
    /// @param valueQ96 Q64.96 格式的值
    /// @return 对应的整数值
    function fromQ96(uint256 valueQ96) internal pure returns (uint256) {
        return valueQ96 >> 96;
    }

    /// @notice 将整数转换为 Q64.64 格式
    /// @param value 整数值
    /// @return 对应的 Q64.64 格式值
    function toQ64(uint256 value) internal pure returns (uint256) {
        return value << 64;
    }

    /// @notice 将 Q64.64 格式转换为整数（向下取整）
    /// @param valueQ64 Q64.64 格式的值
    /// @return 对应的整数值
    function fromQ64(uint256 valueQ64) internal pure returns (uint256) {
        return valueQ64 >> 64;
    }

    /// @notice 将 Q64.64 转换为 Q64.96
    /// @param valueQ64 Q64.64 格式的值
    /// @return 对应的 Q64.96 格式值
    function q64ToQ96(uint256 valueQ64) internal pure returns (uint256) {
        return valueQ64 << (96 - 64); // 左移 32 位
    }

    /// @notice 将 Q64.96 转换为 Q64.64
    /// @param valueQ96 Q64.96 格式的值
    /// @return 对应的 Q64.64 格式值
    function q96ToQ64(uint256 valueQ96) internal pure returns (uint256) {
        return valueQ96 >> (96 - 64); // 右移 32 位
    }

    /// @notice 创建并初始化一个新的池子
    /// @param factory Factory 合约地址
    /// @param token0 代币0地址（必须 < token1）
    /// @param token1 代币1地址
    /// @param tickSpacing Tick 间距
    /// @param sqrtPriceX96 初始价格
    /// @return pool 创建的池子合约
    function createAndInitializePool(
        UniswapV3Factory factory,
        address token0,
        address token1,
        uint24 tickSpacing,
        uint160 sqrtPriceX96
    ) internal returns (UniswapV3Pool pool) {
        // 创建池子
        address poolAddress = factory.createPool(token0, token1, tickSpacing);
        pool = UniswapV3Pool(poolAddress);

        // 初始化池子
        pool.initialize(sqrtPriceX96);
    }
}
