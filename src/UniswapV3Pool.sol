// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./lib/Tick.sol";
import "./lib/Position.sol";
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

        // 步骤 2: 更新 Tick
        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        // 步骤 3: 更新仓位
        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        // 步骤 4: 计算代币数量（暂时使用硬编码值）
        // TODO: 在后续章节中实现动态计算
        amount0 = 0.99897661834742528 ether;
        amount1 = 5000 ether;

        // 步骤 5: 更新池子流动性
        liquidity += uint128(amount);

        // ==================== I: INTERACTIONS（交互）=============
        // 步骤 6: 通过回调接收代币
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
        // 步骤 7: 验证余额变化
        // 确保调用者在回调中真的转入了代币
        if (amount0 > 0 && balance0() < balance0Before + amount0) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1() < balance1Before + amount1) {
            revert InsufficientInputAmount();
        }

        // 步骤 8: 发出事件
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
    /// @dev 当前版本使用硬编码的值，后续章节会实现动态计算
    /// @param recipient 接收输出代币的地址
    /// @param data 回调函数的额外数据（编码后的 CallbackData）
    /// @return amount0 token0 的数量变化（负数表示输出给用户）
    /// @return amount1 token1 的数量变化（正数表示用户输入）
    function swap(address recipient, bytes calldata data)
        public
        returns (int256 amount0, int256 amount1)
    {
        // ==================== 步骤 1: 计算目标价格和数量 ====================
        // TODO: 目前使用硬编码值，后续章节会实现动态计算
        // 这些值是通过数学公式预先计算得出的

        int24 nextTick = 85184; // 目标 tick
        uint160 nextPrice = 5604469350942327889444743441197; // 目标价格

        // amount0 是负数：表示用户从池子获得 ETH
        amount0 = -0.008396714242162444 ether;

        // amount1 是正数：表示用户向池子支付 USDC
        amount1 = 42 ether;

        // ==================== 步骤 2: 更新池子状态 ====================
        // 交换会改变当前价格和 tick
        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        // ==================== 步骤 3: 转移代币 ====================

        // 3.1 将输出代币（ETH）发送给接收者
        // 使用 uint256(-amount0) 将负数转为正数
        // 注意：amount0 是负数，所以 -amount0 是正数
        if (amount0 < 0) {
            IERC20(token0).transfer(recipient, uint256(-amount0));
        }

        // 3.2 通过回调接收输入代币（USDC）
        uint256 balance1Before = balance1(); // 记录当前余额

        // 调用回调函数，通知调用者需要转入的代币数量，传递额外数据
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);

        // 3.3 验证余额变化
        // 确保调用者在回调中确实转入了足够的代币
        if (amount1 > 0) {
            uint256 expectedBalance = balance1Before + uint256(amount1);
            if (balance1() < expectedBalance) {
                revert InsufficientInputAmount();
            }
        }

        // ==================== 步骤 4: 发出事件 ====================
        emit Swap(
            msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick
        );
    }
}
