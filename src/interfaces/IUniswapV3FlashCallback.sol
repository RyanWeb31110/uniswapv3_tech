// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title 闪电贷回调接口
/// @notice 借款人合约必须实现此接口才能使用闪电贷
/// @dev 任何希望使用 Uniswap V3 闪电贷功能的合约都需要实现这个接口
interface IUniswapV3FlashCallback {

    /// @notice 闪电贷回调函数
    /// @dev 在此函数中，借款人需要:
    ///      1. 使用借到的代币执行操作
    ///      2. 归还代币到池子合约（包含手续费）
    ///      注意：此函数会被池子合约调用，调用者(msg.sender)必须是有效的池子地址
    /// @param fee0 需要支付的 token0 手续费
    /// @param fee1 需要支付的 token1 手续费
    /// @param data 自定义数据，由 flash 函数传入，可用于传递操作参数
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
