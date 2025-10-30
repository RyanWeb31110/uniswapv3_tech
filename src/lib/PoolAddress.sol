// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "../UniswapV3Pool.sol";

/// @title 池子地址计算库
/// @notice 提供离线计算池子地址的功能
library PoolAddress {
    /// @notice 计算池子的确定性地址
    /// @param factory Factory 合约地址
    /// @param token0 代币0地址（必须 < token1）
    /// @param token1 代币1地址
    /// @param tickSpacing Tick 间距
    /// @return pool 计算出的池子地址
    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 tickSpacing
    ) internal pure returns (address pool) {
        // 确保代币已排序
        require(token0 < token1, "Tokens not sorted");

        // 按照 CREATE2 规则计算地址
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            // CREATE2 的标识前缀
                            hex"ff",
                            // 部署者（Factory）地址
                            factory,
                            // Salt（代币对 + tick spacing）
                            keccak256(
                                abi.encodePacked(token0, token1, tickSpacing)
                            ),
                            // 池子合约的代码哈希
                            keccak256(type(UniswapV3Pool).creationCode)
                        )
                    )
                )
            )
        );
    }
}
