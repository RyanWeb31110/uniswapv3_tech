// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/lib/LiquidityAmounts.sol";
import "../src/lib/TickMath.sol";

/// @title LiquidityAmounts 测试合约
/// @notice 测试流动性计算库的各种场景
contract LiquidityAmountsTest is Test {

    /// @notice 测试：当前价格在区间下方
    /// @dev 价格低于区间下限时,只需要代币0
    function test_GetLiquidity_PriceBelowRange() public {
        // 设置价格区间：4545 - 5500 USDC/ETH
        int24 lowerTick = 84222;  // 约 4545 USDC/ETH
        int24 upperTick = 86129;  // 约 5500 USDC/ETH

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);

        // 当前价格：4000 USDC/ETH（低于区间下限）
        int24 currentTick = 83000;
        uint160 sqrtPriceCurrent = TickMath.getSqrtRatioAtTick(currentTick);

        // 用户提供：10 ETH + 100,000 USDC
        uint256 amount0 = 10 ether;
        uint256 amount1 = 100_000 * 1e6;  // USDC 有 6 位小数

        // 计算流动性
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        // 由于价格在区间下方,流动性应该只基于 amount0 计算
        uint128 expectedLiquidity = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0
        );

        assertEq(liquidity, expectedLiquidity, "Liquidity should be based on amount0 only");
        assertTrue(liquidity > 0, "Liquidity should be positive");
    }

    /// @notice 测试：当前价格在区间内部
    /// @dev 价格在区间内时,需要两种代币,选择较小的流动性
    function test_GetLiquidity_PriceInRange() public {
        // 设置价格区间：4545 - 5500 USDC/ETH
        int24 lowerTick = 84222;
        int24 upperTick = 86129;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);

        // 当前价格：5000 USDC/ETH（在区间内部）
        int24 currentTick = 85176;
        uint160 sqrtPriceCurrent = TickMath.getSqrtRatioAtTick(currentTick);

        // 用户提供：1 ETH + 5000 USDC
        uint256 amount0 = 1 ether;
        uint256 amount1 = 5000 * 1e6;

        // 计算流动性
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        // 分别计算基于两种代币的流动性
        uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceCurrent,
            sqrtPriceUpper,
            amount0
        );

        uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(
            sqrtPriceLower,
            sqrtPriceCurrent,
            amount1
        );

        // 应该选择较小的流动性
        uint128 expectedLiquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;

        assertEq(liquidity, expectedLiquidity, "Should choose smaller liquidity");
        assertTrue(liquidity > 0, "Liquidity should be positive");
    }

    /// @notice 测试：当前价格在区间上方
    /// @dev 价格高于区间上限时,只需要代币1
    function test_GetLiquidity_PriceAboveRange() public {
        // 设置价格区间：4545 - 5500 USDC/ETH
        int24 lowerTick = 84222;
        int24 upperTick = 86129;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);

        // 当前价格：6000 USDC/ETH（高于区间上限）
        int24 currentTick = 87000;
        uint160 sqrtPriceCurrent = TickMath.getSqrtRatioAtTick(currentTick);

        // 用户提供：10 ETH + 100,000 USDC
        uint256 amount0 = 10 ether;
        uint256 amount1 = 100_000 * 1e6;

        // 计算流动性
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        // 由于价格在区间上方,流动性应该只基于 amount1 计算
        uint128 expectedLiquidity = LiquidityAmounts.getLiquidityForAmount1(
            sqrtPriceLower,
            sqrtPriceUpper,
            amount1
        );

        assertEq(liquidity, expectedLiquidity, "Liquidity should be based on amount1 only");
        assertTrue(liquidity > 0, "Liquidity should be positive");
    }

    /// @notice 测试：基于代币0计算流动性
    /// @dev 验证 getLiquidityForAmount0 的正确性
    function test_GetLiquidityForAmount0() public {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);

        uint256 amount0 = 1 ether;

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0
        );

        assertTrue(liquidity > 0, "Liquidity should be positive");

        // 验证参数顺序无关性
        uint128 liquidityReversed = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceUpper,
            sqrtPriceLower,
            amount0
        );

        assertEq(liquidity, liquidityReversed, "Order should not matter");
    }

    /// @notice 测试：基于代币1计算流动性
    /// @dev 验证 getLiquidityForAmount1 的正确性
    function test_GetLiquidityForAmount1() public {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);

        uint256 amount1 = 5000 * 1e6;

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            sqrtPriceLower,
            sqrtPriceUpper,
            amount1
        );

        assertTrue(liquidity > 0, "Liquidity should be positive");

        // 验证参数顺序无关性
        uint128 liquidityReversed = LiquidityAmounts.getLiquidityForAmount1(
            sqrtPriceUpper,
            sqrtPriceLower,
            amount1
        );

        assertEq(liquidity, liquidityReversed, "Order should not matter");
    }

    /// @notice Fuzzing 测试：随机价格和数量
    /// @dev 使用随机输入验证函数的健壮性
    function testFuzz_GetLiquidity(
        uint88 amount0Seed,
        uint88 amount1Seed,
        uint8 tickSeed
    ) public {
        // 基于种子生成合理的输入值
        uint256 amount0 = uint256(amount0Seed) + 1000;  // 至少 1000
        uint256 amount1 = uint256(amount1Seed) + 1000;  // 至少 1000

        // 固定价格区间
        int24 lowerTick = 84222;
        int24 upperTick = 86129;

        // 基于种子生成 tick,限制在合理范围内
        int24 currentTick = int24(int256(lowerTick - 5000 + (int256(uint256(tickSeed)) * 100)));

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPriceCurrent = TickMath.getSqrtRatioAtTick(currentTick);

        // 计算流动性
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        // 验证不变量
        assertTrue(liquidity >= 0, "Liquidity should be non-negative");
        assertTrue(liquidity > 0, "Liquidity should be positive when tokens are provided");
    }

    /// @notice 测试：零数量输入
    /// @dev 验证零输入的处理
    function test_GetLiquidity_ZeroAmounts() public {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        int24 currentTick = 85176;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPriceCurrent = TickMath.getSqrtRatioAtTick(currentTick);

        // 两种代币都为0
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            0,
            0
        );

        assertEq(liquidity, 0, "Liquidity should be zero when both amounts are zero");
    }

    /// @notice 测试：价格接近区间边界
    /// @dev 验证价格接近但不等于边界时的情况
    function test_GetLiquidity_NearBoundaryPrices() public {
        int24 lowerTick = 84000;
        int24 upperTick = 86000;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);

        uint256 amount0 = 1 ether;
        uint256 amount1 = 5000 * 1e6;

        // 当前价格略低于下限 - 只需要 token0
        int24 belowLowerTick = lowerTick - 100;
        uint160 sqrtPriceBelowLower = TickMath.getSqrtRatioAtTick(belowLowerTick);

        uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceBelowLower,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        assertTrue(liquidity1 > 0, "Should handle current price below lower bound");

        // 当前价格略高于上限 - 只需要 token1
        int24 aboveUpperTick = upperTick + 100;
        uint160 sqrtPriceAboveUpper = TickMath.getSqrtRatioAtTick(aboveUpperTick);

        uint128 liquidity2 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceAboveUpper,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        assertTrue(liquidity2 > 0, "Should handle current price above upper bound");

        // 当前价格在区间中间
        int24 middleTick = (lowerTick + upperTick) / 2;
        uint160 sqrtPriceMiddle = TickMath.getSqrtRatioAtTick(middleTick);

        uint128 liquidity3 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceMiddle,
            sqrtPriceLower,
            sqrtPriceUpper,
            amount0,
            amount1
        );

        assertTrue(liquidity3 > 0, "Should handle current price in middle of range");
    }

    /// @notice 测试：不同数量比例
    /// @dev 验证选择较小流动性的逻辑
    function test_GetLiquidity_DifferentRatios() public {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        int24 currentTick = 85176;

        uint160 sqrtPriceLower = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtRatioAtTick(upperTick);
        uint160 sqrtPriceCurrent = TickMath.getSqrtRatioAtTick(currentTick);

        // 场景1：amount0 多，amount1 少
        uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            100 ether,
            1000 * 1e6
        );

        // 场景2：amount0 少，amount1 多
        uint128 liquidity2 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceCurrent,
            sqrtPriceLower,
            sqrtPriceUpper,
            0.1 ether,
            100_000 * 1e6
        );

        // 两种场景应该都能正常计算
        assertTrue(liquidity1 > 0, "Should handle high amount0 ratio");
        assertTrue(liquidity2 > 0, "Should handle high amount1 ratio");

        // 不同比例应该产生不同的流动性
        assertTrue(liquidity1 != liquidity2, "Different ratios should produce different liquidity");
    }
}
