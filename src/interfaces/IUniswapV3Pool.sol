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
        uint8 feeProtocol;   // 协议费用比例
    }

    /// @notice 累积的协议费用
    struct ProtocolFees {
        uint128 token0;  // 累积的 token0 协议费用
        uint128 token1;  // 累积的 token1 协议费用
    }

    // ============ 外部函数 ============

    /// @notice 获取池子的当前状态
    /// @return sqrtPriceX96 当前价格的平方根
    /// @return tick 当前价格对应的 Tick
    /// @return feeProtocol 协议费用比例
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint8 feeProtocol);

    /// @notice 获取累积的协议费用
    /// @return token0 累积的 token0 协议费用
    /// @return token1 累积的 token1 协议费用
    function protocolFees() external view returns (uint128 token0, uint128 token1);
    
    /// @notice 执行代币交换
    /// @param recipient 接收输出代币的地址
    /// @param zeroForOne 交换方向（true: token0 -> token1）
    /// @param amountSpecified 指定的输入金额
    /// @param sqrtPriceLimitX96 价格限制（Q64.96 格式的平方根价格）
    /// @param data 传递给回调函数的额外数据
    /// @return amount0 token0 的变化量
    /// @return amount1 token1 的变化量
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice 执行闪电贷
    /// @param recipient 接收代币的地址
    /// @param amount0 请求借出的 token0 数量
    /// @param amount1 请求借出的 token1 数量
    /// @param data 传递给回调函数的自定义数据
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice 获取 token0 地址
    function token0() external view returns (address);

    /// @notice 获取 token1 地址
    function token1() external view returns (address);

    /// @notice 设置协议费用比例
    /// @param feeProtocol0 token0 的协议费用比例 (0 或 4-10)
    /// @param feeProtocol1 token1 的协议费用比例 (0 或 4-10)
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice 提取累积的协议费用
    /// @param recipient 接收地址
    /// @param amount0Requested 请求提取的 token0 数量
    /// @param amount1Requested 请求提取的 token1 数量
    /// @return amount0 实际提取的 token0 数量
    /// @return amount1 实际提取的 token1 数量
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
