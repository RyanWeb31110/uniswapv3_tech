// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/// @title ERC20 接口
/// @notice 简化的 ERC20 接口，仅包含本项目需要的函数
interface IERC20 {
    /// @notice 查询账户余额
    /// @param account 要查询的账户地址
    /// @return 账户的代币余额
    function balanceOf(address account) external view returns (uint256);

    /// @notice 转账代币
    /// @param recipient 接收者地址
    /// @param amount 转账数量
    /// @return 是否转账成功
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice 授权第三方使用代币
    /// @param spender 被授权的地址
    /// @param amount 授权的数量
    /// @return 是否授权成功
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice 从授权账户转账代币
    /// @param sender 代币发送者地址
    /// @param recipient 代币接收者地址
    /// @param amount 转账数量
    /// @return 是否转账成功
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);
}
