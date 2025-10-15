// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TickBitmap
 * @notice 刻度位图索引库，用于高效管理刻度状态
 * @dev 使用位图技术来索引已初始化的刻度，每个字可以存储256个刻度的状态
 */
library TickBitmap {
    /// @notice 计算刻度在位图中的位置
    /// @param tick 目标刻度
    /// @return wordPos 字位置
    /// @return bitPos 位位置
    function position(int24 tick) internal pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);  // 等价于 tick / 256
        bitPos = uint8(uint24(tick % 256));  // 余数部分
    }

    /// @notice 翻转指定刻度的标志位
    /// @param self 位图映射
    /// @param tick 目标刻度
    /// @param tickSpacing 刻度间距
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0, "Tick not spaced"); // 确保刻度符合间距要求
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;  // 使用异或操作翻转标志位
    }

    /// @notice 在单个字范围内查找下一个已初始化的刻度
    /// @param self 位图映射
    /// @param tick 当前刻度
    /// @param tickSpacing 刻度间距
    /// @param lte 方向标志：true表示出售X（向右搜索），false表示出售Y（向左搜索）
    /// @return next 下一个刻度位置
    /// @return initialized 是否找到已初始化的刻度
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        
        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // 创建掩码：当前位位置及其右侧的所有位
            uint256 mask = (1 << (bitPos + 1)) - 1;
            uint256 masked = self[wordPos] & mask;
            
            initialized = masked != 0;
            if (initialized) {
                // 找到最高有效位
                uint8 msb = mostSignificantBit(masked);
                next = (compressed - int24(uint24(bitPos - msb))) * tickSpacing;
            } else {
                // 没有找到，返回下一个字的起始位置
                next = (compressed - int24(uint24(bitPos))) * tickSpacing;
            }
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // 创建掩码：当前位位置左侧的所有位
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;
            
            initialized = masked != 0;
            if (initialized) {
                // 找到最低有效位
                uint8 lsb = leastSignificantBit(masked);
                next = (compressed + 1 + int24(uint24(lsb - bitPos))) * tickSpacing;
            } else {
                // 没有找到，返回下一个字的起始位置
                next = (compressed + 1 + int24(uint24(255 - bitPos))) * tickSpacing;
            }
        }
    }

    /// @notice 查找数字中最高有效位的位置
    /// @param x 输入数字
    /// @return msb 最高有效位的位置
    function mostSignificantBit(uint256 x) private pure returns (uint8 msb) {
        require(x > 0, "Zero input");
        
        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 0x10000000000000000) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 0x100000000) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 0x10000) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 0x100) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 0x10) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 0x4) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 0x2) msb += 1; // No need to shift x anymore
    }

    /// @notice 查找数字中最低有效位的位置
    /// @param x 输入数字
    /// @return lsb 最低有效位的位置
    function leastSignificantBit(uint256 x) private pure returns (uint8 lsb) {
        require(x > 0, "Zero input");
        
        // 使用位运算技巧快速找到最低有效位
        uint256 lsbValue = x & (~x + 1);
        
        // 将位位置转换为索引
        if (lsbValue >= 0x100000000000000000000000000000000) lsb = 128;
        else if (lsbValue >= 0x10000000000000000) lsb = 64;
        else if (lsbValue >= 0x100000000) lsb = 32;
        else if (lsbValue >= 0x10000) lsb = 16;
        else if (lsbValue >= 0x100) lsb = 8;
        else if (lsbValue >= 0x10) lsb = 4;
        else if (lsbValue >= 0x4) lsb = 2;
        else lsb = 1;
        
        // 转换为从0开始的索引
        lsb -= 1;
    }
}
