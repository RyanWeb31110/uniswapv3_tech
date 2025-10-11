// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title Uniswap V3 Mint 回调接口
/// @notice 调用 mint 的合约必须实现此接口
/// @dev 回调机制工作流程：
///      1. 调用者调用 pool.mint()
///      2. 池子计算需要的代币数量
///      3. 池子通过此回调函数通知调用者
///      4. 调用者在回调中将代币转入池子
///      5. 池子验证代币是否到账
interface IUniswapV3MintCallback {
    /// @notice Mint 回调函数
    /// @dev 在此函数中将代币转入池子（msg.sender 就是池子合约）
    ///      池子会在调用此函数后验证余额是否增加
    /// @param amount0 需要转入的 token0 数量
    /// @param amount1 需要转入的 token1 数量
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) external;
}
