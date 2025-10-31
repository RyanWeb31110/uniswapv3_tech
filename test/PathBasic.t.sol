// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/lib/Path.sol";
import "../src/lib/BytesLib.sol";

/// @title Path 库基础测试
/// @notice 独立测试 Path 库的核心功能
contract PathBasicTest is Test {
    using Path for bytes;
    using BytesLib for bytes;

    // 使用完整的测试地址（避免 abi.encodePacked 的前导零问题）
    address constant TOKEN_A = address(0x0000000000000000000000000000000000000001);
    address constant TOKEN_B = address(0x0000000000000000000000000000000000000002);
    address constant TOKEN_C = address(0x0000000000000000000000000000000000000003);
    address constant TOKEN_D = address(0x0000000000000000000000000000000000000004);

    function setUp() public {
        // 无需设置
    }

    /// @notice 测试 BytesLib 的 toAddress 函数
    function test_BytesLib_toAddress() public {
        bytes memory data = abi.encodePacked(TOKEN_A);
        address extracted = data.toAddress(0);
        assertEq(extracted, TOKEN_A, "Address extraction failed");
    }

    /// @notice 测试 BytesLib 的 toUint24 函数
    function test_BytesLib_toUint24() public {
        bytes memory data = abi.encodePacked(uint24(60));
        uint24 extracted = data.toUint24(0);
        assertEq(extracted, 60, "Uint24 extraction failed");
    }

    /// @notice 测试 BytesLib 的 slice 函数
    function test_BytesLib_slice() public {
        bytes memory data = abi.encodePacked(TOKEN_A, uint24(60), TOKEN_B);

        // 提取前 20 字节（地址）
        bytes memory sliced = data.slice(0, 20);
        assertEq(sliced.length, 20, "Slice length incorrect");

        address extracted = sliced.toAddress(0);
        assertEq(extracted, TOKEN_A, "Sliced address incorrect");
    }

    /// @notice 测试单池路径
    function test_Path_SinglePool() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B
        );

        assertEq(path.length, 43, "Path length should be 43");
        assertEq(path.numPools(), 1, "Should have 1 pool");
        assertFalse(path.hasMultiplePools(), "Should not have multiple pools");
    }

    /// @notice 测试双池路径
    function test_Path_TwoPool() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B,
            uint24(10),
            TOKEN_C
        );

        assertEq(path.length, 66, "Path length should be 66");
        assertEq(path.numPools(), 2, "Should have 2 pools");
        assertTrue(path.hasMultiplePools(), "Should have multiple pools");
    }

    /// @notice 测试三池路径
    function test_Path_ThreePool() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B,
            uint24(10),
            TOKEN_C,
            uint24(200),
            TOKEN_D
        );

        assertEq(path.length, 89, "Path length should be 86");
        assertEq(path.numPools(), 3, "Should have 3 pools");
        assertTrue(path.hasMultiplePools(), "Should have multiple pools");
    }

    /// @notice 测试 decodeFirstPool
    function test_Path_DecodeFirstPool() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B
        );

        (address tokenIn, address tokenOut, uint24 tickSpacing) = path.decodeFirstPool();

        assertEq(tokenIn, TOKEN_A, "TokenIn incorrect");
        assertEq(tokenOut, TOKEN_B, "TokenOut incorrect");
        assertEq(tickSpacing, 60, "TickSpacing incorrect");
    }

    /// @notice 测试 getFirstPool
    function test_Path_GetFirstPool() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B,
            uint24(10),
            TOKEN_C
        );

        bytes memory firstPool = path.getFirstPool();
        assertEq(firstPool.length, 43, "First pool length should be 43");

        (address tokenIn, address tokenOut, uint24 tickSpacing) = firstPool.decodeFirstPool();
        assertEq(tokenIn, TOKEN_A, "First pool tokenIn incorrect");
        assertEq(tokenOut, TOKEN_B, "First pool tokenOut incorrect");
        assertEq(tickSpacing, 60, "First pool tickSpacing incorrect");
    }

    /// @notice 测试 skipToken
    function test_Path_SkipToken() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B,
            uint24(10),
            TOKEN_C
        );

        bytes memory skipped = path.skipToken();

        // 跳过后应该是：TOKEN_B, 10, TOKEN_C
        assertEq(skipped.length, 43, "Skipped path length should be 43");

        (address tokenIn, address tokenOut, uint24 tickSpacing) = skipped.decodeFirstPool();
        assertEq(tokenIn, TOKEN_B, "Skipped tokenIn should be TOKEN_B");
        assertEq(tokenOut, TOKEN_C, "Skipped tokenOut should be TOKEN_C");
        assertEq(tickSpacing, 10, "Skipped tickSpacing should be 10");
    }

    /// @notice 测试完整遍历
    function test_Path_FullTraversal() public {
        bytes memory path = abi.encodePacked(
            TOKEN_A,
            uint24(60),
            TOKEN_B,
            uint24(10),
            TOKEN_C,
            uint24(200),
            TOKEN_D
        );

        uint256 poolCount = 0;

        // 第一个池子
        (address token0, address token1, uint24 spacing0) = path.decodeFirstPool();
        assertEq(token0, TOKEN_A);
        assertEq(token1, TOKEN_B);
        assertEq(spacing0, 60);
        poolCount++;

        // 移动到第二个池子
        path = path.skipToken();
        (address token2, address token3, uint24 spacing1) = path.decodeFirstPool();
        assertEq(token2, TOKEN_B);
        assertEq(token3, TOKEN_C);
        assertEq(spacing1, 10);
        poolCount++;

        // 移动到第三个池子
        path = path.skipToken();
        (address token4, address token5, uint24 spacing2) = path.decodeFirstPool();
        assertEq(token4, TOKEN_C);
        assertEq(token5, TOKEN_D);
        assertEq(spacing2, 200);
        poolCount++;

        assertEq(poolCount, 3, "Should have traversed 3 pools");
    }
}
