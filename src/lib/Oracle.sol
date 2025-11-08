// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title Oracle
/// @notice 提供价格预言机功能，用于记录和查询历史价格
/// @dev 实现时间加权平均价格（TWAP）机制
library Oracle {
    // ============ 数据结构 ============

    /// @notice 观测值结构
    /// @dev 每个观测值记录一个时间点的价格信息
    struct Observation {
        uint32 timestamp;        // 记录时间戳
        int56 tickCumulative;    // 累计 Tick 值
        bool initialized;        // 是否已初始化
    }

    // ============ 函数 ============

    /// @notice 初始化观测数组
    /// @param self 观测数组的存储引用
    /// @param time 当前区块时间戳
    /// @return cardinality 初始基数（总是为 1）
    /// @return cardinalityNext 下一个基数（总是为 1）
    function initialize(
        Observation[65535] storage self,
        uint32 time
    ) internal returns (uint16 cardinality, uint16 cardinalityNext) {
        // 初始化第一个观测值
        self[0] = Observation({
            timestamp: time,
            tickCumulative: 0,
            initialized: true
        });

        // 默认基数为 1
        cardinality = 1;
        cardinalityNext = 1;
    }

    /// @notice 扩展观测数组容量
    /// @param self 观测数组的存储引用
    /// @param current 当前基数
    /// @param next 目标基数
    /// @return 更新后的目标基数
    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        // 如果目标基数小于等于当前基数，不需要扩展
        if (next <= current) return current;

        // 预先初始化新的观测槽位
        for (uint16 i = current; i < next; i++) {
            self[i].timestamp = 1;  // 设置一个非零值表示已预留
        }

        return next;
    }

    /// @notice 写入新的观测值
    /// @param self 观测数组的存储引用
    /// @param index 当前观测索引
    /// @param timestamp 当前区块时间戳
    /// @param tick 当前 Tick
    /// @param cardinality 当前基数
    /// @param cardinalityNext 目标基数
    /// @return indexUpdated 更新后的索引
    /// @return cardinalityUpdated 更新后的基数
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 timestamp,
        int24 tick,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // 如果当前区块已有观测，跳过（每个区块最多写入一次）
        if (last.timestamp == timestamp) return (index, cardinality);

        // 尝试扩展基数
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        // 计算新索引（循环覆盖）
        indexUpdated = (index + 1) % cardinalityUpdated;

        // 写入新观测值
        self[indexUpdated] = transform(last, timestamp, tick);
    }

    /// @notice 将上一个观测值转换为新的观测值
    /// @param last 上一个观测值
    /// @param timestamp 当前时间戳
    /// @param tick 当前 Tick
    /// @return 新的观测值
    function transform(
        Observation memory last,
        uint32 timestamp,
        int24 tick
    ) internal pure returns (Observation memory) {
        // 计算时间差
        uint56 delta = timestamp - last.timestamp;

        // 计算新的累计 Tick
        return Observation({
            timestamp: timestamp,
            tickCumulative: last.tickCumulative + int56(tick) * int56(delta),
            initialized: true
        });
    }

    /// @notice 查询多个时间点的观测值
    /// @param self 观测数组的存储引用
    /// @param time 当前区块时间戳
    /// @param secondsAgos 请求的时间点数组（距今多少秒前）
    /// @param tick 当前 Tick
    /// @param index 最新观测值的索引
    /// @param cardinality 当前基数
    /// @return tickCumulatives 累计 Tick 值数组
    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives) {
        // 初始化返回数组
        tickCumulatives = new int56[](secondsAgos.length);

        // 逐个查询
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            tickCumulatives[i] = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                cardinality
            );
        }
    }

    /// @notice 查询单个时间点的观测值
    /// @param self 观测数组的存储引用
    /// @param time 当前区块时间戳
    /// @param secondsAgo 距今多少秒前
    /// @param tick 当前 Tick
    /// @param index 最新观测值的索引
    /// @param cardinality 当前基数
    /// @return tickCumulative 累计 Tick 值
    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative) {
        // 情况 1: 请求最新观测（0 秒前）
        if (secondsAgo == 0) {
            Observation memory last = self[index];
            if (last.timestamp != time) {
                // 如果当前区块还没有观测，计算当前累计值
                return transform(last, time, tick).tickCumulative;
            }
            return last.tickCumulative;
        }

        // 计算目标时间
        uint32 target = time - secondsAgo;

        // 情况 2 和 3: 需要查找历史观测
        (Observation memory beforeOrAt, Observation memory atOrAfter) =
            getSurroundingObservations(self, time, target, tick, index, cardinality);

        // 如果找到精确匹配
        if (target == beforeOrAt.timestamp) {
            return beforeOrAt.tickCumulative;
        }

        // 需要插值计算
        uint56 observationTimeDelta = atOrAfter.timestamp - beforeOrAt.timestamp;
        uint56 targetDelta = target - beforeOrAt.timestamp;

        return beforeOrAt.tickCumulative +
               ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) /
                int56(observationTimeDelta)) *
               int56(targetDelta);
    }

    /// @notice 获取目标时间周围的两个观测值
    /// @param self 观测数组的存储引用
    /// @param time 当前区块时间戳
    /// @param target 目标时间戳
    /// @param tick 当前 Tick
    /// @param index 最新观测值的索引
    /// @param cardinality 当前基数
    /// @return beforeOrAt 目标时间之前或等于的观测值
    /// @return atOrAfter 目标时间之后或等于的观测值
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint16 cardinality
    )
        private
        view
        returns (Observation memory beforeOrAt, Observation memory atOrAfter)
    {
        // 获取最近的观测值
        beforeOrAt = self[index];

        // 如果最近观测值的时间 <= 目标时间
        if (lte(time, beforeOrAt.timestamp, target)) {
            if (beforeOrAt.timestamp == target) {
                // 精确匹配
                return (beforeOrAt, atOrAfter);
            } else {
                // 目标时间在最近观测之后，需要推算
                return (beforeOrAt, transform(beforeOrAt, target, tick));
            }
        }

        // 需要二分查找
        // 最老的观测值索引
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // 验证目标时间不能早于最老的观测值
        require(lte(time, beforeOrAt.timestamp, target), "OLD");

        // 二分查找
        return binarySearch(self, time, target, index, cardinality);
    }

    /// @notice 二分查找目标时间周围的观测值
    /// @param self 观测数组的存储引用
    /// @param time 当前区块时间戳
    /// @param target 目标时间戳
    /// @param index 最新观测值的索引
    /// @param cardinality 当前基数
    /// @return beforeOrAt 目标时间之前或等于的观测值
    /// @return atOrAfter 目标时间之后或等于的观测值
    function binarySearch(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    )
        private
        view
        returns (Observation memory beforeOrAt, Observation memory atOrAfter)
    {
        // 初始化搜索边界
        uint256 l = (index + 1) % cardinality;  // 最老的观测
        uint256 r = l + cardinality - 1;         // 最新的观测
        uint256 i;

        while (true) {
            i = (l + r) / 2;  // 中点

            beforeOrAt = self[i % cardinality];

            // 如果未初始化，继续向右搜索
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            // 检查 target 是否在 [beforeOrAt, atOrAfter] 区间内
            bool targetAtOrAfter = lte(time, beforeOrAt.timestamp, target);

            if (targetAtOrAfter && lte(time, target, atOrAfter.timestamp)) {
                break;  // 找到了！
            }

            // 调整搜索范围
            if (!targetAtOrAfter) {
                r = i - 1;
            } else {
                l = i + 1;
            }
        }
    }

    /// @notice 比较两个时间戳（考虑溢出）
    /// @param time 当前时间（基准）
    /// @param a 时间戳 a
    /// @param b 时间戳 b
    /// @return 如果 a <= b 返回 true
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // 如果 a <= time 且 b <= time，直接比较
        if (a <= time && b <= time) return a <= b;

        // 计算相对于 time 的差值
        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }
}
