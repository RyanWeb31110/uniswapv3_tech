// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3Pool.sol";

/// @title Uniswap V3 池子工厂合约
/// @notice 负责创建和管理所有的交易池
contract UniswapV3Factory is IUniswapV3PoolDeployer {
    // ============ 错误定义 ============

    /// @notice 两个代币地址不能相同
    error TokensMustBeDifferent();

    /// @notice 不支持的 tick spacing
    error UnsupportedTickSpacing();

    /// @notice token0 不能是零地址
    error TokenXCannotBeZero();

    /// @notice 池子已存在
    error PoolAlreadyExists();

    // ============ 状态变量 ============

    /// @notice 记录哪些 tick spacing 和对应的手续费率是被支持的
    /// @dev tickSpacing => fee => 是否支持
    mapping(uint24 => mapping(uint24 => bool)) public tickSpacingToFee;

    /// @notice 临时存储池子初始化参数（仅在部署期间使用）
    /// @dev 使用控制反转模式，避免在构造函数中传递大量参数
    PoolParameters public override parameters;

    /// @notice 三维映射：token0 => token1 => tickSpacing => pool地址
    /// @dev 可以快速定位任意池子
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;

    // ============ 事件定义 ============

    /// @notice 池子创建事件
    /// @param token0 代币0地址
    /// @param token1 代币1地址
    /// @param tickSpacing Tick 间距
    /// @param pool 新创建的池子地址
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed tickSpacing,
        address pool
    );

    // ============ 构造函数 ============

    constructor() {
        // 初始化支持的 tick spacing 和手续费率组合
        // 稳定币对 - 高精度，低手续费（0.05%）
        tickSpacingToFee[10][500] = true;
        // 常规代币对 - 中等精度，中等手续费（0.3%）
        tickSpacingToFee[60][3000] = true;
        // 高波动率代币对 - 低精度，高手续费（1%）
        tickSpacingToFee[200][10000] = true;
    }

    // ============ 外部函数 ============

    /// @notice 创建一个新的交易池
    /// @param tokenX 代币 X 地址
    /// @param tokenY 代币 Y 地址
    /// @param tickSpacing Tick 间距（决定价格精度）
    /// @param fee 手续费率（以百万分之一为单位）
    /// @return pool 新创建的池子地址
    function createPool(
        address tokenX,
        address tokenY,
        uint24 tickSpacing,
        uint24 fee
    ) public returns (address pool) {
        // ========== 1. 输入验证 ==========

        // 检查代币地址不能相同
        if (tokenX == tokenY) revert TokensMustBeDifferent();

        // 检查 tick spacing 和 fee 的组合是否被支持
        if (!tickSpacingToFee[tickSpacing][fee]) revert UnsupportedTickSpacing();

        // ========== 2. 代币排序 ==========
        // 确保 token0 < token1（地址数值比较）
        (tokenX, tokenY) = tokenX < tokenY
            ? (tokenX, tokenY)
            : (tokenY, tokenX);

        // token0 不能是零地址
        if (tokenX == address(0)) revert TokenXCannotBeZero();

        // 检查池子是否已存在
        if (pools[tokenX][tokenY][tickSpacing] != address(0)) {
            revert PoolAlreadyExists();
        }

        // ========== 3. 设置部署参数 ==========
        // 使用控制反转模式传递参数
        parameters = PoolParameters({
            factory: address(this),
            token0: tokenX,
            token1: tokenY,
            tickSpacing: tickSpacing,
            fee: fee
        });

        // ========== 4. 使用 CREATE2 部署池子 ==========
        pool = address(
            new UniswapV3Pool{
                salt: keccak256(abi.encodePacked(tokenX, tokenY, tickSpacing))
            }()
        );

        // ========== 5. 清理临时参数 ==========
        // 删除参数可以退还 gas
        delete parameters;

        // ========== 6. 记录池子地址 ==========
        // 双向记录，方便查询
        pools[tokenX][tokenY][tickSpacing] = pool;
        pools[tokenY][tokenX][tickSpacing] = pool;

        // 发出事件
        emit PoolCreated(tokenX, tokenY, tickSpacing, pool);
    }
}
