// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Strings 工具库
/// @notice 提供字符串操作的辅助函数
/// @dev 主要用于将数字转换为字符串
library Strings {
    bytes16 private constant ALPHABET = "0123456789abcdef";

    /// @notice 将 uint256 转换为字符串
    /// @param value 要转换的数字
    /// @return 转换后的字符串
    function toString(uint256 value) internal pure returns (string memory) {
        // 特殊情况：0
        if (value == 0) {
            return "0";
        }

        // 计算数字位数
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        // 分配字节数组
        bytes memory buffer = new bytes(digits);

        // 从后往前填充数字
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    /// @notice 将 uint256 转换为十六进制字符串
    /// @param value 要转换的数字
    /// @return 转换后的十六进制字符串（带 0x 前缀）
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }

        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }

        return toHexString(value, length);
    }

    /// @notice 将 uint256 转换为指定长度的十六进制字符串
    /// @param value 要转换的数字
    /// @param length 字节长度
    /// @return 转换后的十六进制字符串
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";

        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }

        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /// @notice 将 address 转换为十六进制字符串
    /// @param addr 地址
    /// @return 地址的十六进制字符串表示
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), 20);
    }
}
