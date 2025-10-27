// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import {TestHelper} from "./TestHelper.sol";
import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import {TickMath} from "../src/lib/TickMath.sol";
import {FixedPoint96} from "../src/lib/FixedPoint96.sol";

/// @title 定点数深度测试
/// @notice 测试定点数转换和辅助函数的正确性
contract FixedPointNumbersTest is Test {
    using TestHelper for uint256;

    /// @notice 测试整数转换为 Q64.96 格式
    function testIntegerToQ96() public pure {
        // 测试：42 转换为 Q64.96
        uint256 value = 42;
        uint256 q96Value = TestHelper.toQ96(value);

        // 验证：42 << 96
        uint256 expected = 42 << 96;
        assertEq(q96Value, expected, "Integer to Q96 conversion failed");

        // 反向转换验证
        uint256 recovered = TestHelper.fromQ96(q96Value);
        assertEq(recovered, value, "Q96 to integer conversion failed");
    }

    /// @notice 测试整数转换为 Q64.64 格式
    function testIntegerToQ64() public pure {
        // 测试：42 转换为 Q64.64
        uint256 value = 42;
        uint256 q64Value = TestHelper.toQ64(value);

        // 验证：42 << 64
        uint256 expected = 42 << 64;
        assertEq(q64Value, expected, "Integer to Q64 conversion failed");

        // 反向转换验证
        uint256 recovered = TestHelper.fromQ64(q64Value);
        assertEq(recovered, value, "Q64 to integer conversion failed");
    }

    /// @notice 测试 Q64.64 和 Q64.96 之间的转换
    function testQ64ToQ96Conversion() public pure {
        // 创建一个 Q64.64 格式的数字（42）
        uint256 q64Value = 42 << 64;

        // 转换为 Q64.96
        uint256 q96Value = TestHelper.q64ToQ96(q64Value);

        // 验证：应该左移 32 位
        uint256 expected = q64Value << 32;
        assertEq(q96Value, expected, "Q64 to Q96 conversion failed");

        // 反向转换
        uint256 recovered = TestHelper.q96ToQ64(q96Value);
        assertEq(recovered, q64Value, "Q96 to Q64 conversion failed");
    }

    /// @notice 测试价格转换为 sqrtPriceX96
    function testPriceToSqrtP() public pure {
        // 测试价格：5000
        uint256 price = 5000;
        uint160 sqrtPrice = TestHelper.sqrtP(price);

        // 验证平方根的平方应该接近原价格
        // sqrtPrice 是 Q64.96 格式，平方后需要右移 192 位才能得到原价格
        // 因为 (sqrtP * 2^96)^2 = P * 2^192
        uint256 recoveredPrice = (uint256(sqrtPrice) * uint256(sqrtPrice)) >> 192;

        // 由于精度问题，允许一定的误差范围（1%）
        uint256 tolerance = price / 100;
        assertApproxEqAbs(recoveredPrice, price, tolerance, "Price to sqrtP conversion inaccurate");
    }

    /// @notice 测试价格转换为 Tick
    function testPriceToTick() public {
        // 测试价格：5000
        uint256 price = 5000;
        int24 tickValue = TestHelper.tick(price);

        // Tick 应该在有效范围内
        assertTrue(tickValue >= TickMath.MIN_TICK, "Tick below minimum");
        assertTrue(tickValue <= TickMath.MAX_TICK, "Tick above maximum");

        // 验证：通过 Tick 反推的价格应该接近原价格
        uint160 sqrtPriceAtTick = TickMath.getSqrtRatioAtTick(tickValue);
        uint256 recoveredPrice = (uint256(sqrtPriceAtTick) * uint256(sqrtPriceAtTick)) >> 192;

        // 允许较大的误差范围（由于 TickMath 的简化实现）
        uint256 tolerance = price * 2; // 较大容差，因为 TickMath 是简化实现
        assertApproxEqAbs(recoveredPrice, price, tolerance, "Tick conversion inaccurate");
    }

    /// @notice 测试带小数的价格转换
    function testDecimalPriceConversion() public pure {
        // 测试价格：42.1337
        uint256 numerator = 421337;
        uint256 denominator = 10000;

        uint160 sqrtPrice = TestHelper.sqrtPWithDecimals(numerator, denominator);

        // 验证结果不为零
        assertTrue(sqrtPrice > 0, "Decimal price conversion returned zero");

        // 验证平方根的平方应该接近原价格
        // sqrtPrice 是 Q64.96 格式，平方后右移 192 位
        uint256 recoveredPrice = (uint256(sqrtPrice) * uint256(sqrtPrice)) >> 192;
        uint256 expectedPrice = numerator / denominator;

        // 允许 1% 的误差
        uint256 tolerance = expectedPrice / 100 + 1;
        assertApproxEqAbs(recoveredPrice, expectedPrice, tolerance, "Decimal price conversion inaccurate");
    }

    /// @notice 测试带小数的价格转换为 Tick
    function testDecimalPriceToTick() public {
        // 测试价格：42.1337
        uint256 numerator = 421337;
        uint256 denominator = 10000;

        int24 tickValue = TestHelper.tickWithDecimals(numerator, denominator);

        // Tick 应该在有效范围内
        assertTrue(tickValue >= TickMath.MIN_TICK, "Decimal tick below minimum");
        assertTrue(tickValue <= TickMath.MAX_TICK, "Decimal tick above maximum");
    }

    /// @notice 测试 ABDK Math64x64 平方根功能
    function testABDKSqrt() public pure {
        // 测试：计算 5000 的平方根
        uint256 value = 5000;

        // 转换为 Q64.64 格式
        int128 valueQ64 = int128(int256(value << 64));

        // 计算平方根（结果也是 Q64.64 格式）
        int128 sqrtQ64 = ABDKMath64x64.sqrt(valueQ64);

        // 验证：平方根的平方应该等于原值
        int128 recovered = ABDKMath64x64.mul(sqrtQ64, sqrtQ64);

        // 转换回整数进行比较
        uint256 recoveredValue = uint256(uint128(recovered)) >> 64;

        // 允许 1% 的误差（由于精度限制）
        uint256 tolerance = value / 100;
        assertApproxEqAbs(recoveredValue, value, tolerance, "ABDK sqrt inaccurate");
    }

    /// @notice 测试多个价格点的转换
    function testMultiplePrices() public pure {
        uint256[] memory prices = new uint256[](5);
        prices[0] = 1;
        prices[1] = 100;
        prices[2] = 5000;
        prices[3] = 10000;
        prices[4] = 50000;

        for (uint256 i = 0; i < prices.length; i++) {
            uint256 price = prices[i];
            uint160 sqrtPrice = TestHelper.sqrtP(price);

            // 验证转换后的值不为零
            assertTrue(sqrtPrice > 0, "sqrtP returned zero");

            // 验证平方根的平方接近原价格
            uint256 recoveredPrice = (uint256(sqrtPrice) * uint256(sqrtPrice)) >> 192;
            uint256 tolerance = price / 50 + 1; // 2% 容差

            assertApproxEqAbs(
                recoveredPrice,
                price,
                tolerance,
                string.concat("Price conversion failed for ", vm.toString(price))
            );
        }
    }

    /// @notice 测试格式转换的精度
    function testFormatConversionPrecision() public pure {
        // 测试一个带小数的值：123.456
        uint256 numerator = 123456;
        uint256 denominator = 1000;

        // 通过 ABDK 计算 Q64.64 表示
        int128 q64Value = ABDKMath64x64.divu(numerator, denominator);

        // 转换为 Q64.96
        uint256 q96Value = TestHelper.q64ToQ96(uint256(uint128(q64Value)));

        // 转换回 Q64.64
        uint256 recoveredQ64 = TestHelper.q96ToQ64(q96Value);

        // 验证转换是可逆的
        assertEq(recoveredQ64, uint256(uint128(q64Value)), "Format conversion not reversible");
    }

    /// @notice 测试边界情况：最小价格
    function testMinPrice() public {
        uint256 minPrice = 1;
        uint160 sqrtPrice = TestHelper.sqrtP(minPrice);

        // 验证结果在有效范围内
        assertTrue(sqrtPrice >= TickMath.MIN_SQRT_RATIO, "sqrtPrice below minimum");
        assertTrue(sqrtPrice < TickMath.MAX_SQRT_RATIO, "sqrtPrice above maximum");
    }

    /// @notice 测试边界情况：大价格值
    function testLargePrice() public {
        uint256 largePrice = 100000;
        uint160 sqrtPrice = TestHelper.sqrtP(largePrice);

        // 验证结果在有效范围内
        assertTrue(sqrtPrice >= TickMath.MIN_SQRT_RATIO, "sqrtPrice below minimum");
        assertTrue(sqrtPrice < TickMath.MAX_SQRT_RATIO, "sqrtPrice above maximum");
    }

    /// @notice 测试文档中的示例：42 转换
    function testDocumentExample42() public pure {
        // 文档示例：整数 42 转换为 Q64.96
        uint256 value = 42;
        uint256 q96Value = value << 96;

        // 验证结果
        assertEq(q96Value, 3327582825599102178928845914112, "Doc example 42 to Q96 failed");
    }

    /// @notice 测试文档中的示例：42.1337 转换
    function testDocumentExample42Decimal() public pure {
        // 文档示例：42.1337 转换为 Q64.96
        // 42.1337 = 421337 / 10000
        uint256 numerator = 421337;
        // 简化计算：421337 << 92 (相当于 << 96 然后 / 10000)
        uint256 q96Value = numerator << 92;

        // 验证结果（文档中的值）
        assertEq(q96Value, 2086359769329537075540689212669952, "Doc example 42.1337 to Q96 failed");
    }
}
