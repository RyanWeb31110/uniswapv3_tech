// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./UniswapV3Pool.sol";
import "./interfaces/IERC20.sol";

/// @title Uniswap V3 管理合约
/// @notice 为核心池合约提供用户友好的接口
/// @dev 作为用户和池合约之间的中介，处理代币授权和转移
contract UniswapV3Manager {
    // ==================== 错误定义 ====================

    /// @notice 滑点保护失败
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    /// @notice 接收的代币数量太少
    error TooLittleReceived(uint256 amountOut);

    // ==================== 外部函数 ====================

    /// @notice 向指定池提供流动性
    /// @dev 用户需要先 approve 足够的代币给本合约
    /// @param poolAddress_ 目标池合约地址
    /// @param lowerTick 价格区间下界（Tick）
    /// @param upperTick 价格区间上界（Tick）
    /// @param liquidity 流动性数量
    /// @param data 额外数据（传递给池合约的回调）
    /// @return amount0 实际使用的 token0 数量
    /// @return amount1 实际使用的 token1 数量
    function mint(
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

    /// @notice 在指定池中执行代币交换
    /// @dev 用户需要先 approve 足够的输入代币给本合约
    /// @param poolAddress_ 目标池合约地址
    /// @param data 额外数据（传递给池合约的回调）
    /// @return amount0 token0 的变化量
    /// @return amount1 token1 的变化量
    function swap(address poolAddress_, bytes calldata data)
        public
        returns (int256 amount0, int256 amount1)
    {
        // 将调用转发到池合约
        // msg.sender 是用户地址，会接收输出代币
        (amount0, amount1) = UniswapV3Pool(poolAddress_).swap(
            msg.sender, // recipient: 用户地址
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
