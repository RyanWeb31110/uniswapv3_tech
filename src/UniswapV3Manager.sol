// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./UniswapV3Pool.sol";
import "./interfaces/IERC20.sol";
import "./lib/TickMath.sol";
import "./lib/LiquidityAmounts.sol";
import "./lib/PoolAddress.sol";

/// @title Uniswap V3 管理合约
/// @notice 为核心池合约提供用户友好的接口
/// @dev 作为用户和池合约之间的中介，处理代币授权和转移
contract UniswapV3Manager {
    // ==================== 状态变量 ====================

    /// @notice Factory 合约地址
    address public immutable factory;

    // ==================== 构造函数 ====================

    constructor(address factory_) {
        factory = factory_;
    }

    // ==================== 数据结构 ====================

    /// @notice 添加流动性的参数
    struct MintParams {
        address poolAddress;      // 池子地址
        int24 lowerTick;          // 价格区间下界（tick 值）
        int24 upperTick;          // 价格区间上界（tick 值）
        uint256 amount0Desired;   // 期望投入的 token0 数量
        uint256 amount1Desired;   // 期望投入的 token1 数量
        uint256 amount0Min;       // 最小可接受的 token0 数量（滑点保护）
        uint256 amount1Min;       // 最小可接受的 token1 数量（滑点保护）
    }

    // ==================== 错误定义 ====================

    /// @notice 滑点保护失败
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    /// @notice 接收的代币数量太少
    error TooLittleReceived(uint256 amountOut);

    // ==================== 外部函数 ====================

    /// @notice 向指定池提供流动性（带滑点保护）
    /// @dev 用户需要先 approve 足够的代币给本合约
    /// @param params 添加流动性的参数
    /// @return amount0 实际使用的 token0 数量
    /// @return amount1 实际使用的 token1 数量
    function mint(MintParams calldata params)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        // 获取池子合约实例
        UniswapV3Pool pool = UniswapV3Pool(params.poolAddress);

        // 获取当前价格
        (uint160 sqrtPriceX96, ) = pool.slot0();

        // 计算价格区间的平方根价格
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(params.lowerTick);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(params.upperTick);

        // 根据期望投入的代币数量计算流动性
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            params.amount0Desired,
            params.amount1Desired
        );

        // 调用池子的 mint 函数添加流动性
        (amount0, amount1) = pool.mint(
            msg.sender,
            params.lowerTick,
            params.upperTick,
            liquidity,
            abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    payer: msg.sender
                })
            )
        );

        // 滑点保护：验证实际投入的代币数量不低于最小值
        if (amount0 < params.amount0Min || amount1 < params.amount1Min)
            revert SlippageCheckFailed(amount0, amount1);
    }

    /// @notice 向指定池提供流动性（旧版本，保持向后兼容）
    /// @dev 用户需要先 approve 足够的代币给本合约
    /// @param poolAddress_ 目标池合约地址
    /// @param lowerTick 价格区间下界（Tick）
    /// @param upperTick 价格区间上界（Tick）
    /// @param liquidity 流动性数量
    /// @param data 额外数据（传递给池合约的回调）
    /// @return amount0 实际使用的 token0 数量
    /// @return amount1 实际使用的 token1 数量
    function mintWithLiquidity(
        address poolAddress_,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity,
        bytes calldata data
    ) public returns (uint256 amount0, uint256 amount1) {
        // 将调用转发到池合约
        // msg.sender 是用户地址，会被记录为流动性拥有者
        (amount0, amount1) = UniswapV3Pool(poolAddress_).mint(
            msg.sender, // owner: 用户地址
            lowerTick,
            upperTick,
            liquidity,
            data
        );
    }

    /// @notice 在指定池中执行代币交换（新版本，自动查找池子）
    /// @dev 用户需要先 approve 足够的输入代币给本合约
    /// @param tokenIn 输入代币地址
    /// @param tokenOut 输出代币地址
    /// @param tickSpacing Tick 间距
    /// @param amountIn 输入金额
    /// @param sqrtPriceLimitX96 价格限制（Q64.96 格式的平方根价格）
    /// @return amountOut 输出代币数量
    function swapSingle(
        address tokenIn,
        address tokenOut,
        uint24 tickSpacing,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) public returns (uint256 amountOut) {
        // 1. 排序代币
        (address token0, address token1) = tokenIn < tokenOut
            ? (tokenIn, tokenOut)
            : (tokenOut, tokenIn);

        // 2. 计算池子地址
        address poolAddress = PoolAddress.computeAddress(
            factory,
            token0,
            token1,
            tickSpacing
        );

        // 3. 确定交换方向
        bool zeroForOne = tokenIn < tokenOut;

        // 4. 执行交换
        (int256 amount0, int256 amount1) = UniswapV3Pool(poolAddress).swap(
            msg.sender,
            zeroForOne,
            amountIn,
            sqrtPriceLimitX96,
            abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: token0,
                    token1: token1,
                    payer: msg.sender
                })
            )
        );

        // 5. 返回输出数量
        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// @notice 在指定池中执行代币交换（旧版本，保持向后兼容）
    /// @dev 用户需要先 approve 足够的输入代币给本合约
    /// @param poolAddress_ 目标池合约地址
    /// @param zeroForOne 交换方向标志
    /// @param amountSpecified 用户指定的输入金额
    /// @param sqrtPriceLimitX96 价格限制（Q64.96 格式的平方根价格）
    /// @param data 额外数据（传递给池合约的回调）
    /// @return amount0 token0 的变化量
    /// @return amount1 token1 的变化量
    function swap(
        address poolAddress_,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // 将调用转发到池合约
        // msg.sender 是用户地址，会接收输出代币
        (amount0, amount1) = UniswapV3Pool(poolAddress_).swap(
            msg.sender, // recipient: 用户地址
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );
    }

    // ==================== 回调实现 ====================

    /// @notice Mint 回调函数实现
    /// @dev 由池合约调用，用于接收代币
    /// @param amount0 需要支付的 token0 数量
    /// @param amount1 需要支付的 token1 数量
    /// @param data 编码的 CallbackData
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) public {
        // 解码回调数据
        UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));

        // 从用户地址转移 token0 到池合约
        // extra.payer 是用户地址（已经 approve 给本合约）
        // msg.sender 是池合约地址
        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);

        // 从用户地址转移 token1 到池合约
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

    /// @notice Swap 回调函数实现
    /// @dev 由池合约调用，用于接收输入代币
    /// @param amount0 token0 的变化量（正数表示需要支付）
    /// @param amount1 token1 的变化量（正数表示需要支付）
    /// @param data 编码的 CallbackData
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        // 解码回调数据
        UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));

        // 如果 amount0 > 0，说明用户需要支付 token0
        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
        }

        // 如果 amount1 > 0，说明用户需要支付 token1
        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
        }
    }
}
