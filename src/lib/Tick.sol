// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./LiquidityMath.sol";

/// @title Tick 数据结构和操作
/// @notice 管理单个 Tick 的状态信息
library Tick {
    /// @notice Tick信息结构体
    /// @param initialized 是否已初始化
    /// @param liquidityGross tick处的总流动性
    /// @param liquidityNet 跨越tick时添加或移除的流动性数量
    struct Info {
        bool initialized;
        // tick处的总流动性
        uint128 liquidityGross;
        // 跨越tick时添加或移除的流动性数量
        int128 liquidityNet;
    }

    /// @notice 更新tick信息
    /// @param self tick映射
    /// @param tick tick位置
    /// @param liquidityDelta 流动性变化量
    /// @param upper 是否为上tick
    /// @return flipped tick是否被翻转
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int128 liquidityDelta,
        bool upper
    ) internal returns (bool flipped) {
        Tick.Info storage tickInfo = self[tick];
        
        // 记录tick是否已初始化
        bool wasInitialized = tickInfo.initialized;
        
        // 更新总流动性
        tickInfo.liquidityGross = LiquidityMath.addDelta(
            tickInfo.liquidityGross,
            liquidityDelta
        );
        
        // 更新净流动性变化
        tickInfo.liquidityNet = upper
            ? int128(int256(tickInfo.liquidityNet) - liquidityDelta)
            : int128(int256(tickInfo.liquidityNet) + liquidityDelta);
        
        // 检查tick是否被翻转
        flipped = wasInitialized != (tickInfo.liquidityGross > 0);
        
        // 更新初始化状态
        tickInfo.initialized = tickInfo.liquidityGross > 0;
    }

    /// @notice 跨越tick时获取流动性变化
    /// @param self tick映射
    /// @param tick tick位置
    /// @return liquidityDelta 流动性变化量
    function cross(mapping(int24 => Tick.Info) storage self, int24 tick)
        internal
        view
        returns (int128 liquidityDelta)
    {
        Tick.Info storage info = self[tick];
        liquidityDelta = info.liquidityNet;
    }
}
