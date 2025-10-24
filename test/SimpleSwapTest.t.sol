// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Pool.sol";
import "./ERC20Mintable.sol";

/// @title 简单交换测试
/// @notice 测试基本的交换功能
contract SimpleSwapTest is Test {
    // ============ 测试状态变量 ============

    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    // ============ 初始化 ============

    function setUp() public {
        // 1. 部署测试代币
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);

        // 2. 部署池子合约
        // 初始价格：5000 USDC per ETH
        uint160 sqrtPriceX96 = 5602277097478614198912276234240; // sqrt(5000) * 2^96
        int24 tick = 85176; // tick for price 5000
        pool = new UniswapV3Pool(address(token0), address(token1), sqrtPriceX96, tick);

        // 3. 为测试合约铸造代币
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5000 ether);
    }

    // ============ 测试用例：基本交换 ============

    /// @notice 测试基本交换功能
    function testBasicSwap() public {
        // 设置价格区间：85176 - 86129 (5000 - 5500)
        int24 lowerTick = 85176;
        int24 upperTick = 86129;
        uint128 liquidity = 1000000000000000000; // 使用更小的流动性数量

        // 准备回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        // 添加流动性
        pool.mint(address(this), lowerTick, upperTick, liquidity, data);

        // 记录交换前的状态
        (uint160 sqrtPriceX96Before, int24 tickBefore) = pool.slot0();
        uint128 liquidityBefore = pool.liquidity();

        console.log("Before swap - Price:", sqrtPriceX96Before);
        console.log("Before swap - Tick:", tickBefore);
        console.log("Before swap - Liquidity:", liquidityBefore);

        // 执行小额交换（购买ETH）
        pool.swap(address(this), false, 42 ether, data);

        // 记录交换后的状态
        (uint160 sqrtPriceX96After, int24 tickAfter) = pool.slot0();
        uint128 liquidityAfter = pool.liquidity();

        console.log("After swap - Price:", sqrtPriceX96After);
        console.log("After swap - Tick:", tickAfter);
        console.log("After swap - Liquidity:", liquidityAfter);

        // 验证交换结果
        assertTrue(sqrtPriceX96After > 0, "Price should be positive");
        assertTrue(tickAfter > 0, "Tick should be positive");
        
        // 验证价格发生了变化
        assertTrue(sqrtPriceX96After != sqrtPriceX96Before, "Price should have changed");
        assertTrue(tickAfter != tickBefore, "Tick should have changed");
        
        // 验证流动性保持不变（仍在同一区间内）
        assertEq(liquidityAfter, liquidityBefore, "Liquidity should remain the same");
    }

    // ============ 回调函数实现 ============

    /// @notice Mint 回调函数实现
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) public {
        // 转移代币到池合约
        if (amount0 > 0) {
            token0.transfer(msg.sender, amount0);
        }
        if (amount1 > 0) {
            token1.transfer(msg.sender, amount1);
        }
    }

    /// @notice Swap 回调函数实现
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        // 如果 amount0 > 0，说明用户需要支付 token0
        if (amount0 > 0) {
            token0.transfer(msg.sender, uint256(amount0));
        }

        // 如果 amount1 > 0，说明用户需要支付 token1
        if (amount1 > 0) {
            token1.transfer(msg.sender, uint256(amount1));
        }
    }
}
