// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Manager.sol";
import "../src/UniswapV3Pool.sol";
import "./ERC20Mintable.sol";

/// @title UniswapV3Manager 测试合约
/// @notice 测试 Manager 合约作为用户和池之间的中介
contract UniswapV3ManagerTest is Test {
    // ============ 测试状态变量 ============

    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;
    UniswapV3Manager manager;

    // 测试用户地址
    address alice = address(0x1);
    address bob = address(0x2);

    // ============ 事件定义（用于测试） ============

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

        // 2. 部署池合约
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            5602277097478614198912276234240, // sqrtPriceX96 = √5000
            85176 // tick for price = 5000
        );

        // 3. 部署 Manager 合约
        manager = new UniswapV3Manager();
    }

    // ============ 测试用例：Mint 功能 ============

    /// @notice 测试通过 Manager 提供流动性
    function testMintThroughManager() public {
        // 准备测试参数
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        // 为 Alice 铸造代币
        token0.mint(alice, 10 ether);
        token1.mint(alice, 10000 ether);

        // Alice 授权 Manager
        vm.startPrank(alice);
        token0.approve(address(manager), 10 ether);
        token1.approve(address(manager), 10000 ether);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        // 记录 Alice 的初始余额
        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        // Alice 通过 Manager 添加流动性
        (uint256 amount0, uint256 amount1) =
            manager.mint(address(pool), lowerTick, upperTick, liquidity, data);

        vm.stopPrank();

        // 验证返回的代币数量
        assertEq(amount0, 0.99897661834742528 ether, "incorrect amount0");
        assertEq(amount1, 5000 ether, "incorrect amount1");

        // 验证 Alice 的代币已转移
        assertEq(
            token0.balanceOf(alice), aliceToken0Before - amount0, "incorrect Alice token0 balance"
        );
        assertEq(
            token1.balanceOf(alice), aliceToken1Before - amount1, "incorrect Alice token1 balance"
        );

        // 验证池子收到了代币
        assertEq(token0.balanceOf(address(pool)), amount0, "incorrect pool token0 balance");
        assertEq(token1.balanceOf(address(pool)), amount1, "incorrect pool token1 balance");

        // 验证流动性已记录在 Alice 名下
        bytes32 positionKey = keccak256(abi.encodePacked(alice, lowerTick, upperTick));
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, liquidity, "incorrect position liquidity");
    }

    /// @notice 测试没有 approve 的情况
    function testMintWithoutApprove() public {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        // 为 Alice 铸造代币
        token0.mint(alice, 10 ether);
        token1.mint(alice, 10000 ether);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        // Alice 没有 approve，尝试添加流动性应该失败
        vm.prank(alice);
        vm.expectRevert();
        manager.mint(address(pool), lowerTick, upperTick, liquidity, data);
    }

    /// @notice 测试多个用户同时提供流动性
    function testMintMultipleUsers() public {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        // 为 Alice 和 Bob 铸造代币
        token0.mint(alice, 10 ether);
        token1.mint(alice, 10000 ether);
        token0.mint(bob, 10 ether);
        token1.mint(bob, 10000 ether);

        // Alice 添加流动性
        vm.startPrank(alice);
        token0.approve(address(manager), 10 ether);
        token1.approve(address(manager), 10000 ether);

        bytes memory dataAlice = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: alice
            })
        );

        manager.mint(address(pool), lowerTick, upperTick, liquidity, dataAlice);
        vm.stopPrank();

        // Bob 添加流动性
        vm.startPrank(bob);
        token0.approve(address(manager), 10 ether);
        token1.approve(address(manager), 10000 ether);

        bytes memory dataBob = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: bob
            })
        );

        manager.mint(address(pool), lowerTick, upperTick, liquidity, dataBob);
        vm.stopPrank();

        // 验证两个用户的仓位都被记录
        bytes32 alicePositionKey = keccak256(abi.encodePacked(alice, lowerTick, upperTick));
        bytes32 bobPositionKey = keccak256(abi.encodePacked(bob, lowerTick, upperTick));

        assertEq(pool.positions(alicePositionKey), liquidity, "incorrect Alice position");
        assertEq(pool.positions(bobPositionKey), liquidity, "incorrect Bob position");
    }

    // ============ 测试用例：Swap 功能 ============

    /// @notice 测试通过 Manager 执行交换
    function testSwapThroughManager() public {
        // 1. 先由测试合约提供初始流动性
        _setupInitialLiquidity();

        // 2. 为 Bob 铸造 USDC 用于交换
        token1.mint(bob, 100 ether);

        // 3. Bob 授权 Manager
        vm.startPrank(bob);
        token1.approve(address(manager), 100 ether);

        // 4. 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: bob
            })
        );

        // 5. 记录 Bob 的初始余额
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        // 6. Bob 通过 Manager 执行交换
        (int256 amount0, int256 amount1) = manager.swap(address(pool), true, 1 ether, data);

        vm.stopPrank();

        // 7. 验证交换结果
        assertEq(amount0, -0.008396714242162444 ether, "incorrect amount0");
        assertEq(amount1, 42 ether, "incorrect amount1");

        // Bob 支付了 token1（正数）
        assertGt(amount1, 0, "amount1 should be positive");
        assertEq(
            token1.balanceOf(bob),
            bobToken1Before - uint256(amount1),
            "incorrect Bob token1 balance"
        );

        // Bob 接收了 token0（负数）
        assertLt(amount0, 0, "amount0 should be negative");
        assertEq(
            token0.balanceOf(bob),
            bobToken0Before + uint256(-amount0),
            "incorrect Bob token0 balance"
        );
    }

    /// @notice 测试没有足够代币余额的交换
    function testSwapInsufficientBalance() public {
        // 1. 设置初始流动性
        _setupInitialLiquidity();

        // 2. Bob 没有足够的代币
        token1.mint(bob, 10 ether); // 只有 10 USDC，但需要 42

        // 3. Bob 授权 Manager
        vm.startPrank(bob);
        token1.approve(address(manager), 100 ether);

        // 4. 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: bob
            })
        );

        // 5. 交换应该失败
        vm.expectRevert();
        manager.swap(address(pool), true, 1 ether, data);

        vm.stopPrank();
    }

    // ============ 辅助函数 ============

    /// @notice 设置初始流动性（由测试合约提供）
    function _setupInitialLiquidity() internal {
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        // 为测试合约铸造代币
        token0.mint(address(this), 10 ether);
        token1.mint(address(this), 10000 ether);

        // 授权 Manager
        token0.approve(address(manager), 10 ether);
        token1.approve(address(manager), 10000 ether);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        // 添加流动性
        manager.mint(address(pool), lowerTick, upperTick, liquidity, data);
    }
}
