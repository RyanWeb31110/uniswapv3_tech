// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title Uniswap V3 池子部署器接口
/// @notice 定义了池子部署时需要的参数结构
interface IUniswapV3PoolDeployer {
    /// @notice 池子部署参数结构
    /// @dev 用于在 Factory 和 Pool 之间传递初始化参数
    struct PoolParameters {
        /// @notice Factory 合约地址
        address factory;
        /// @notice 代币0地址（地址值较小的代币）
        address token0;
        /// @notice 代币1地址（地址值较大的代币）
        address token1;
        /// @notice Tick 间距（决定价格精度）
        uint24 tickSpacing;
    }

    /// @notice 获取池子部署参数
    /// @return factory Factory 合约地址
    /// @return token0 代币0地址
    /// @return token1 代币1地址
    /// @return tickSpacing Tick 间距
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 tickSpacing
        );
}
