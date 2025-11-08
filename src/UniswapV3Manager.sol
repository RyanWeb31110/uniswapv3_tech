// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./UniswapV3Pool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";
import "./lib/LiquidityAmounts.sol";
import "./lib/PoolAddress.sol";
import "./lib/Path.sol";

/// @title Uniswap V3 管理合约
/// @notice 为核心池合约提供用户友好的接口
/// @dev 作为用户和池合约之间的中介，处理代币授权和转移
contract UniswapV3Manager {
    using Path for bytes;

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

    /// @notice 单池交换参数
    struct SwapSingleParams {
        address tokenIn;           // 输入代币地址
        address tokenOut;          // 输出代币地址
        uint24 tickSpacing;        // Tick 间距（决定费率）
        uint256 amountIn;          // 输入代币数量
        uint160 sqrtPriceLimitX96; // 价格限制（滑点保护）
    }

    /// @notice 多池交换参数
    struct SwapParams {
        bytes path;            // 交换路径（编码后的多池路径）
        address recipient;     // 接收输出代币的地址
        uint256 amountIn;      // 输入代币数量
        uint256 minAmountOut;  // 最小输出数量（滑点保护）
    }

    /// @notice 交换回调数据
    struct SwapCallbackData {
        bytes path;      // 交换路径
        address payer;   // 支付输入代币的地址
    }

    /// @notice 获取仓位信息的参数
    struct GetPositionParams {
        address tokenA;      // 第一个代币地址
        address tokenB;      // 第二个代币地址
        uint24 fee;          // 费率（对应 tickSpacing）
        address owner;       // 仓位所有者地址
        int24 lowerTick;     // 价格区间下界
        int24 upperTick;     // 价格区间上界
    }

    // ==================== 错误定义 ====================

    /// @notice 滑点保护失败
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    /// @notice 接收的代币数量太少
    error TooLittleReceived(uint256 amountOut);

    // ==================== 外部函数 ====================

    /// @notice 获取用户在指定资金池中的流动性仓位信息
    /// @dev 这是一个只读函数，用于前端查询用户的仓位状态
    /// @param params 仓位查询参数（包含代币地址、费率、仓位所有者、价格区间）
    /// @return liquidity 流动性数量
    /// @return feeGrowthInside0LastX128 token0 的内部手续费增长快照（用于计算新增手续费）
    /// @return feeGrowthInside1LastX128 token1 的内部手续费增长快照（用于计算新增手续费）
    /// @return tokensOwed0 待领取的 token0 手续费（已结算但未领取的数量）
    /// @return tokensOwed1 待领取的 token1 手续费（已结算但未领取的数量）
    function getPosition(GetPositionParams calldata params)
        public
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        // 通过代币对和费率获取资金池合约
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

        // 从资金池合约读取仓位信息
        // 仓位键 = keccak256(abi.encodePacked(owner, lowerTick, upperTick))
        (
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        ) = pool.positions(
            keccak256(
                abi.encodePacked(
                    params.owner,      // 仓位所有者地址
                    params.lowerTick,  // 价格区间下界
                    params.upperTick   // 价格区间上界
                )
            )
        );
    }

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
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();

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

    /// @notice 执行单池交换
    /// @dev 用户需要先 approve 足够的输入代币给本合约
    /// @param params 单池交换参数
    /// @return amountOut 输出代币数量
    function swapSingle(SwapSingleParams calldata params)
        public
        returns (uint256 amountOut)
    {
        // 构建单池路径并调用 _swap
        amountOut = _swap(
            params.amountIn,              // 输入数量
            msg.sender,                   // 输出接收者（调用者）
            params.sqrtPriceLimitX96,     // 价格限制
            SwapCallbackData({
                // 编码单池路径：tokenIn | tickSpacing | tokenOut
                path: abi.encodePacked(
                    params.tokenIn,
                    params.tickSpacing,
                    params.tokenOut
                ),
                payer: msg.sender         // 付款人（调用者）
            })
        );
    }

    /// @notice 执行多池交换
    /// @dev 用户需要先 approve 足够的输入代币给本合约
    /// @param params 多池交换参数
    /// @return amountOut 最终输出代币数量
    function swap(SwapParams memory params) public returns (uint256 amountOut) {
        // 第一次交换由用户支付输入代币
        address payer = msg.sender;
        bool hasMultiplePools;

        // 循环遍历路径中的每个池
        while (true) {
            // 检查路径中是否还有多个池
            hasMultiplePools = params.path.hasMultiplePools();

            // 执行当前池的交换
            params.amountIn = _swap(
                params.amountIn,                                    // 输入数量
                hasMultiplePools ? address(this) : params.recipient, // 接收者
                0,                                                  // 禁用价格限制
                SwapCallbackData({
                    path: params.path.getFirstPool(),               // 当前池的路径
                    payer: payer                                    // 当前付款人
                })
            );

            // 如果还有更多池需要交换
            if (hasMultiplePools) {
                payer = address(this);           // 后续交换由合约支付
                params.path = params.path.skipToken(); // 移除已处理的池
            } else {
                // 所有池都处理完毕
                amountOut = params.amountIn;
                break;
            }
        }

        // 滑点保护：检查最终输出是否满足最小要求
        if (amountOut < params.minAmountOut)
            revert TooLittleReceived(amountOut);
    }

    // ==================== 内部函数 ====================

    /// @notice 获取池合约地址
    /// @dev 可以传入 tokenA 和 tokenB，函数内部会自动排序
    /// @param tokenA 第一个代币地址（可以是任意顺序）
    /// @param tokenB 第二个代币地址（可以是任意顺序）
    /// @param tickSpacing Tick 间距（或费率）
    /// @return pool 池合约实例
    function getPool(
        address tokenA,
        address tokenB,
        uint24 tickSpacing
    ) internal view returns (IUniswapV3Pool pool) {
        // 确保 token0 < token1（符合 UniswapV3 的地址排序规则）
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        // 使用 CREATE2 计算池地址（无需查询 Factory）
        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, tickSpacing)
        );
    }

    /// @notice 内部交换函数（被单池和多池交换调用）
    /// @param amountIn 输入代币数量
    /// @param recipient 接收输出代币的地址
    /// @param sqrtPriceLimitX96 价格限制
    /// @param data 传递给回调函数的数据
    /// @return amountOut 输出代币数量
    function _swap(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) internal returns (uint256 amountOut) {
        // 从路径中提取当前池的参数
        (address tokenIn, address tokenOut, uint24 tickSpacing) = data
            .path
            .decodeFirstPool();

        // 确定交换方向（token0 → token1 或 token1 → token0）
        bool zeroForOne = tokenIn < tokenOut;

        // 调用 Pool 合约进行实际交换
        (int256 amount0, int256 amount1) = getPool(
            tokenIn,
            tokenOut,
            tickSpacing
        ).swap(
            recipient,                   // 接收代币的地址
            zeroForOne,                  // 交换方向
            amountIn,                    // 输入数量
            sqrtPriceLimitX96 == 0       // 如果没有设置价格限制
                ? (
                    zeroForOne
                        ? TickMath.MIN_SQRT_RATIO + 1  // 使用最小价格
                        : TickMath.MAX_SQRT_RATIO - 1  // 使用最大价格
                )
                : sqrtPriceLimitX96,     // 使用指定的价格限制
            abi.encode(data)             // 传递给回调函数的数据
        );

        // 提取输出数量（根据交换方向选择 amount0 或 amount1）
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

    /// @notice Swap 回调函数实现（支持多池交换）
    /// @dev 由池合约调用，用于接收输入代币
    /// @param amount0 token0 的变化量（正数表示需要支付）
    /// @param amount1 token1 的变化量（正数表示需要支付）
    /// @param data_ 编码的 SwapCallbackData
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data_) public {
        // 解码回调数据
        SwapCallbackData memory data = abi.decode(data_, (SwapCallbackData));
        (address tokenIn, address tokenOut, ) = data.path.decodeFirstPool();

        // 确定交换方向
        bool zeroForOne = tokenIn < tokenOut;

        // 计算需要转入的代币数量（输入数量是正值）
        int256 amount = zeroForOne ? amount0 : amount1;

        // 根据付款人转移代币
        if (data.payer == address(this)) {
            // 如果付款人是合约自己（多池交换的中间步骤）
            // 直接从合约余额转移到池合约
            IERC20(tokenIn).transfer(msg.sender, uint256(amount));
        } else {
            // 如果付款人是用户（第一次交换或单池交换）
            // 从用户账户转移到池合约
            IERC20(tokenIn).transferFrom(
                data.payer,
                msg.sender,
                uint256(amount)
            );
        }
    }
}
