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
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";

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
        uint256 feeAmount;         // 当前步骤的手续费
        bool initialized;          // 下一个tick是否已初始化
    }

    /// @notice 修改仓位参数结构
    struct ModifyPositionParams {
        address owner;
        int24 lowerTick;
        int24 upperTick;
        int128 liquidityDelta;
    }

    // ============ 常量 ============

    /// @notice 最小 Tick 索引
    int24 internal constant MIN_TICK = -887272;
    /// @notice 最大 Tick 索引
    int24 internal constant MAX_TICK = -MIN_TICK;

    // ============ 不可变状态 ============

    /// @notice Factory 合约地址
    address public immutable factory;
    /// @notice 池子的第一个代币
    address public immutable token0;
    /// @notice 池子的第二个代币
    address public immutable token1;
    /// @notice Tick 间距（决定价格精度）
    uint24 public immutable tickSpacing;
    /// @notice 手续费率（以百万分之一为单位）
    /// @dev 500 = 0.05%, 3000 = 0.3%, 10000 = 1%
    uint24 public immutable fee;

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

    /// @notice token0 的全局费用累积器
    /// @dev 使用 Q128 定点数格式，记录每单位流动性累积的 token0 手续费
    uint256 public feeGrowthGlobal0X128;

    /// @notice token1 的全局费用累积器
    /// @dev 使用 Q128 定点数格式，记录每单位流动性累积的 token1 手续费
    uint256 public feeGrowthGlobal1X128;

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
    error InvalidPriceLimit();
    error AlreadyInitialized();
    error TickSpacingMismatch();

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

    /// @notice 闪电贷事件
    /// @param sender 调用者地址
    /// @param recipient 接收代币的地址
    /// @param amount0 借出的 token0 数量
    /// @param amount1 借出的 token1 数量
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice 移除流动性事件
    event Burn(
        address indexed owner,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice 提取代币事件
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint256 amount0,
        uint256 amount1
    );

    // ============ 构造函数 ============

    /// @notice 创建新的交易池
    /// @dev 使用控制反转模式，从 Factory 合约读取参数
    constructor() {
        // msg.sender 就是 Factory 合约地址
        (factory, token0, token1, tickSpacing, fee) = IUniswapV3PoolDeployer(
            msg.sender
        ).parameters();
    }

    // ============ 外部函数 ============

    /// @notice 初始化池子价格
    /// @param sqrtPriceX96 初始价格的 Q64.96 格式平方根
    /// @dev 该函数只能调用一次
    function initialize(uint160 sqrtPriceX96) public {
        // 防止重复初始化
        if (slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();

        // 根据价格计算对应的 tick
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        // 设置初始状态
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

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
        if (amount == 0) revert ZeroLiquidity();

        // 使用 _modifyPosition 更新状态
        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: owner,
                lowerTick: lowerTick,
                upperTick: upperTick,
                liquidityDelta: int128(amount)
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        // 通过回调接收代币
        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

        // 验证余额变化
        if (amount0 > 0 && balance0() < balance0Before + amount0) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1() < balance1Before + amount1) {
            revert InsufficientInputAmount();
        }

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
    /// @param sqrtPriceLimitX96 价格限制（Q64.96 格式的平方根价格）
    /// @param data 回调函数的额外数据
    /// @return amount0 token0 的数量变化
    /// @return amount1 token1 的数量变化
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // 获取当前池子状态
        Slot0 memory slot0_ = slot0;

        // 验证价格限制的有效性
        if (
            zeroForOne
                // 卖出 token0（zeroForOne = true）时，价格会下跌
                // 限制价格必须小于当前价格，且大于最小允许价格
                ? sqrtPriceLimitX96 > slot0_.sqrtPriceX96 ||
                    sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
                // 卖出 token1（zeroForOne = false）时，价格会上涨
                // 限制价格必须大于当前价格，且小于最大允许价格
                : sqrtPriceLimitX96 < slot0_.sqrtPriceX96 ||
                    sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
        ) revert InvalidPriceLimit();

        // 初始化交换状态
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick,
            liquidity: liquidity
        });

        // 主循环：直到处理完所有输入金额或达到价格限制
        // 注意：使用范围比较而非精确相等，因为价格可能跨越限制价格
        while (
            state.amountSpecifiedRemaining > 0 &&
            (zeroForOne
                ? state.sqrtPriceX96 > sqrtPriceLimitX96  // 卖出 token0：价格下跌，只要当前价格 > 限制价格就继续
                : state.sqrtPriceX96 < sqrtPriceLimitX96) // 卖出 token1：价格上涨，只要当前价格 < 限制价格就继续
        ) {
            StepState memory step;

            // 设置当前步骤的起始价格
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            // 获取下一个初始化的tick和是否已初始化的标志
            (step.nextTick, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                int24(tickSpacing),
                zeroForOne
            );

            // 计算下一个 Tick 的价格
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // 计算当前价格区间可提供的交换金额
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath
                .computeSwapStep(
                    state.sqrtPriceX96,
                    (
                        zeroForOne
                            // 卖出 token0 时，价格下跌
                            // 如果下一个 tick 的价格低于限制价格，使用限制价格作为目标
                            ? step.sqrtPriceNextX96 < sqrtPriceLimitX96
                            // 卖出 token1 时，价格上涨
                            // 如果下一个 tick 的价格高于限制价格，使用限制价格作为目标
                            : step.sqrtPriceNextX96 > sqrtPriceLimitX96
                    )
                        ? sqrtPriceLimitX96      // 使用限制价格
                        : step.sqrtPriceNextX96, // 使用下一个 tick 的价格
                    state.liquidity,
                    state.amountSpecifiedRemaining,
                    fee
                );

            // 更新交换状态
            state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount);
            state.amountCalculated += step.amountOut;

            // 更新全局费用累积器
            if (state.liquidity > 0) {
                if (zeroForOne) {
                    feeGrowthGlobal0X128 += Math.mulDiv(
                        step.feeAmount,
                        0x100000000000000000000000000000000,  // 2^128
                        state.liquidity
                    );
                } else {
                    feeGrowthGlobal1X128 += Math.mulDiv(
                        step.feeAmount,
                        0x100000000000000000000000000000000,  // 2^128
                        state.liquidity
                    );
                }
            }

            // 检查是否到达了价格区间边界
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // 到达边界，需要处理tick交叉
                if (step.initialized) {
                    // 获取tick交叉时的流动性变化，并翻转费用记录
                    int128 liquidityDelta = ticks.cross(
                        step.nextTick,
                        feeGrowthGlobal0X128,
                        feeGrowthGlobal1X128
                    );

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

    /// @notice 执行闪电贷
    /// @dev 任何人都可以调用此函数借出代币，但必须在回调中归还
    ///      闪电贷的核心机制：
    ///      1. 先无条件转出代币给借款人
    ///      2. 调用借款人的回调函数，让其执行操作并归还代币
    ///      3. 验证余额是否足够（必须 >= 贷前余额）
    ///      4. 如果余额不足，整个交易回滚，代币不会丢失
    /// @param recipient 接收代币的地址
    /// @param amount0 请求借出的 token0 数量
    /// @param amount1 请求借出的 token1 数量
    /// @param data 传递给回调函数的自定义数据
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        // 步骤1: 记录贷款前的余额
        // 这是验证还款的关键——贷后余额必须大于等于贷前余额
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        // 步骤2: 转出代币给借款人
        // 注意：这里是无条件转出，不检查任何抵押品
        // 依赖原子性保证：如果最后验证失败，整个交易回滚
        if (amount0 > 0) IERC20(token0).transfer(recipient, amount0);
        if (amount1 > 0) IERC20(token1).transfer(recipient, amount1);

        // 步骤3: 调用借款人合约的回调函数
        // 借款人需要在这个回调中：
        // 1. 使用借到的代币执行操作（套利、清算等）
        // 2. 归还代币到本合约
        // 注意：回调的调用者是 msg.sender（发起闪电贷的地址）
        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(data);

        // 步骤4: 验证还款
        // 检查当前余额是否大于等于贷款前余额
        // 如果借款人没有还钱，这里会回滚整个交易
        require(
            balance0() >= balance0Before,
            "Flash loan not repaid: token0"
        );
        require(
            balance1() >= balance1Before,
            "Flash loan not repaid: token1"
        );

        // 步骤5: 触发事件
        emit Flash(msg.sender, recipient, amount0, amount1);
    }

    /// @notice 移除流动性
    /// @dev 重要说明：
    ///      1. 为什么需要 lowerTick 和 upperTick 参数？
    ///         - 每个 Position 由 (owner, lowerTick, upperTick) 三元组唯一标识
    ///         - 用户可以在多个不同的价格区间创建独立的流动性仓位
    ///         - 例如：Alice 可以同时拥有 [100,200]、[300,400]、[500,600] 三个独立仓位
    ///         - 必须明确指定要操作哪个价格区间的仓位
    ///      2. burn 只是"标记移除"，并不实际转出代币
    ///         - 将可提取的代币数量记录到 position.tokensOwed0/tokensOwed1
    ///         - 用户需要额外调用 collect() 函数才能真正提取代币
    /// @param lowerTick 价格区间下限（用于定位具体的 Position）
    /// @param upperTick 价格区间上限（用于定位具体的 Position）
    /// @param amount 要移除的流动性数量
    /// @return amount0 可提取的 token0 数量
    /// @return amount1 可提取的 token1 数量
    function burn(
        int24 lowerTick,
        int24 upperTick,
        uint128 amount
    ) public returns (uint256 amount0, uint256 amount1) {
        // 使用负数的流动性增量来移除流动性
        // 通过 (msg.sender, lowerTick, upperTick) 定位到具体的 Position
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    lowerTick: lowerTick,
                    upperTick: upperTick,
                    liquidityDelta: -int128(amount)  // 负数表示移除
                })
            );

        // 将返还的代币数量（包括本金+手续费）记录到仓位
        // 注意：这里只是记账，并未实际转出代币
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, lowerTick, upperTick, amount, amount0, amount1);
    }

    /// @notice 提取代币
    /// @dev 重要说明：
    ///      1. 为什么需要 lowerTick 和 upperTick 参数？
    ///         - 每个 Position 由 (owner, lowerTick, upperTick) 三元组唯一标识
    ///         - 用户可能在多个价格区间都有流动性仓位和累积的手续费
    ///         - 必须明确指定要从哪个价格区间提取收益
    ///      2. collect 的资金来源
    ///         - position.tokensOwed0/tokensOwed1 记录了可提取的代币数量
    ///         - 这些数量来自两部分：
    ///           a) burn() 移除流动性后的本金归还
    ///           b) 交易手续费的自然累积（通过 position.update() 计算）
    ///      3. 灵活的提取机制
    ///         - 可以只提取部分金额（amount0Requested < tokensOwed0）
    ///         - 可以提取到指定的 recipient 地址
    /// @param recipient 接收代币的地址
    /// @param lowerTick 价格区间下限（用于定位具体的 Position）
    /// @param upperTick 价格区间上限（用于定位具体的 Position）
    /// @param amount0Requested 请求提取的 token0 数量
    /// @param amount1Requested 请求提取的 token1 数量
    /// @return amount0 实际提取的 token0 数量
    /// @return amount1 实际提取的 token1 数量
    function collect(
        address recipient,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) public returns (uint128 amount0, uint128 amount1) {
        // 通过 (msg.sender, lowerTick, upperTick) 定位到具体的 Position
        Position.Info storage position = positions.get(
            msg.sender,
            lowerTick,
            upperTick
        );

        // 确保不能提取超过欠款的金额
        // 实际提取金额 = min(请求金额, 欠款金额)
        amount0 = amount0Requested > position.tokensOwed0
            ? position.tokensOwed0
            : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1
            ? position.tokensOwed1
            : amount1Requested;

        // 更新欠款并转账
        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            IERC20(token0).transfer(recipient, amount0);
        }

        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            IERC20(token1).transfer(recipient, amount1);
        }

        emit Collect(msg.sender, recipient, lowerTick, upperTick, amount0, amount1);
    }

    /// @notice 修改仓位流动性的内部函数
    /// @param params 修改参数
    /// @return position 仓位信息
    /// @return amount0 token0 数量变化
    /// @return amount1 token1 数量变化
    function _modifyPosition(ModifyPositionParams memory params)
        internal
        returns (
            Position.Info storage position,
            int256 amount0,
            int256 amount1
        )
    {
        // 验证 tick 范围
        if (params.lowerTick >= params.upperTick ||
            params.lowerTick < MIN_TICK ||
            params.upperTick > MAX_TICK) {
            revert InvalidTickRange();
        }

        // 验证 tick spacing
        if (params.lowerTick % int24(tickSpacing) != 0 ||
            params.upperTick % int24(tickSpacing) != 0) {
            revert TickSpacingMismatch();
        }

        Slot0 memory slot0_ = slot0;

        // 更新 Tick
        bool flippedLower;
        bool flippedUpper;
        if (params.liquidityDelta != 0) {
            flippedLower = ticks.update(params.lowerTick, params.liquidityDelta, false);
            flippedUpper = ticks.update(params.upperTick, params.liquidityDelta, true);

            // 更新位图
            if (flippedLower) {
                tickBitmap.flipTick(params.lowerTick, int24(tickSpacing));
            }
            if (flippedUpper) {
                tickBitmap.flipTick(params.upperTick, int24(tickSpacing));
            }
        }

        // 计算区间内累积的费用
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks
            .getFeeGrowthInside(
                params.lowerTick,
                params.upperTick,
                slot0_.tick,
                feeGrowthGlobal0X128,
                feeGrowthGlobal1X128
            );

        // 更新仓位
        position = positions.get(params.owner, params.lowerTick, params.upperTick);
        position.update(params.liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // 计算代币数量变化
        if (slot0_.tick < params.lowerTick) {
            // 价格区间在当前价格之上
            amount0 = int256(
                Math.calcAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.lowerTick),
                    TickMath.getSqrtRatioAtTick(params.upperTick),
                    params.liquidityDelta < 0
                        ? uint128(-params.liquidityDelta)
                        : uint128(params.liquidityDelta)
                )
            );
            if (params.liquidityDelta < 0) amount0 = -amount0;
        } else if (slot0_.tick < params.upperTick) {
            // 价格区间包含当前价格
            amount0 = int256(
                Math.calcAmount0Delta(
                    slot0_.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.upperTick),
                    params.liquidityDelta < 0
                        ? uint128(-params.liquidityDelta)
                        : uint128(params.liquidityDelta)
                )
            );

            amount1 = int256(
                Math.calcAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.lowerTick),
                    slot0_.sqrtPriceX96,
                    params.liquidityDelta < 0
                        ? uint128(-params.liquidityDelta)
                        : uint128(params.liquidityDelta)
                )
            );

            if (params.liquidityDelta < 0) {
                amount0 = -amount0;
                amount1 = -amount1;
            }

            // 更新全局流动性
            liquidity = LiquidityMath.addLiquidity(liquidity, params.liquidityDelta);
        } else {
            // 价格区间在当前价格之下
            amount1 = int256(
                Math.calcAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.lowerTick),
                    TickMath.getSqrtRatioAtTick(params.upperTick),
                    params.liquidityDelta < 0
                        ? uint128(-params.liquidityDelta)
                        : uint128(params.liquidityDelta)
                )
            );
            if (params.liquidityDelta < 0) amount1 = -amount1;
        }
    }
}
