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
    /// @param feeGrowthOutside0X128 该 Tick 外部的 token0 累积费用（Q128 格式）
    /// @param feeGrowthOutside1X128 该 Tick 外部的 token1 累积费用（Q128 格式）
    struct Info {
        bool initialized;
        // tick处的总流动性
        uint128 liquidityGross;
        // 跨越tick时添加或移除的流动性数量
        int128 liquidityNet;
        // 该 Tick 外部的 token0 累积费用
        uint256 feeGrowthOutside0X128;
        // 该 Tick 外部的 token1 累积费用
        uint256 feeGrowthOutside1X128;
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

    /// @notice 跨越tick时获取流动性变化并翻转费用记录
    /// @param self tick映射
    /// @param tick tick位置
    /// @param feeGrowthGlobal0X128 全局 token0 累积费用
    /// @param feeGrowthGlobal1X128 全局 token1 累积费用
    /// @return liquidityDelta 流动性变化量
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal returns (int128 liquidityDelta) {
        Tick.Info storage info = self[tick];

        // 翻转费用记录（内外互换）
        // 这个操作利用了数学恒等式：全局费用 = 内部费用 + 外部费用
        // 因此：新外部费用 = 全局费用 - 旧外部费用
        info.feeGrowthOutside0X128 =
            feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 =
            feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;

        liquidityDelta = info.liquidityNet;
    }

    /// @notice 计算价格区间内累积的费用
    /// @param self tick映射
    /// @param lowerTick_ 区间下界
    /// @param upperTick_ 区间上界
    /// @param currentTick 当前 tick
    /// @param feeGrowthGlobal0X128 全局 token0 累积费用
    /// @param feeGrowthGlobal1X128 全局 token1 累积费用
    /// @return feeGrowthInside0X128 区间内 token0 累积费用
    /// @return feeGrowthInside1X128 区间内 token1 累积费用
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 lowerTick_,
        int24 upperTick_,
        int24 currentTick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) {
        Tick.Info storage lowerTick = self[lowerTick_];
        Tick.Info storage upperTick = self[upperTick_];

        // 计算下界以下的费用
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (currentTick >= lowerTick_) {
            // 价格在下界之上，直接使用记录值
            feeGrowthBelow0X128 = lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lowerTick.feeGrowthOutside1X128;
        } else {
            // 价格在下界之下，需要计算更新值
            feeGrowthBelow0X128 =
                feeGrowthGlobal0X128 - lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 =
                feeGrowthGlobal1X128 - lowerTick.feeGrowthOutside1X128;
        }

        // 计算上界以上的费用
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (currentTick < upperTick_) {
            // 价格在上界之下，直接使用记录值
            feeGrowthAbove0X128 = upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upperTick.feeGrowthOutside1X128;
        } else {
            // 价格在上界之上，需要计算更新值
            feeGrowthAbove0X128 =
                feeGrowthGlobal0X128 - upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 =
                feeGrowthGlobal1X128 - upperTick.feeGrowthOutside1X128;
        }

        // 区间内费用 = 总费用 - 下界以下费用 - 上界以上费用
        feeGrowthInside0X128 =
            feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 =
            feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }
}
