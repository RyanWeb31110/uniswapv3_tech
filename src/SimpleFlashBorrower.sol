// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/IERC20.sol";

/// @title 简单闪电贷借款人
/// @notice 这个合约演示如何使用 Uniswap V3 的闪电贷功能
/// @dev 这是一个最简单的示例，只是借了再还，没有执行复杂的操作
contract SimpleFlashBorrower is IUniswapV3FlashCallback {

    /// @notice 发起闪电贷
    /// @dev 任何人都可以调用此函数发起闪电贷
    /// @param pool 池子合约地址
    /// @param amount0 请求借出的 token0 数量
    /// @param amount1 请求借出的 token1 数量
    function executeFlashLoan(
        address pool,
        uint256 amount0,
        uint256 amount1
    ) external {
        // 编码回调数据
        // 将借款数量编码后传递给回调函数
        bytes memory data = abi.encode(amount0, amount1);

        // 调用池子的 flash 函数
        // 注意：代币会被转到 address(this)，即本合约地址
        IUniswapV3Pool(pool).flash(
            address(this),  // 代币接收者
            amount0,        // 借出 token0 数量
            amount1,        // 借出 token1 数量
            data            // 回调数据
        );
    }

    /// @notice 闪电贷回调函数
    /// @dev 池子合约会调用这个函数
    ///      在这个函数中，我们需要：
    ///      1. 使用借到的代币执行操作
    ///      2. 归还代币到池子合约
    /// @param data 编码的回调数据
    function uniswapV3FlashCallback(bytes calldata data) external override {
        // 解码回调数据
        (uint256 amount0, uint256 amount1) = abi.decode(
            data,
            (uint256, uint256)
        );

        // 获取池子合约地址（调用者）
        address pool = msg.sender;

        // 🎯 在这里可以使用借到的代币执行操作
        // 例如：套利、清算、杠杆操作等
        // ...
        // 注意：在实际应用中，这里的操作需要确保最终有足够的代币归还

        // 归还代币到池子
        // 在实际应用中，这里需要确保有足够的代币来归还
        // 对于这个简单示例，假设合约已经预先存入了足够的代币
        if (amount0 > 0) {
            IERC20 token0 = IERC20(IUniswapV3Pool(pool).token0());
            token0.transfer(pool, amount0);
        }

        if (amount1 > 0) {
            IERC20 token1 = IERC20(IUniswapV3Pool(pool).token1());
            token1.transfer(pool, amount1);
        }
    }
}
