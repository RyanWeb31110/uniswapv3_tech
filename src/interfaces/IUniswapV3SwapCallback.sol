// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title Uniswap V3 Swap 回调接口
/// @notice 调用 swap 的合约必须实现此接口
/// @dev 用于在 swap 操作中接收输入代币
interface IUniswapV3SwapCallback {
    /// @notice swap 操作的回调函数
    /// @dev 在回调中，调用者需要将输入代币转入池子
    /// @param amount0Delta token0 的数量变化（正数表示池子需要接收，负数表示池子需要发送）
    /// @param amount1Delta token1 的数量变化（正数表示池子需要接收，负数表示池子需要发送）
    /// @param data swap 函数调用时传递的额外数据
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
        external;
}
