// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "solmate/tokens/ERC20.sol";

/// @title 可铸造的 ERC20 代币（仅用于测试）
/// @notice 继承 Solmate 的 ERC20 并公开 mint 功能
contract ERC20Mintable is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {}

    /// @notice 铸造代币（仅测试使用）
    /// @param to 接收地址
    /// @param amount 铸造数量
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

