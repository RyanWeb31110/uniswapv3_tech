// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./lib/PoolAddress.sol";
import "./lib/Path.sol";
import "./lib/TickMath.sol";

/// @title UniswapV3Quoter
/// @notice 链上价格查询合约，用于计算交换结果而不实际执行交换
/// @dev 通过模拟真实交换来获取精确的报价信息
contract UniswapV3Quoter is IUniswapV3SwapCallback {
    using Path for bytes;

    // ============ 状态变量 ============

    /// @notice Factory 合约地址
    address public immutable factory;

    // ============ 构造函数 ============

    constructor(address factory_) {
        factory = factory_;
    }

    // ============ 错误定义 ============

    /// @notice 无效的池地址
    error InvalidPool();

    /// @notice 无效的输入金额
    error InvalidAmountIn();

    // ============ 数据结构 ============

    /// @notice 报价参数结构（旧版本）
    struct QuoteParams {
        address pool;        // 目标池合约地址
        uint256 amountIn;    // 输入金额
        bool zeroForOne;     // 交换方向（true: token0 -> token1）
    }

    /// @notice 单池报价参数
    struct QuoteSingleParams {
        address tokenIn;           // 输入代币
        address tokenOut;          // 输出代币
        uint24 tickSpacing;        // Tick 间距
        uint256 amountIn;          // 输入数量
        uint160 sqrtPriceLimitX96; // 价格限制
    }

    // ============ 外部函数 ============

    /// @notice 计算单池交换的输出
    /// @param params 单池报价参数
    /// @return amountOut 预期输出数量
    /// @return sqrtPriceX96After 交换后的价格
    /// @return tickAfter 交换后的 tick
    function quoteSingle(QuoteSingleParams memory params)
        public
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        // 获取池合约
        IUniswapV3Pool pool = getPool(
            params.tokenIn,
            params.tokenOut,
            params.tickSpacing
        );

        // 确定交换方向
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 尝试执行交换（会回滚，但我们会捕获返回值）
        try
            pool.swap(
                address(this),
                zeroForOne,
                params.amountIn,
                params.sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1  // 最小价格限制 + 1
                            : TickMath.MAX_SQRT_RATIO - 1   // 最大价格限制 - 1
                    )
                    : params.sqrtPriceLimitX96,
                abi.encode(address(pool))
            )
        {} catch (bytes memory reason) {
            // 从回滚数据中提取结果
            return abi.decode(reason, (uint256, uint160, int24));
        }
    }

    /// @notice 计算多池交换的输出
    /// @param path 交换路径
    /// @param amountIn 输入数量
    /// @return amountOut 最终输出数量
    /// @return sqrtPriceX96AfterList 每个池交换后的价格列表
    /// @return tickAfterList 每个池交换后的 tick 列表
    function quote(bytes memory path, uint256 amountIn)
        public
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            int24[] memory tickAfterList
        )
    {
        // 初始化结果数组（长度等于池的数量）
        sqrtPriceX96AfterList = new uint160[](path.numPools());
        tickAfterList = new int24[](path.numPools());

        uint256 i = 0;

        // 遍历路径中的每个池
        while (true) {
            // 解码当前池的参数
            (address tokenIn, address tokenOut, uint24 tickSpacing) = path
                .decodeFirstPool();

            // 调用单池报价
            (
                uint256 amountOut_,
                uint160 sqrtPriceX96After,
                int24 tickAfter
            ) = quoteSingle(
                    QuoteSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        tickSpacing: tickSpacing,
                        amountIn: amountIn,      // 当前输入数量
                        sqrtPriceLimitX96: 0     // 不设置价格限制
                    })
                );

            // 保存当前池的结果
            sqrtPriceX96AfterList[i] = sqrtPriceX96After;
            tickAfterList[i] = tickAfter;
            amountIn = amountOut_; // 当前池的输出是下一个池的输入
            i++;

            // 检查是否还有更多池
            if (path.hasMultiplePools()) {
                path = path.skipToken(); // 移除已处理的池
            } else {
                amountOut = amountIn;    // 最后一个池的输出就是最终输出
                break;
            }
        }
    }

    // ============ 内部函数 ============

    /// @notice 获取池合约地址
    /// @param token0 第一个代币地址
    /// @param token1 第二个代币地址
    /// @param tickSpacing Tick 间距
    /// @return pool 池合约实例
    function getPool(
        address token0,
        address token1,
        uint24 tickSpacing
    ) internal view returns (IUniswapV3Pool pool) {
        // 确保 token0 < token1（符合 UniswapV3 的地址排序规则）
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);

        // 使用 CREATE2 计算池地址（无需查询 Factory）
        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, tickSpacing)
        );
    }

    // ============ 回调函数 ============
    
    /// @notice 交换回调函数实现
    /// @dev 由池合约调用，用于收集交换结果并中断执行
    /// @param amount0Delta token0 的变化量（正数表示需要支付）
    /// @param amount1Delta token1 的变化量（正数表示需要支付）
    /// @param data 编码的池地址
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view override {
        // 解码池地址
        address pool = abi.decode(data, (address));
        
        // 验证调用者是否为指定的池合约
        if (msg.sender != pool) revert InvalidPool();

        // 计算输出金额
        // 如果 amount0Delta > 0，说明用户支付 token0，获得 token1
        // 如果 amount0Delta < 0，说明用户支付 token1，获得 token0
        uint256 amountOut = amount0Delta > 0
            ? uint256(-amount1Delta)  // 获得 token1
            : uint256(-amount0Delta); // 获得 token0

        // 获取交换后的池状态
        (uint160 sqrtPriceX96After, int24 tickAfter) = IUniswapV3Pool(pool).slot0();

        // 使用内联汇编将数据写入内存并 revert
        // 这样做比使用 abi.encode 更节省 Gas
        assembly {
            let ptr := mload(0x40)                    // 获取下一个可用内存槽指针
            mstore(ptr, amountOut)                    // 写入输出金额
            mstore(add(ptr, 0x20), sqrtPriceX96After) // 写入新价格
            mstore(add(ptr, 0x40), tickAfter)         // 写入新 Tick
            revert(ptr, 96)                           // revert 并返回 96 字节数据
        }
    }
}
