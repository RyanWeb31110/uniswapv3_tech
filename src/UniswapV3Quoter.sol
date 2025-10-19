// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

/// @title UniswapV3Quoter
/// @notice 链上价格查询合约，用于计算交换结果而不实际执行交换
/// @dev 通过模拟真实交换来获取精确的报价信息
contract UniswapV3Quoter is IUniswapV3SwapCallback {
    // ============ 错误定义 ============
    
    /// @notice 无效的池地址
    error InvalidPool();
    
    /// @notice 无效的输入金额
    error InvalidAmountIn();

    // ============ 数据结构 ============
    
    /// @notice 报价参数结构
    struct QuoteParams {
        address pool;        // 目标池合约地址
        uint256 amountIn;    // 输入金额
        bool zeroForOne;     // 交换方向（true: token0 -> token1）
    }

    // ============ 外部函数 ============
    
    /// @notice 获取交换报价
    /// @dev 通过模拟真实交换来获取精确的报价信息
    /// @param params 报价参数
    /// @return amountOut 输出金额
    /// @return sqrtPriceX96After 交换后的价格（Q64.96 格式）
    /// @return tickAfter 交换后的 Tick
    function quote(QuoteParams memory params)
        public
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        // 参数验证
        if (params.pool == address(0)) revert InvalidPool();
        if (params.amountIn == 0) revert InvalidAmountIn();

        // 调用池合约的 swap 函数进行模拟交换
        // 这个调用会触发 uniswapV3SwapCallback，在那里我们会 revert 并返回结果
        try
            IUniswapV3Pool(params.pool).swap(
                address(this),           // 接收者（本合约）
                params.zeroForOne,       // 交换方向
                params.amountIn,         // 输入金额
                abi.encode(params.pool)  // 额外数据（池地址）
            )
        {} catch (bytes memory reason) {
            // 解码 revert 原因，获取交换结果
            return abi.decode(reason, (uint256, uint160, int24));
        }
        
        // 如果执行到这里，说明没有发生 revert，这是不应该发生的
        revert("Unexpected: swap did not revert");
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
