// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import {TickMath} from "../src/lib/TickMath.sol";

/// @title Tick 舍入功能简单测试
/// @notice 直接实现和测试 Tick 舍入功能
contract TickRoundingSimpleTest is Test {
    /// @notice 舍入除法 (Q64.64 格式)
    function divRound(int128 x, int128 y)
        internal
        pure
        returns (int128 result)
    {
        int128 quot = ABDKMath64x64.div(x, y);
        result = quot >> 64;
        if (quot % 2**64 >= 0x8000000000000000) {
            result += 1;
        }
    }

    /// @notice 将任意 tick 舍入到最近的可用 tick
    function nearestUsableTick(int24 tick_, uint24 tickSpacing)
        internal
        pure
        returns (int24 result)
    {
        result =
            int24(divRound(int128(tick_), int128(int24(tickSpacing)))) *
            int24(tickSpacing);

        if (result < TickMath.MIN_TICK) {
            result += int24(tickSpacing);
        } else if (result > TickMath.MAX_TICK) {
            result -= int24(tickSpacing);
        }
    }

    function test_divRound_Basic() public {
        // 1422 / 1 = 1422
        int128 x = int128(1422) << 64;
        int128 y = int128(1) << 64;
        int128 result = divRound(x, y);
        assertEq(result, 1422);
    }

    function test_divRound_RoundHalf() public {
        // 85350 / 60 = 1422.5 should round to 1423
        int128 x = int128(85350) << 64;
        int128 y = int128(60) << 64;
        int128 result = divRound(x, y);
        assertEq(result, 1423);
    }

    function test_nearestUsableTick_ExactMatch() public {
        uint24 tickSpacing = 60;
        int24 tick = 85320;
        int24 rounded = nearestUsableTick(tick, tickSpacing);

        assertEq(rounded, 85320);
        assertEq(rounded % int24(tickSpacing), 0);
    }

    function test_nearestUsableTick_RoundUp() public {
        uint24 tickSpacing = 60;
        int24 tick = 85350;  // 85350 / 60 = 1422.5 -> 1423 * 60 = 85380
        int24 rounded = nearestUsableTick(tick, tickSpacing);

        assertEq(rounded, 85380);
        assertEq(rounded % int24(tickSpacing), 0);
    }

    function test_nearestUsableTick_RoundDown() public {
        uint24 tickSpacing = 60;
        int24 tick = 85310;  // 85310 / 60 = 1421.83 -> 1422 * 60 = 85320
        int24 rounded = nearestUsableTick(tick, tickSpacing);

        assertEq(rounded, 85320);
        assertEq(rounded % int24(tickSpacing), 0);
    }

    function test_nearestUsableTick_Negative() public {
        uint24 tickSpacing = 60;
        int24 tick = -85350;
        int24 rounded = nearestUsableTick(tick, tickSpacing);

        // -85350 / 60 = -1422.5, rounds to -1423, -1423 * 60 = -85380
        assertEq(rounded, -85380);
        assertEq(rounded % int24(tickSpacing), 0);
    }

    function test_nearestUsableTick_DifferentSpacings() public {
        int24 tick = 1000;

        int24 rounded10 = nearestUsableTick(tick, 10);
        assertEq(rounded10, 1000);

        int24 rounded60 = nearestUsableTick(tick, 60);
        assertEq(rounded60, 1020);  // 1000/60=16.67 -> 17*60=1020

        int24 rounded200 = nearestUsableTick(tick, 200);
        assertEq(rounded200, 1000);  // 1000/200=5 -> 5*200=1000
    }

    function test_nearestUsableTick_Bounds() public {
        uint24 tickSpacing = 60;

        // Near MAX_TICK
        int24 nearMax = TickMath.MAX_TICK - 10;
        int24 roundedMax = nearestUsableTick(nearMax, tickSpacing);
        assertTrue(roundedMax <= TickMath.MAX_TICK);
        assertEq(roundedMax % int24(tickSpacing), 0);

        // Near MIN_TICK
        int24 nearMin = TickMath.MIN_TICK + 10;
        int24 roundedMin = nearestUsableTick(nearMin, tickSpacing);
        assertTrue(roundedMin >= TickMath.MIN_TICK);
        assertEq(roundedMin % int24(tickSpacing), 0);
    }
}
