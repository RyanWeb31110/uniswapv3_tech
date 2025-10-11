// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title Tick 数据结构和操作
/// @notice 管理单个 Tick 的状态信息
library Tick {
    /// @notice Tick 的状态信息
    /// @param initialized 是否已初始化（是否有流动性）
    /// @param liquidity 该 Tick 的流动性总量
    struct Info {
        bool initialized;
        uint128 liquidity;
    }

    /// @notice 更新 Tick 的流动性
    /// @param self Tick 映射的存储引用
    /// @param tick 要更新的 Tick 索引
    /// @param liquidityDelta 流动性变化量
    function update(
        mapping(int24 => Tick.Info) storage self, // storage: 直接操作区块链存储，不复制数据
        int24 tick,
        uint128 liquidityDelta
    ) internal {
        Tick.Info storage tickInfo = self[tick]; // storage: 获取引用以修改区块链数据
        uint128 liquidityBefore = tickInfo.liquidity;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;

        // 如果是首次添加流动性，标记为已初始化
        if (liquidityBefore == 0) {
            tickInfo.initialized = true;
        }

        tickInfo.liquidity = liquidityAfter;
    }
}
