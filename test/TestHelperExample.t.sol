// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import {TestHelper} from "./TestHelper.sol";

/// @title TestHelper 实际应用示例
/// @notice 展示如何在实际测试中使用 TestHelper 提高代码可读性
contract TestHelperExampleTest is Test {

    /// @notice 示例 1：使用 TestHelper 获取 Tick 值
    function testTickConversion() public pure {
        // ✅ 使用 TestHelper - 清晰表达价格范围
        int24 lowerTick = TestHelper.tick(4500); // 下限价格：4500
        int24 upperTick = TestHelper.tick(5500); // 上限价格：5500

        console.log("Lower Tick (price 4500):", uint256(uint24(lowerTick)));
        console.log("Upper Tick (price 5500):", uint256(uint24(upperTick)));

        // 验证 Tick 顺序正确
        assertTrue(lowerTick < upperTick, "Lower tick should be less than upper tick");
    }

    /// @notice 示例 2：测试带小数的价格
    function testDecimalPrices() public pure {
        // 测试价格：0.5（1 token0 = 0.5 token1）
        uint160 sqrtPrice_0_5 = TestHelper.sqrtPWithDecimals(1, 2);
        console.log("sqrtPrice for 0.5:", sqrtPrice_0_5);

        // 测试价格：1.5
        uint160 sqrtPrice_1_5 = TestHelper.sqrtPWithDecimals(3, 2);
        console.log("sqrtPrice for 1.5:", sqrtPrice_1_5);

        // 测试价格：3.14159（近似 π）
        uint160 sqrtPrice_pi = TestHelper.sqrtPWithDecimals(314159, 100000);
        console.log("sqrtPrice for ~pi:", sqrtPrice_pi);

        // 验证价格顺序正确
        assertTrue(sqrtPrice_0_5 < sqrtPrice_1_5);
        assertTrue(sqrtPrice_1_5 < sqrtPrice_pi);
    }

    /// @notice 示例 3：测试多个价格区间
    function testMultiplePriceRanges() public pure {
        // ✅ 使用 TestHelper 创建多个清晰的价格区间
        // 区间 1: 4000-4500
        int24 range1Lower = TestHelper.tick(4000);
        int24 range1Upper = TestHelper.tick(4500);

        // 区间 2: 4500-5000
        int24 range2Lower = TestHelper.tick(4500);
        int24 range2Upper = TestHelper.tick(5000);

        // 区间 3: 5000-5500
        int24 range3Lower = TestHelper.tick(5000);
        int24 range3Upper = TestHelper.tick(5500);

        // 区间 4: 5500-6000
        int24 range4Lower = TestHelper.tick(5500);
        int24 range4Upper = TestHelper.tick(6000);

        console.log("Range 1:", uint256(uint24(range1Lower)), "-", uint256(uint24(range1Upper)));
        console.log("Range 2:", uint256(uint24(range2Lower)), "-", uint256(uint24(range2Upper)));
        console.log("Range 3:", uint256(uint24(range3Lower)), "-", uint256(uint24(range3Upper)));
        console.log("Range 4:", uint256(uint24(range4Lower)), "-", uint256(uint24(range4Upper)));

        // 验证区间连续性
        assertEq(range1Upper, range2Lower, "Range 1 and 2 should be continuous");
        assertEq(range2Upper, range3Lower, "Range 2 and 3 should be continuous");
        assertEq(range3Upper, range4Lower, "Range 3 and 4 should be continuous");
    }

    /// @notice 示例 4：格式转换测试
    function testFormatConversions() public pure {
        uint256 price = 5000;

        // Q64.96 格式
        uint256 q96 = TestHelper.toQ96(price);
        console.log("5000 in Q96:", q96);

        // Q64.64 格式
        uint256 q64 = TestHelper.toQ64(price);
        console.log("5000 in Q64:", q64);

        // 格式转换
        uint256 q96FromQ64 = TestHelper.q64ToQ96(q64);
        console.log("Q64 to Q96:", q96FromQ64);

        // 验证转换正确性
        uint256 recovered = TestHelper.fromQ96(q96);
        assertEq(recovered, price, "Format conversion should be reversible");
    }

    /// @notice 示例 5：价格比较
    function testPriceComparison() public pure {
        // ✅ 使用 TestHelper 验证价格关系
        uint160 price4500 = TestHelper.sqrtP(4500);
        uint160 price5000 = TestHelper.sqrtP(5000);
        uint160 price5500 = TestHelper.sqrtP(5500);

        console.log("sqrtPrice for 4500:", price4500);
        console.log("sqrtPrice for 5000:", price5000);
        console.log("sqrtPrice for 5500:", price5500);

        // 验证价格顺序
        assertTrue(price4500 < price5000, "Price 4500 should be less than 5000");
        assertTrue(price5000 < price5500, "Price 5000 should be less than 5500");
    }

    /// @notice 示例 6：边界条件测试
    function testBoundaryConditions() public view {
        // 测试极小价格
        uint160 minPrice = TestHelper.sqrtP(1);
        console.log("Min price (1):", minPrice);

        // 测试极大价格
        uint160 maxPrice = TestHelper.sqrtP(100000);
        console.log("Max price (100000):", maxPrice);

        // 测试小数价格
        uint160 fractionalPrice = TestHelper.sqrtPWithDecimals(1, 10); // 0.1
        console.log("Fractional price (0.1):", fractionalPrice);

        // 验证价格顺序
        assertTrue(fractionalPrice < minPrice);
        assertTrue(minPrice < maxPrice);
    }

    /// @notice 示例 7：对比硬编码 vs TestHelper
    function testCompareApproaches() public pure {
        // ❌ 硬编码方式 - 难以理解，容易出错
        uint160 hardcodedSqrtPrice = 5602277097478614198912276234240;
        int24 hardcodedTick = 85176;

        // ✅ 使用 TestHelper - 清晰、易维护
        uint160 helperSqrtPrice = TestHelper.sqrtP(5000);
        int24 helperTick = TestHelper.tick(5000);

        console.log("Hardcoded sqrtPrice:", hardcodedSqrtPrice);
        console.log("Helper sqrtPrice:", helperSqrtPrice);
        console.log("Hardcoded tick:", uint256(uint24(hardcodedTick)));
        console.log("Helper tick:", uint256(uint24(helperTick)));

        // 两种方式应该产生相似的结果
        // 注意：由于 TickMath 的简化实现，可能有一定误差
        assertApproxEqAbs(
            helperSqrtPrice,
            hardcodedSqrtPrice,
            hardcodedSqrtPrice / 100, // 1% 容差
            "Helper should produce similar results to hardcoded"
        );
    }

}
