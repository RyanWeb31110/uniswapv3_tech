// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./Math.sol";

/// @title Position 数据结构和操作
/// @notice 管理流动性仓位信息
library Position {
    /// @notice 仓位的状态信息
    /// @param liquidity 该仓位的流动性数量
    /// @param feeGrowthInside0LastX128 仓位上次更新时区间内 token0 费用的快照
    /// @param feeGrowthInside1LastX128 仓位上次更新时区间内 token1 费用的快照
    /// @param tokensOwed0 仓位累积的 token0 欠款（包括本金和手续费）
    /// @param tokensOwed1 仓位累积的 token1 欠款（包括本金和手续费）
    struct Info {
        uint128 liquidity;
        // 仓位上次更新时区间内的费用快照
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // 仓位欠款（用于 burn 和 collect）
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice 获取仓位信息
    /// @dev 使用三个参数的哈希作为唯一标识
    /// @param self Position 映射的存储引用
    /// @param owner 仓位所有者地址
    /// @param lowerTick 价格区间下限
    /// @param upperTick 价格区间上限
    /// @return position 仓位信息的存储引用
    function get(
        mapping(bytes32 => Info) storage self, // storage: mapping 只能使用 storage
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) internal view returns (Position.Info storage position) {
        // storage: 返回引用而非副本
        // 使用三个参数的哈希作为键
        // 这样只需要一个 32 字节的存储槽，而不是三个
        position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
    }

    /// @notice 更新仓位的流动性和费用
    /// @param self 仓位信息的存储引用
    /// @param liquidityDelta 流动性变化量（正数为增加，负数为减少）
    /// @param feeGrowthInside0X128 当前区间内 token0 累积费用
    /// @param feeGrowthInside1X128 当前区间内 token1 累积费用
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        uint128 liquidityBefore = self.liquidity;
        uint128 liquidityAfter;

        // 计算新的流动性
        if (liquidityDelta == 0) {
            // 如果流动性没有变化（只是更新费用），检查流动性必须大于 0
            if (liquidityBefore == 0) revert("Position: zero liquidity");
            liquidityAfter = liquidityBefore;
        } else if (liquidityDelta > 0) {
            // 增加流动性
            liquidityAfter = liquidityBefore + uint128(liquidityDelta);
        } else {
            // 减少流动性
            liquidityAfter = liquidityBefore - uint128(-liquidityDelta);
        }

        // 计算自上次更新以来累积的费用
        uint128 tokensOwed0 = uint128(
            Math.mulDiv(
                feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
                liquidityBefore,
                0x100000000000000000000000000000000  // 2^128
            )
        );
        uint128 tokensOwed1 = uint128(
            Math.mulDiv(
                feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
                liquidityBefore,
                0x100000000000000000000000000000000  // 2^128
            )
        );

        // 更新状态
        self.liquidity = liquidityAfter;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;

        // 累积欠款
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
