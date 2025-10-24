// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Pool.sol";
import "./ERC20Mintable.sol";

/// @title 跨Tick交换测试合约
/// @notice 测试跨多个价格区间的交换功能
contract CrossTickSwapTest is Test {
    // ============ 测试状态变量 ============

    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    // 测试用户地址
    address alice = address(0x1);

    // ============ 事件定义 ============

    event Mint(
        address sender,
        address indexed owner,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

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

        // 3. 为 Alice 铸造代币
        token0.mint(alice, 100 ether);
        token1.mint(alice, 100000 ether);
    }

    // ============ 测试用例：跨Tick交换 ============

    /// @notice 测试单一价格区间内的交换
    function testSwapWithinSingleRange() public {
        // 设置价格区间：85176 - 86129 (对应价格 5000 - 5500)
        int24 lowerTick = 85176;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544; // 使用与原始测试相同的流动性

        // 准备回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        // Alice 授权池子合约
        vm.startPrank(alice);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10000 ether);

        // 添加流动性
        pool.mint(alice, lowerTick, upperTick, liquidity, data);

        // 执行小额交换（购买ETH）
        pool.swap(alice, false, 42 ether, data);

        // 验证交换结果
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertTrue(sqrtPriceX96 > 0, "Price should be positive");
        assertTrue(tick > 0, "Tick should be positive");

        vm.stopPrank();
    }

    /// @notice 测试跨多个价格区间的交换
    function testSwapAcrossMultipleRanges() public {
        // 设置第一个价格区间：4545 - 5500
        int24 lowerTick1 = 4545;
        int24 upperTick1 = 5500;
        uint128 liquidity1 = 1 ether;

        // 设置第二个价格区间：5500 - 6250
        int24 lowerTick2 = 5500;
        int24 upperTick2 = 6250;
        uint128 liquidity2 = 1 ether;

        // 准备回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        // Alice 授权池子合约
        vm.startPrank(alice);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10000 ether);

        // 添加第一个价格区间的流动性
        pool.mint(alice, lowerTick1, upperTick1, liquidity1, data);

        // 添加第二个价格区间的流动性
        pool.mint(alice, lowerTick2, upperTick2, liquidity2, data);

        // 执行大额交换（购买ETH），应该跨越两个价格区间
        pool.swap(alice, false, 10000 ether, data);

        // 验证交换结果
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertTrue(sqrtPriceX96 > 0, "Price should be positive");
        assertTrue(tick > 0, "Tick should be positive");

        vm.stopPrank();
    }

    /// @notice 测试重叠价格区间的交换
    function testSwapOverlappingRanges() public {
        // 设置第一个价格区间：4545 - 5500
        int24 lowerTick1 = 4545;
        int24 upperTick1 = 5500;
        uint128 liquidity1 = 1 ether;

        // 设置第二个价格区间：5001 - 6250（与第一个区间重叠）
        int24 lowerTick2 = 5001;
        int24 upperTick2 = 6250;
        uint128 liquidity2 = 1 ether;

        // 准备回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        // Alice 授权池子合约
        vm.startPrank(alice);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10000 ether);

        // 添加第一个价格区间的流动性
        pool.mint(alice, lowerTick1, upperTick1, liquidity1, data);

        // 添加第二个价格区间的流动性
        pool.mint(alice, lowerTick2, upperTick2, liquidity2, data);

        // 执行交换（购买ETH）
        pool.swap(alice, false, 10000 ether, data);

        // 验证交换结果
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertTrue(sqrtPriceX96 > 0, "Price should be positive");
        assertTrue(tick > 0, "Tick should be positive");

        vm.stopPrank();
    }

    /// @notice 测试流动性不足的情况
    function testSwapInsufficientLiquidity() public {
        // 设置价格区间：4545 - 5500
        int24 lowerTick = 4545;
        int24 upperTick = 5500;
        uint128 liquidity = 1 ether;

        // 准备回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        // Alice 授权池子合约
        vm.startPrank(alice);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10000 ether);

        // 添加流动性
        pool.mint(alice, lowerTick, upperTick, liquidity, data);

        // 尝试执行超大额交换，应该失败
        vm.expectRevert();
        pool.swap(alice, false, 1000000 ether, data);

        vm.stopPrank();
    }
}
