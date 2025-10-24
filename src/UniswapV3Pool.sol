// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./lib/TickBitmap.sol";
import "./lib/Math.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";
import "./lib/LiquidityMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

/// @title UniswapV3Pool
/// @notice 实现 Uniswap V3 的核心交易池逻辑
/// @dev 这是一个简化版本，用于学习目的
contract UniswapV3Pool {
    // using: 将库函数绑定到类型上，使调用更简洁
    // 例如: ticks.update(tick, amount) 等价于 Tick.update(ticks, tick, amount)
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using TickBitmap for mapping(int16 => uint256);

    // ============ 数据结构 ============

    /// @notice 回调函数的额外数据结构
    /// @dev 使用 abi.encode 编码后传递给回调函数
    struct CallbackData {
        /// @notice 池中的 token0 地址
        address token0;
        /// @notice 池中的 token1 地址
        address token1;
        /// @notice 支付代币的用户地址
        address payer;
    }

    /// @notice 交换状态结构
    /// @dev 维护整个交换过程的状态
    struct SwapState {
        uint256 amountSpecifiedRemaining; // 剩余需要处理的输入金额
        uint256 amountCalculated;         // 已计算出的输出金额
        uint160 sqrtPriceX96;             // 当前价格（Q64.96 格式）
        int24 tick;                       // 当前 Tick
        uint128 liquidity;                // 当前流动性
    }

    /// @notice 交换步骤状态结构
    /// @dev 维护单次迭代的状态
    struct StepState {
        uint160 sqrtPriceStartX96; // 步骤开始时的价格
        int24 nextTick;            // 下一个已初始化的 Tick
        uint160 sqrtPriceNextX96;  // 下一个 Tick 的价格
        uint256 amountIn;          // 当前步骤的输入金额
        uint256 amountOut;         // 当前步骤的输出金额
        bool initialized;          // 下一个tick是否已初始化
    }

    // ============ 常量 ============

    /// @notice 最小 Tick 索引
    int24 internal constant MIN_TICK = -887272;
    /// @notice 最大 Tick 索引
    int24 internal constant MAX_TICK = -MIN_TICK;

    // ============ 不可变状态 ============

    /// @notice 池子的第一个代币
    address public immutable token0;
    /// @notice 池子的第二个代币
    address public immutable token1;

    // ============ 可变状态 ============

    /// @notice 池子的核心状态（价格和 Tick）
    /// @dev 打包到一个存储槽以节省 Gas
    struct Slot0 {
        uint160 sqrtPriceX96; // 当前平方根价格（Q64.96 格式）
        int24 tick; // 当前 Tick
    }

    Slot0 public slot0;

    /// @notice 当前价格点的流动性
    uint128 public liquidity;

    /// @notice Tick 状态映射
    mapping(int24 => Tick.Info) public ticks;

    /// @notice 仓位状态映射
    mapping(bytes32 => Position.Info) public positions;

    /// @notice 刻度位图索引
    mapping(int16 => uint256) public tickBitmap;

    // ============ 错误定义 ============

    error InvalidTickRange();
    error ZeroLiquidity();
    error InsufficientInputAmount();

    // ============ 事件定义 ============

    /// @notice 添加流动性事件
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice 代币交换事件
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    // ============ 构造函数 ============

    /// @notice 创建新的交易池
    /// @param token0_ 第一个代币地址
    /// @param token1_ 第二个代币地址
    /// @param sqrtPriceX96 初始平方根价格
    /// @param tick 初始 Tick
    constructor(address token0_, address token1_, uint160 sqrtPriceX96, int24 tick) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({ sqrtPriceX96: sqrtPriceX96, tick: tick });
    }

    // ============ 外部函数 ============

    /// @notice 在指定价格区间添加流动性
    /// @dev 支持三种价格区间类型：上方、包含当前价格、下方
    /// @param owner 流动性仓位的所有者
    /// @param lowerTick 价格区间下限
    /// @param upperTick 价格区间上限
    /// @param amount 要添加的流动性数量（L）
    /// @param data 回调函数的额外数据（编码后的 CallbackData）
    /// @return amount0 实际存入的 token0 数量
    /// @return amount1 实际存入的 token1 数量
    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {
        // ==================== C: CHECK（检查）====================
        // 步骤 1: 验证参数
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) {
            revert InvalidTickRange();
        }

        if (amount == 0) revert ZeroLiquidity();

        // ==================== E: EFFECTS（效果）==================
        // CEI 模式的关键：在调用外部合约前更新所有状态
        // 这样即使发生重入，重入者看到的也是最新状态

        // 步骤 2: 更新 Tick 和位图索引
        bool flippedLower = ticks.update(lowerTick, int128(amount), false);
        bool flippedUpper = ticks.update(upperTick, int128(amount), true);
        
        // 如果下边界 Tick 状态发生翻转，更新位图索引
        if (flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }

        // 如果上边界 Tick 状态发生翻转，更新位图索引
        if (flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        // 步骤 3: 更新仓位
        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        // 步骤 4: 根据价格区间位置计算代币数量
        // 获取当前价格状态
        Slot0 memory slot0_ = slot0;

        if (slot0_.tick < lowerTick) {
            // 情况1: 价格区间在当前价格之上
            // 流动性完全由 token0 组成
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );
            amount1 = 0;

        } else if (slot0_.tick < upperTick) {
            // 情况2: 价格区间包含当前价格
            // 流动性由两种代币按比例组成
            amount0 = Math.calcAmount0Delta(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );

            amount1 = Math.calcAmount1Delta(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                amount
            );

            // 只有这种情况才更新流动性跟踪器
            liquidity = LiquidityMath.addLiquidity(liquidity, int128(amount));

        } else {
            // 情况3: 价格区间在当前价格之下
            // 流动性完全由 token1 组成
            amount0 = 0;
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );
        }

        // ==================== I: INTERACTIONS（交互）=============
        // 步骤 5: 通过回调接收代币
        // 回调机制说明：
        // 1. 先记录当前余额
        // 2. 调用 msg.sender 的回调函数，告诉它需要转多少代币
        // 3. 回调函数应该将代币转入本合约
        // 4. 回调返回后，验证余额是否增加了
        // 优势：合约控制代币数量计算，防止用户作弊
        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        // 调用回调函数 - 调用者必须实现此接口，传递额外数据
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

        // ==================== C: CHECK（再次检查）===============
        // 步骤 6: 验证余额变化
        // 确保调用者在回调中真的转入了代币
        if (amount0 > 0 && balance0() < balance0Before + amount0) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1() < balance1Before + amount1) {
            revert InsufficientInputAmount();
        }

        // 步骤 7: 发出事件
        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    // ============ 内部函数 ============

    /// @notice 查询池子的 token0 余额
    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    /// @notice 查询池子的 token1 余额
    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

    /// @notice 执行代币交换
    /// @dev 实现动态的订单填充机制
    /// @param recipient 接收输出代币的地址
    /// @param zeroForOne 交换方向标志
    /// @param amountSpecified 用户指定的输入金额
    /// @param data 回调函数的额外数据
    /// @return amount0 token0 的数量变化
    /// @return amount1 token1 的数量变化
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // 获取当前池子状态
        Slot0 memory slot0_ = slot0;

        // 初始化交换状态
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick,
            liquidity: liquidity
        });

        // 主循环：直到处理完所有输入金额
        while (state.amountSpecifiedRemaining > 0) {
            StepState memory step;

            // 设置当前步骤的起始价格
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            // 获取下一个初始化的tick和是否已初始化的标志
            (step.nextTick, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                1,        // tickSpacing = 1
                zeroForOne
            );

            // 计算下一个 Tick 的价格
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // 计算当前价格区间可提供的交换金额
            (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath
                .computeSwapStep(
                    state.sqrtPriceX96,
                    step.sqrtPriceNextX96,
                    state.liquidity,
                    state.amountSpecifiedRemaining,
                    zeroForOne
                );

            // 更新交换状态
            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;

            // 检查是否到达了价格区间边界
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // 到达边界，需要处理tick交叉
                if (step.initialized) {
                    // 获取tick交叉时的流动性变化
                    int128 liquidityDelta = ticks.cross(step.nextTick);

                    // 根据交换方向调整流动性变化符号
                    if (zeroForOne) liquidityDelta = -liquidityDelta;

                    // 更新当前流动性
                    state.liquidity = LiquidityMath.addLiquidity(
                        state.liquidity,
                        liquidityDelta
                    );

                    // 检查流动性是否为零
                    if (state.liquidity == 0) revert ZeroLiquidity();
                }

                // 更新当前tick
                state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
            } else {
                // 价格仍在当前区间内，根据新价格计算tick
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // 更新池子状态
        if (state.tick != slot0_.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        }

        // 更新全局流动性变量
        if (liquidity != state.liquidity) liquidity = state.liquidity;

        // 计算最终的交换金额
        (amount0, amount1) = zeroForOne
            ? (
                int256(amountSpecified - state.amountSpecifiedRemaining),
                -int256(state.amountCalculated)
            )
            : (
                -int256(state.amountCalculated),
                int256(amountSpecified - state.amountSpecifiedRemaining)
            );

        // 执行代币转移
        if (zeroForOne) {
            // 用 token0 换取 token1
            IERC20(token1).transfer(recipient, uint256(-amount1));
            
            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance0Before + uint256(amount0) > balance0())
                revert InsufficientInputAmount();
        } else {
            // 用 token1 换取 token0
            IERC20(token0).transfer(recipient, uint256(-amount0));
            
            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance1Before + uint256(amount1) > balance1())
                revert InsufficientInputAmount();
        }

        // 发出交换事件
        emit Swap(
            msg.sender, recipient, amount0, amount1, 
            slot0.sqrtPriceX96, liquidity, slot0.tick
        );
    }
}
