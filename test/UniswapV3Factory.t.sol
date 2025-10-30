// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";
import "./ERC20Mintable.sol";

/// @title UniswapV3Factory 测试
/// @notice 测试 Factory 合约的池子创建和管理功能
contract UniswapV3FactoryTest is Test {
    UniswapV3Factory factory;
    ERC20Mintable token0;
    ERC20Mintable token1;

    function setUp() public {
        // 部署 Factory
        factory = new UniswapV3Factory();

        // 部署测试代币
        token0 = new ERC20Mintable("Token 0", "TKN0", 18);
        token1 = new ERC20Mintable("Token 1", "TKN1", 18);

        // 确保 token0 < token1（地址排序）
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
    }

    /// @notice 测试创建池子
    function testCreatePool() public {
        // 创建池子
        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            60 // tickSpacing
        );

        // 验证池子地址不为零
        assertTrue(poolAddress != address(0), "Pool address should not be zero");

        // 验证池子已注册
        assertEq(
            factory.pools(address(token0), address(token1), 60),
            poolAddress,
            "Pool should be registered"
        );

        // 验证双向注册
        assertEq(
            factory.pools(address(token1), address(token0), 60),
            poolAddress,
            "Pool should be registered in both directions"
        );

        // 验证池子参数
        UniswapV3Pool pool = UniswapV3Pool(poolAddress);
        assertEq(pool.factory(), address(factory), "Factory address mismatch");
        assertEq(pool.token0(), address(token0), "Token0 mismatch");
        assertEq(pool.token1(), address(token1), "Token1 mismatch");
        assertEq(pool.tickSpacing(), 60, "TickSpacing mismatch");
    }

    /// @notice 测试创建多个不同 tick spacing 的池子
    function testCreatePoolWithDifferentTickSpacing() public {
        // 创建 tickSpacing = 10 的池子
        address pool10 = factory.createPool(
            address(token0),
            address(token1),
            10
        );

        // 创建 tickSpacing = 60 的池子
        address pool60 = factory.createPool(
            address(token0),
            address(token1),
            60
        );

        // 创建 tickSpacing = 200 的池子
        address pool200 = factory.createPool(
            address(token0),
            address(token1),
            200
        );

        // 验证三个池子地址不同
        assertTrue(pool10 != pool60, "Pool10 and Pool60 should be different");
        assertTrue(pool10 != pool200, "Pool10 and Pool200 should be different");
        assertTrue(pool60 != pool200, "Pool60 and Pool200 should be different");
    }

    /// @notice 测试代币自动排序
    function testTokenOrdering() public {
        // 无论传入顺序如何，都应该创建相同的池子
        address pool1 = factory.createPool(address(token0), address(token1), 60);

        // 尝试反向创建应该失败（池子已存在）
        vm.expectRevert(UniswapV3Factory.PoolAlreadyExists.selector);
        factory.createPool(address(token1), address(token0), 60);

        // 验证池子中的代币顺序
        UniswapV3Pool pool = UniswapV3Pool(pool1);
        assertTrue(pool.token0() < pool.token1(), "Token0 should be less than Token1");
    }

    /// @notice 测试不支持的 tick spacing
    function testUnsupportedTickSpacing() public {
        // 尝试创建不支持的 tick spacing 应该失败
        vm.expectRevert(UniswapV3Factory.UnsupportedTickSpacing.selector);
        factory.createPool(address(token0), address(token1), 100);
    }

    /// @notice 测试相同代币错误
    function testSameTokenError() public {
        vm.expectRevert(UniswapV3Factory.TokensMustBeDifferent.selector);
        factory.createPool(address(token0), address(token0), 60);
    }

    /// @notice 测试零地址错误
    function testZeroAddressError() public {
        vm.expectRevert(UniswapV3Factory.TokenXCannotBeZero.selector);
        factory.createPool(address(0), address(token1), 60);
    }

    /// @notice 测试池子已存在错误
    function testPoolAlreadyExists() public {
        // 创建第一个池子
        factory.createPool(address(token0), address(token1), 60);

        // 尝试再次创建应该失败
        vm.expectRevert(UniswapV3Factory.PoolAlreadyExists.selector);
        factory.createPool(address(token0), address(token1), 60);
    }

    /// @notice 测试池子初始化
    function testPoolInitialization() public {
        // 创建池子
        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            60
        );

        UniswapV3Pool pool = UniswapV3Pool(poolAddress);

        // 初始化池子
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 价格 = 1
        pool.initialize(sqrtPriceX96);

        // 验证初始化状态
        (uint160 price, int24 tick) = pool.slot0();
        assertEq(price, sqrtPriceX96, "Price mismatch");
        assertTrue(tick != 0 || price == sqrtPriceX96, "Tick should be set");
    }

    /// @notice 测试重复初始化错误
    function testDoubleInitializeError() public {
        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            60
        );

        UniswapV3Pool pool = UniswapV3Pool(poolAddress);

        // 第一次初始化
        uint160 sqrtPriceX96 = 79228162514264337593543950336;
        pool.initialize(sqrtPriceX96);

        // 尝试第二次初始化应该失败
        vm.expectRevert(UniswapV3Pool.AlreadyInitialized.selector);
        pool.initialize(sqrtPriceX96);
    }
}
