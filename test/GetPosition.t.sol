// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Manager.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Factory.sol";
import "./ERC20Mintable.sol";

/// @title GetPosition 函数测试
/// @notice 测试 Manager 合约的 getPosition 辅助函数
contract GetPositionTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Factory factory;
    UniswapV3Pool pool;
    UniswapV3Manager manager;

    address alice = address(0x1);
    address bob = address(0x2);

    uint24 constant FEE_500 = 500;      // 0.05% 费率
    uint24 constant TICK_SPACING_10 = 10;

    function setUp() public {
        // 1. 部署代币
        token0 = new ERC20Mintable("Token A", "TKNA", 18);
        token1 = new ERC20Mintable("Token B", "TKNB", 18);

        // 确保 token0 < token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // 2. 部署 Factory
        factory = new UniswapV3Factory();

        // 3. 创建池子
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 价格 = 1
        int24 tick = 0;

        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            TICK_SPACING_10,
            sqrtPriceX96
        );
        pool = UniswapV3Pool(poolAddress);

        // 4. 部署 Manager
        manager = new UniswapV3Manager(address(factory));

        // 5. 给 Alice 铸造代币并授权
        token0.mint(alice, 10 ether);
        token1.mint(alice, 10 ether);

        vm.startPrank(alice);
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice 测试 getPosition 函数 - 空仓位
    function test_GetPosition_EmptyPosition() public {
        // 查询一个不存在的仓位
        UniswapV3Manager.GetPositionParams memory params = UniswapV3Manager
            .GetPositionParams({
            tokenA: address(token0),
            tokenB: address(token1),
            fee: TICK_SPACING_10,
            owner: alice,
            lowerTick: -100,
            upperTick: 100
        });

        (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = manager.getPosition(params);

        // 验证所有字段都是 0
        assertEq(liquidity, 0, "liquidity should be 0");
        assertEq(feeGrowthInside0LastX128, 0, "feeGrowthInside0 should be 0");
        assertEq(feeGrowthInside1LastX128, 0, "feeGrowthInside1 should be 0");
        assertEq(tokensOwed0, 0, "tokensOwed0 should be 0");
        assertEq(tokensOwed1, 0, "tokensOwed1 should be 0");
    }

    /// @notice 测试 getPosition 函数 - 有流动性的仓位
    function test_GetPosition_WithLiquidity() public {
        vm.startPrank(alice);

        // 1. Alice 添加流动性
        int24 lowerTick = -100;
        int24 upperTick = 100;
        uint128 liquidityToAdd = 1000000;

        pool.mint(
            alice,
            lowerTick,
            upperTick,
            liquidityToAdd,
            abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    payer: alice
                })
            )
        );

        vm.stopPrank();

        // 2. 使用 getPosition 查询仓位
        UniswapV3Manager.GetPositionParams memory params = UniswapV3Manager
            .GetPositionParams({
            tokenA: address(token0),
            tokenB: address(token1),
            fee: TICK_SPACING_10,
            owner: alice,
            lowerTick: lowerTick,
            upperTick: upperTick
        });

        (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = manager.getPosition(params);

        // 3. 验证结果
        assertEq(liquidity, liquidityToAdd, "incorrect liquidity");
        // 新添加的仓位，手续费相关字段应该为 0
        assertEq(tokensOwed0, 0, "tokensOwed0 should be 0 for new position");
        assertEq(tokensOwed1, 0, "tokensOwed1 should be 0 for new position");
    }

    /// @notice 测试 getPosition 函数 - 代币顺序无关
    function test_GetPosition_TokenOrderIndependent() public {
        vm.startPrank(alice);

        int24 lowerTick = -100;
        int24 upperTick = 100;
        uint128 liquidityToAdd = 1000000;

        pool.mint(
            alice,
            lowerTick,
            upperTick,
            liquidityToAdd,
            abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    payer: alice
                })
            )
        );

        vm.stopPrank();

        // 测试 1: tokenA < tokenB（正常顺序）
        UniswapV3Manager.GetPositionParams memory params1 = UniswapV3Manager
            .GetPositionParams({
            tokenA: address(token0),
            tokenB: address(token1),
            fee: TICK_SPACING_10,
            owner: alice,
            lowerTick: lowerTick,
            upperTick: upperTick
        });

        (uint128 liquidity1, , , , ) = manager.getPosition(params1);

        // 测试 2: tokenA > tokenB（反序）
        UniswapV3Manager.GetPositionParams memory params2 = UniswapV3Manager
            .GetPositionParams({
            tokenA: address(token1),  // 反序
            tokenB: address(token0),  // 反序
            fee: TICK_SPACING_10,
            owner: alice,
            lowerTick: lowerTick,
            upperTick: upperTick
        });

        (uint128 liquidity2, , , , ) = manager.getPosition(params2);

        // 两种顺序应该返回相同的结果
        assertEq(liquidity1, liquidity2, "liquidity should be same regardless of token order");
        assertEq(liquidity1, liquidityToAdd, "liquidity should match");
    }
}
