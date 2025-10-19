// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title IUniswapV3Pool
/// @notice UniswapV3 池合约的接口定义
/// @dev 定义了池合约需要实现的核心函数
interface IUniswapV3Pool {
    // ============ 数据结构 ============
    
    /// @notice 池子的核心状态信息
    struct Slot0 {
        uint160 sqrtPriceX96; // 当前价格的平方根（Q64.96 格式）
        int24 tick;          // 当前价格对应的 Tick
    }
    
    // ============ 外部函数 ============
    
    /// @notice 获取池子的当前状态
    /// @return sqrtPriceX96 当前价格的平方根
    /// @return tick 当前价格对应的 Tick
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick);
    
    /// @notice 执行代币交换
    /// @param recipient 接收输出代币的地址
    /// @param zeroForOne 交换方向（true: token0 -> token1）
    /// @param amountSpecified 指定的输入金额
    /// @param data 传递给回调函数的额外数据
    /// @return amount0 token0 的变化量
    /// @return amount1 token1 的变化量
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}
