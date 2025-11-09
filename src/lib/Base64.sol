// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Base64 编码库
/// @notice 提供 Base64 编码功能
/// @dev 用于将二进制数据编码为 Base64 字符串，常用于 Data URI
library Base64 {
    string internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice 将字节数组编码为 Base64 字符串
    /// @param data 要编码的数据
    /// @return 编码后的 Base64 字符串
    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // 加载编码表
        string memory table = TABLE;

        // 计算输出长度（每 3 字节编码为 4 个字符）
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // 分配输出缓冲区
        string memory result = new string(encodedLen);

        assembly {
            // 获取编码表的起始位置
            let tablePtr := add(table, 1)

            // 获取输入数据的起始位置
            let dataPtr := add(data, 32)

            // 获取输出缓冲区的起始位置
            let resultPtr := add(result, 32)

            // 遍历输入数据，每次处理 3 字节
            for {
                let dataEnd := add(dataPtr, mload(data))
            } lt(dataPtr, dataEnd) {

            } {
                // 读取 3 字节数据
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // 编码为 4 个 Base64 字符
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // 处理填充（padding）
            switch mod(mload(data), 3)
            case 1 {
                // 如果剩余 1 字节，最后两个字符替换为 "=="
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                // 如果剩余 2 字节，最后一个字符替换为 "="
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }
}
