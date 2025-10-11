// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";

/// @title UniswapV3Pool 测试合约
contract UniswapV3PoolTest is Test {
    // ============ 测试状态变量 ============

    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool shouldTransferInCallback;

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

    // ============ 测试用例参数 ============

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
        bool mintLiquidity;
    }

    // ============ 初始化 ============

    function setUp() public {
        // 部署测试代币
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    // ============ Mint 回调实现 ============

    /// @notice 实现 mint 回调，将代币转入池子
    /// @dev 回调机制说明：
    ///      1. 测试合约调用 pool.mint()
    ///      2. 池子计算需要的代币数量并调用此回调
    ///      3. 回调中将代币转入池子（msg.sender 是池子合约）
    ///      4. 池子验证余额是否增加
    /// @param amount0 池子要求的 token0 数量
    /// @param amount1 池子要求的 token1 数量
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata /* data */) public {
        // 根据标志决定是否转账（用于测试不同场景）
        if (shouldTransferInCallback) {
            token0.transfer(msg.sender, amount0); // msg.sender 是池子合约
            token1.transfer(msg.sender, amount1);
        }
    }

    /// @notice 实现 swap 回调
    /// @dev 在回调中转入输入代币
    /// @param amount0Delta token0 的数量变化
    /// @param amount1Delta token1 的数量变化
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata /* data */)
        public
    {
        // amount0Delta < 0: 我们收到 token0（池子输出）
        // amount0Delta > 0: 我们需要支付 token0（池子输入）
        if (amount0Delta > 0) {
            token0.transfer(msg.sender, uint256(amount0Delta));
        }

        // amount1Delta > 0: 我们需要支付 token1（池子输入）
        if (amount1Delta > 0) {
            token1.transfer(msg.sender, uint256(amount1Delta));
        }
    }

    // ============ 辅助函数 ============

    /// @notice 设置测试用例
    /// @param params 测试参数
    /// @return poolBalance0 池子收到的 token0 数量
    /// @return poolBalance1 池子收到的 token1 数量
    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        // 1. 给测试合约铸造代币
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        // 2. 部署池子合约
        pool = new UniswapV3Pool(
            address(token0), address(token1), params.currentSqrtP, params.currentTick
        );

        // 3. 设置回调标志（必须在 mint 之前设置）
        shouldTransferInCallback = params.shouldTransferInCallback;

        // 4. 如果需要，mint 流动性
        if (params.mintLiquidity) {
            // 编码回调数据
            bytes memory data = abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    payer: address(this)
                })
            );
            (poolBalance0, poolBalance1) =
                pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
        }
    }

    // ============ 测试用例：成功场景 ============

    /// @notice 测试成功的流动性添加
    function testMintSuccess() public {
        // 1. 准备测试参数（使用我们在 Python 中计算的值）
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true
        });

        // 2. 执行测试用例设置
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        // 3. 验证返回的代币数量
        uint256 expectedAmount0 = 0.99897661834742528 ether;
        uint256 expectedAmount1 = 5000 ether;

        assertEq(poolBalance0, expectedAmount0, "incorrect token0 deposited amount");
        assertEq(poolBalance1, expectedAmount1, "incorrect token1 deposited amount");

        // 4. 验证池子的代币余额
        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        // 5. 验证仓位信息
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(this), params.lowerTick, params.upperTick));
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, params.liquidity, "incorrect position liquidity");

        // 6. 验证下限 Tick
        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(params.lowerTick);
        assertTrue(tickInitialized, "lower tick not initialized");
        assertEq(tickLiquidity, params.liquidity, "incorrect lower tick liquidity");

        // 7. 验证上限 Tick
        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(tickInitialized, "upper tick not initialized");
        assertEq(tickLiquidity, params.liquidity, "incorrect upper tick liquidity");

        // 8. 验证池子状态
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, 5602277097478614198912276234240, "invalid current sqrtP");
        assertEq(tick, 85176, "invalid current tick");
        assertEq(pool.liquidity(), 1517882343751509868544, "invalid current liquidity");
    }

    // ============ 测试用例：失败场景 ============

    /// @notice 测试无效的 Tick 范围（下限 >= 上限）
    function testMintInvalidTickRangeLower() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 86129, // 下限 > 上限
            upperTick: 84222,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: false
        });

        setupTestCase(params);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        // 期望交易回滚
        vm.expectRevert(UniswapV3Pool.InvalidTickRange.selector);
        pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
    }

    /// @notice 测试下限 Tick 超出范围
    function testMintInvalidTickRangeMin() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: -887273, // 小于 MIN_TICK
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: false
        });

        setupTestCase(params);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        vm.expectRevert(UniswapV3Pool.InvalidTickRange.selector);
        pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
    }

    /// @notice 测试上限 Tick 超出范围
    function testMintInvalidTickRangeMax() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 887273, // 大于 MAX_TICK
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: false
        });

        setupTestCase(params);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        vm.expectRevert(UniswapV3Pool.InvalidTickRange.selector);
        pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
    }

    /// @notice 测试零流动性
    function testMintZeroLiquidity() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 0, // 零流动性
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: false
        });

        setupTestCase(params);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        vm.expectRevert(UniswapV3Pool.ZeroLiquidity.selector);
        pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
    }

    /// @notice 测试未转账代币的情况
    function testMintInsufficientTokens() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: false, // 不转账
            mintLiquidity: false
        });

        setupTestCase(params);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        vm.expectRevert(UniswapV3Pool.InsufficientInputAmount.selector);
        pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
    }

    // ============ 测试用例：事件验证 ============

    /// @notice 测试 Mint 事件是否正确触发
    function testMintEvent() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: false
        });

        setupTestCase(params);

        // 编码回调数据
        bytes memory data = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        // 期望触发 Mint 事件
        vm.expectEmit(true, true, true, true);
        emit Mint(
            address(this),
            address(this),
            params.lowerTick,
            params.upperTick,
            params.liquidity,
            0.99897661834742528 ether,
            5000 ether
        );

        pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, data);
    }

    // ============ 测试用例：Swap 功能 ============

    /// @notice 测试：用 USDC 购买 ETH
    function testSwapBuyEth() public {
        // ==================== 步骤 1: 准备测试环境 ====================

        // 1.1 设置测试参数（与 mint 测试相同）
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiquidity: true // 先添加流动性
         });

        // 1.2 设置测试环境（部署池子、添加流动性）
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        // ==================== 步骤 2: 准备交换资金 ====================

        // 记录交换前的余额
        uint256 userBalance0Before = token0.balanceOf(address(this));

        // 铸造 42 USDC 用于交换
        token1.mint(address(this), 42 ether);

        // ==================== 步骤 3: 执行交换 ====================

        // 编码回调数据
        bytes memory swapData = abi.encode(
            UniswapV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this), swapData);

        // ==================== 步骤 4: 验证交换数量 ====================

        // 4.1 验证返回值
        assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");

        // ==================== 步骤 5: 验证用户余额 ====================

        // 5.1 用户的 ETH 余额应该增加
        // amount0Delta 是负数，所以减去负数等于加上正数
        assertEq(
            token0.balanceOf(address(this)),
            userBalance0Before + uint256(-amount0Delta),
            "invalid user ETH balance"
        );

        // 5.2 用户的 USDC 余额应该为 0（全部用于交换）
        assertEq(token1.balanceOf(address(this)), 0, "invalid user USDC balance");

        // ==================== 步骤 6: 验证池子余额 ====================

        // 6.1 池子的 ETH 余额应该减少
        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + amount0Delta),
            "invalid pool ETH balance"
        );

        // 6.2 池子的 USDC 余额应该增加
        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + amount1Delta),
            "invalid pool USDC balance"
        );

        // ==================== 步骤 7: 验证池子状态 ====================

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();

        // 7.1 验证价格已更新
        assertEq(sqrtPriceX96, 5604469350942327889444743441197, "invalid current sqrtP");

        // 7.2 验证 tick 已更新
        assertEq(tick, 85184, "invalid current tick");

        // 7.3 验证流动性未改变（单区间交换）
        assertEq(pool.liquidity(), 1517882343751509868544, "invalid current liquidity");
    }
}
