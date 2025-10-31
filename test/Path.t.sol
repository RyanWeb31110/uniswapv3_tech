// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/lib/Path.sol";

/// @title Path 库测试合约
/// @notice 测试 Path 库的所有功能
contract PathTest is Test {
    using Path for bytes;

    // 使用真实的以太坊主网代币地址
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    /// @notice 测试单池路径
    function test_SinglePoolPath() public {
        // 构造路径：WETH → USDC
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC
        );

        // 验证路径长度
        assertEq(path.length, 46, "Single pool path should be 46 bytes");

        // 验证池子数量
        assertEq(path.numPools(), 1, "Should have 1 pool");

        // 验证 hasMultiplePools
        assertFalse(path.hasMultiplePools(), "Should not have multiple pools");

        // 解码参数
        (address tokenIn, address tokenOut, uint24 tickSpacing) = path.decodeFirstPool();
        assertEq(tokenIn, WETH, "tokenIn should be WETH");
        assertEq(tokenOut, USDC, "tokenOut should be USDC");
        assertEq(tickSpacing, 60, "tickSpacing should be 60");
    }

    /// @notice 测试多池路径
    function test_MultiPoolPath() public {
        // 构造路径：WETH → USDC → USDT → WBTC
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC,
            uint24(10),
            USDT,
            uint24(60),
            WBTC
        );

        // 验证路径长度
        assertEq(path.length, 89, "Multi pool path should be 89 bytes");

        // 验证池子数量
        assertEq(path.numPools(), 3, "Should have 3 pools");

        // 验证 hasMultiplePools
        assertTrue(path.hasMultiplePools(), "Should have multiple pools");
    }

    /// @notice 测试路径遍历
    function test_PathTraversal() public {
        // 构造路径：WETH → USDC → USDT
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC,
            uint24(10),
            USDT
        );

        // 第一个池子：WETH → USDC
        (address token0, address token1, uint24 spacing0) = path.decodeFirstPool();
        assertEq(token0, WETH, "First pool tokenIn should be WETH");
        assertEq(token1, USDC, "First pool tokenOut should be USDC");
        assertEq(spacing0, 60, "First pool tickSpacing should be 60");

        // 移动到下一个池子
        path = path.skipToken();

        // 第二个池子：USDC → USDT
        (address token2, address token3, uint24 spacing1) = path.decodeFirstPool();
        assertEq(token2, USDC, "Second pool tokenIn should be USDC");
        assertEq(token3, USDT, "Second pool tokenOut should be USDT");
        assertEq(spacing1, 10, "Second pool tickSpacing should be 10");
    }

    /// @notice 测试 getFirstPool
    function test_GetFirstPool() public {
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC,
            uint24(10),
            USDT
        );

        bytes memory firstPool = path.getFirstPool();

        // 第一个池子应该是 46 字节
        assertEq(firstPool.length, 46, "First pool should be 46 bytes");

        // 解码并验证
        (address tokenIn, address tokenOut, uint24 tickSpacing) = firstPool.decodeFirstPool();
        assertEq(tokenIn, WETH, "tokenIn should be WETH");
        assertEq(tokenOut, USDC, "tokenOut should be USDC");
        assertEq(tickSpacing, 60, "tickSpacing should be 60");
    }

    /// @notice 测试完整的多池路径遍历
    function test_FullPathTraversal() public {
        // 构造路径：WETH → USDC → USDT → WBTC
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC,
            uint24(10),
            USDT,
            uint24(60),
            WBTC
        );

        uint256 poolCount = 0;

        // 遍历所有池子
        while (true) {
            bool hasMultiple = path.hasMultiplePools();

            (address tokenIn, address tokenOut, uint24 tickSpacing) = path.decodeFirstPool();

            poolCount++;

            // 验证每个池子的参数
            if (poolCount == 1) {
                assertEq(tokenIn, WETH, "Pool 1 tokenIn should be WETH");
                assertEq(tokenOut, USDC, "Pool 1 tokenOut should be USDC");
                assertEq(tickSpacing, 60, "Pool 1 tickSpacing should be 60");
            } else if (poolCount == 2) {
                assertEq(tokenIn, USDC, "Pool 2 tokenIn should be USDC");
                assertEq(tokenOut, USDT, "Pool 2 tokenOut should be USDT");
                assertEq(tickSpacing, 10, "Pool 2 tickSpacing should be 10");
            } else if (poolCount == 3) {
                assertEq(tokenIn, USDT, "Pool 3 tokenIn should be USDT");
                assertEq(tokenOut, WBTC, "Pool 3 tokenOut should be WBTC");
                assertEq(tickSpacing, 60, "Pool 3 tickSpacing should be 60");
            }

            if (!hasMultiple) {
                break;
            }

            path = path.skipToken();
        }

        // 验证遍历了所有池子
        assertEq(poolCount, 3, "Should have traversed 3 pools");
    }

    /// @notice Fuzzing 测试：随机路径长度
    function testFuzz_NumPools(uint8 numPools_) public {
        // 限制池子数量在合理范围内
        vm.assume(numPools_ > 0 && numPools_ <= 10);

        // 构造随机路径
        bytes memory path = abi.encodePacked(WETH);
        for (uint8 i = 0; i < numPools_; i++) {
            path = abi.encodePacked(
                path,
                uint24(60),
                address(uint160(uint256(keccak256(abi.encode(i)))))
            );
        }

        // 验证池子数量
        assertEq(path.numPools(), numPools_, "Pool count mismatch");

        // 验证 hasMultiplePools
        if (numPools_ == 1) {
            assertFalse(path.hasMultiplePools(), "Single pool should return false");
        } else {
            assertTrue(path.hasMultiplePools(), "Multiple pools should return true");
        }
    }

    /// @notice 测试边界情况：最小有效路径
    function test_MinimumValidPath() public {
        // 最小路径：46 字节（单池）
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC
        );

        assertEq(path.length, 46, "Minimum path should be 46 bytes");
        assertEq(path.numPools(), 1, "Should have 1 pool");
        assertFalse(path.hasMultiplePools(), "Should not have multiple pools");
    }

    /// @notice 测试边界情况：双池路径
    function test_TwoPoolPath() public {
        // 双池路径：69 字节
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(60),
            USDC,
            uint24(10),
            USDT
        );

        assertEq(path.length, 69, "Two pool path should be 69 bytes");
        assertEq(path.numPools(), 2, "Should have 2 pools");
        assertTrue(path.hasMultiplePools(), "Should have multiple pools");
    }

    /// @notice 测试不同的 tick spacing 值
    function test_DifferentTickSpacings() public {
        // 测试不同的 tick spacing：10, 60, 200
        bytes memory path = abi.encodePacked(
            WETH,
            uint24(10),   // 稳定币对
            USDC,
            uint24(60),   // 常规代币对
            USDT,
            uint24(200),  // 高波动率代币对
            WBTC
        );

        // 验证第一个池子
        (address token0, address token1, uint24 spacing0) = path.decodeFirstPool();
        assertEq(spacing0, 10, "First tick spacing should be 10");

        // 跳到第二个池子
        path = path.skipToken();
        (, , uint24 spacing1) = path.decodeFirstPool();
        assertEq(spacing1, 60, "Second tick spacing should be 60");

        // 跳到第三个池子
        path = path.skipToken();
        (, , uint24 spacing2) = path.decodeFirstPool();
        assertEq(spacing2, 200, "Third tick spacing should be 200");
    }
}
