// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title Position 数据结构和操作
/// @notice 管理流动性仓位信息
library Position {
    /// @notice 仓位的状态信息
    /// @param liquidity 该仓位的流动性数量
    struct Info {
        uint128 liquidity;
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
    ) internal view returns (Position.Info storage position) { // storage: 返回引用而非副本
        // 使用三个参数的哈希作为键
        // 这样只需要一个 32 字节的存储槽，而不是三个
        position = self[
            keccak256(abi.encodePacked(owner, lowerTick, upperTick))
        ];
    }

    /// @notice 更新仓位的流动性
    /// @param self 仓位信息的存储引用
    /// @param liquidityDelta 流动性变化量
    function update(Info storage self, uint128 liquidityDelta) internal { // storage: 直接修改区块链数据
        uint128 liquidityBefore = self.liquidity;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;

        self.liquidity = liquidityAfter;
    }
}
