// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title 字节操作工具库
/// @notice 提供字节数组的切片和类型转换功能
/// @dev 简化版实现，仅包含 Path 库所需的核心功能
library BytesLib {
    /// @notice 从字节数组中切片提取子数组
    /// @param _bytes 原始字节数组
    /// @param _start 起始位置（从 0 开始）
    /// @param _length 要提取的长度
    /// @return 提取的字节数组
    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_bytes.length >= _start + _length, "BytesLib: slice out of bounds");

        bytes memory tempBytes;

        assembly {
            // 分配新的内存空间
            // 0x40 是 Solidity 的 free memory pointer
            tempBytes := mload(0x40)

            // 计算新数组需要的总空间
            // 32 字节用于存储长度，_length 字节用于存储数据
            // 向上取整到 32 字节的倍数
            let lengthmod := and(_length, 31)
            let mc := add(tempBytes, lengthmod)
            let end := add(mc, _length)

            // 更新 free memory pointer
            mstore(0x40, add(end, 32))

            // 设置新数组的长度
            mstore(tempBytes, _length)

            // 复制数据
            // _bytes 的数据从 _bytes + 32 + _start 开始
            // tempBytes 的数据从 tempBytes + 32 开始
            let src := add(add(_bytes, 32), _start)
            let dst := add(tempBytes, 32)

            // 按 32 字节为单位复制
            for {
                let i := 0
            } lt(i, _length) {
                i := add(i, 32)
            } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }

        return tempBytes;
    }

    /// @notice 从字节数组中提取地址
    /// @param _bytes 字节数组
    /// @param _start 起始位置（从 0 开始）
    /// @return 提取的地址
    function toAddress(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (address)
    {
        require(_bytes.length >= _start + 20, "BytesLib: toAddress out of bounds");
        address tempAddress;

        assembly {
            // 地址占用 20 字节
            // 从 _bytes + 32 + _start 位置读取
            tempAddress := mload(add(add(_bytes, 20), _start))
        }

        return tempAddress;
    }

    /// @notice 从字节数组中提取 uint24
    /// @param _bytes 字节数组
    /// @param _start 起始位置（从 0 开始）
    /// @return 提取的 uint24 值
    function toUint24(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint24)
    {
        require(_bytes.length >= _start + 3, "BytesLib: toUint24 out of bounds");
        uint24 tempUint;

        assembly {
            // uint24 占用 3 字节
            // 从 _bytes + 32 + _start 位置读取
            tempUint := mload(add(add(_bytes, 3), _start))
        }

        return tempUint;
    }
}
