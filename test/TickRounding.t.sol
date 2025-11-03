// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./TestHelper.sol";
import {TickMath} from "../src/lib/TickMath.sol";

/// @title Tick 舍入功能测试
/// @notice 测试 nearestUsableTick 和 divRound 函数的正确性
contract TickRoundingTest is Test {
    using TestHelper for *;

    function setUp() public {}

    /// @notice 测试 divRound 函数 - 整除情况
    function test_divRound_Exact() public {
        // 1422 / 1 = 1422 (整除)
        int128 x = int128(1422) << 64; // 转换为 Q64.64
        int128 y = int128(1) << 64;
        int128 result = TestHelper.divRound(x, y);

        assertEq(result, 1422, "Result should equal 1422 for exact division");
    }

    /// @notice 测试 divRound 函数 - 向下舍入
    function test_divRound_RoundDown() public {
        // 85320 / 60 = 1422 (整除)
        int128 x = int128(85320) << 64;
        int128 y = int128(60) << 64;
        int128 result = TestHelper.divRound(x, y);

        assertEq(result, 1422, "85320 / 60 should equal 1422");
    }

    /// @notice 测试 divRound 函数 - 向上舍入
    function test_divRound_RoundUp() public {
        // 85350 / 60 = 1422.5，应该向上舍入到 1423
        int128 x = int128(85350) << 64;
        int128 y = int128(60) << 64;
        int128 result = TestHelper.divRound(x, y);

        assertEq(result, 1423, "85350 / 60 = 1422.5 should round up to 1423");
    }

    /// @notice 测试 nearestUsableTick - tick 恰好是 spacing 的倍数
    function test_nearestUsableTick_ExactMultiple() public {
        uint24 tickSpacing = 60;
        int24 tick = 85320;

        int24 rounded = TestHelper.nearestUsableTick(tick, tickSpacing);

        assertEq(rounded, 85320, "Exact multiple tick should not change");
        assertEq(rounded % int24(tickSpacing), 0, "Result must be multiple of spacing");
    }

    /// @notice 测试 nearestUsableTick - 向上舍入
    function test_nearestUsableTick_RoundUp() public {
        uint24 tickSpacing = 60;
        int24 tick = 85350; // 85350 / 60 = 1422.5

        int24 rounded = TestHelper.nearestUsableTick(tick, tickSpacing);

        // 1422.5 向上舍入到 1423，1423 * 60 = 85380
        assertEq(rounded, 85380, "85350 should round up to 85380");
        assertEq(rounded % int24(tickSpacing), 0, "Result must be multiple of spacing");
    }

    /// @notice 测试 nearestUsableTick - 向下舍入
    function test_nearestUsableTick_RoundDown() public {
        uint24 tickSpacing = 60;
        int24 tick = 85310; // 85310 / 60 = 1421.833...

        int24 rounded = TestHelper.nearestUsableTick(tick, tickSpacing);

        // 1421.833 向下舍入到 1422，1422 * 60 = 85320
        assertEq(rounded, 85320, "85310 should round down to 85320");
        assertEq(rounded % int24(tickSpacing), 0, "Result must be multiple of spacing");
    }

    /// @notice 测试 nearestUsableTick - 负数 tick
    function test_nearestUsableTick_Negative() public {
        uint24 tickSpacing = 60;
        int24 tick = -85350;

        int24 rounded = TestHelper.nearestUsableTick(tick, tickSpacing);

        // -85350 / 60 = -1422.5，向上舍入到 -1422，-1422 * 60 = -85320
        assertEq(rounded, -85320, "Negative number should round correctly");
        assertEq(rounded % int24(tickSpacing), 0, "Result must be multiple of spacing");
    }

    /// @notice 测试 nearestUsableTick - 不同的 tick spacing
    function test_nearestUsableTick_DifferentSpacings() public {
        int24 tick = 1000;

        // spacing = 10
        int24 rounded10 = TestHelper.nearestUsableTick(tick, 10);
        assertEq(rounded10, 1000, "tick spacing 10");

        // spacing = 60
        int24 rounded60 = TestHelper.nearestUsableTick(tick, 60);
        assertEq(rounded60, 1020, "tick spacing 60: 1000/60=16.67 -> 17*60=1020");

        // spacing = 200
        int24 rounded200 = TestHelper.nearestUsableTick(tick, 200);
        assertEq(rounded200, 1000, "tick spacing 200: 1000/200=5 -> 5*200=1000");
    }

    /// @notice 测试 nearestUsableTick - 边界情况
    function test_nearestUsableTick_BoundaryCheck() public {
        uint24 tickSpacing = 60;

        // 测试接近 MAX_TICK 的情况
        int24 nearMax = TickMath.MAX_TICK - 10;
        int24 roundedMax = TestHelper.nearestUsableTick(nearMax, tickSpacing);

        assertTrue(roundedMax <= TickMath.MAX_TICK, "Cannot exceed MAX_TICK after rounding");
        assertEq(roundedMax % int24(tickSpacing), 0, "Result must be multiple of spacing");

        // 测试接近 MIN_TICK 的情况
        int24 nearMin = TickMath.MIN_TICK + 10;
        int24 roundedMin = TestHelper.nearestUsableTick(nearMin, tickSpacing);

        assertTrue(roundedMin >= TickMath.MIN_TICK, "Cannot be less than MIN_TICK after rounding");
        assertEq(roundedMin % int24(tickSpacing), 0, "Result must be multiple of spacing");
    }

    /// @notice 测试 sqrtPRounded - 价格舍入
    function test_sqrtPRounded_BasicFunction() public {
        uint256 price = 5000; // 1 ETH = 5000 USDC
        uint24 tickSpacing = 60;

        uint160 sqrtPriceRounded = TestHelper.sqrtPRounded(price, tickSpacing);

        // 验证结果大于 0
        assertTrue(sqrtPriceRounded > 0, "Rounded price should be greater than 0");

        // 验证对应的 tick 是 spacing 的倍数
        int24 tickValue = TickMath.getTickAtSqrtRatio(sqrtPriceRounded);
        assertEq(tickValue % int24(tickSpacing), 0, "Tick must be multiple of spacing");
    }

    /// @notice Fuzzing 测试 - 测试各种 tick 值
    function testFuzz_nearestUsableTick(int24 tick) public {
        uint24 tickSpacing = 60;

        // 限制 tick 在有效范围内
        vm.assume(tick >= TickMath.MIN_TICK && tick <= TickMath.MAX_TICK);

        int24 rounded = TestHelper.nearestUsableTick(tick, tickSpacing);

        // 验证不变量
        assertEq(rounded % int24(tickSpacing), 0, "Result must be multiple of spacing");
        assertTrue(rounded >= TickMath.MIN_TICK, "Cannot be less than MIN_TICK");
        assertTrue(rounded <= TickMath.MAX_TICK, "Cannot exceed MAX_TICK");

        // 验证舍入后的 tick 与原始 tick 的差距不超过 spacing
        int24 diff = rounded > tick ? rounded - tick : tick - rounded;
        assertTrue(diff <= int24(tickSpacing), "Difference cannot exceed one spacing");
    }

    /// @notice Fuzzing 测试 - 测试各种 tick spacing
    function testFuzz_differentSpacings(uint24 tickSpacing) public {
        // 限制 tickSpacing 在合理范围内
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);

        int24 tick = 85350;
        int24 rounded = TestHelper.nearestUsableTick(tick, tickSpacing);

        // 验证结果是 spacing 的倍数
        assertEq(rounded % int24(tickSpacing), 0, "Result must be multiple of spacing");

        // 验证在有效范围内
        assertTrue(rounded >= TickMath.MIN_TICK, "Cannot be less than MIN_TICK");
        assertTrue(rounded <= TickMath.MAX_TICK, "Cannot exceed MAX_TICK");
    }
}
