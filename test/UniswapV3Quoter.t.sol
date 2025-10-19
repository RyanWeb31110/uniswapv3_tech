// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Quoter.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Manager.sol";
import "./ERC20Mintable.sol";

/// @title UniswapV3QuoterTest
/// @notice Quoter 合约的完整测试套件
/// @dev 使用 Foundry 测试框架验证 Quoter 合约的功能
contract UniswapV3QuoterTest is Test {
    // ============ 测试合约 ============
    
    UniswapV3Quoter quoter;
    UniswapV3Pool pool;
    UniswapV3Manager manager;
    ERC20Mintable token0;
    ERC20Mintable token1;
    
    // ============ 测试用户 ============
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    
    // ============ 测试常量 ============
    
    int24 constant MIN_TICK = -1000;
    int24 constant MAX_TICK = 1000;
    uint160 constant INITIAL_PRICE = 79228162514264337593543950336; // 1.0 in Q64.96
    
    function setUp() public {
        // 部署测试代币
        token0 = new ERC20Mintable("Token0", "TK0", 18);
        token1 = new ERC20Mintable("Token1", "TK1", 18);
        
        // 部署池合约
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            INITIAL_PRICE,
            0  // 初始 tick
        );
        
        // 部署管理合约
        manager = new UniswapV3Manager();
        
        // 部署 Quoter 合约
        quoter = new UniswapV3Quoter();
        
        // 给测试用户分配代币
        token0.mint(alice, 1000000 * 10**18);
        token1.mint(alice, 1000000 * 10**18);
        token0.mint(bob, 1000000 * 10**18);
        token1.mint(bob, 1000000 * 10**18);
    }
    
    // ============ 基础功能测试 ============
    
    /// @notice 测试基本的报价功能
    function testBasicQuote() public {
        // 1. 添加流动性
        _addLiquidity();
        
        // 2. 准备报价参数
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(pool),
            amountIn: 1 * 10**18, // 1 token0 (非常小的数量)
            zeroForOne: true       // token0 -> token1
        });
        
        // 3. 获取报价
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter.quote(params);
        
        // 4. 验证结果
        assertTrue(amountOut > 0, "Amount out should be positive");
        assertTrue(sqrtPriceX96After > 0, "Price should be positive");
        
        console.log("Amount out:", amountOut);
        console.log("Price after:", sqrtPriceX96After);
        console.log("Tick after:", tickAfter);
    }
    
    /// @notice 测试反向报价（token1 -> token0）
    function testReverseQuote() public {
        // 1. 添加流动性
        _addLiquidity();
        
        // 2. 准备报价参数
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(pool),
            amountIn: 1000 * 10**18, // 1000 token1
            zeroForOne: false        // token1 -> token0
        });
        
        // 3. 获取报价
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter.quote(params);
        
        // 4. 验证结果
        assertTrue(amountOut > 0, "Amount out should be positive");
        assertTrue(sqrtPriceX96After > 0, "Price should be positive");
        assertTrue(tickAfter != 0, "Tick should change");
        
        console.log("Reverse amount out:", amountOut);
        console.log("Reverse price after:", sqrtPriceX96After);
        console.log("Reverse tick after:", tickAfter);
    }
    
    /// @notice 测试报价与实际交换的一致性
    function testQuoteMatchesSwap() public {
        // 1. 添加流动性
        _addLiquidity();
        
        // 2. 获取报价
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(pool),
            amountIn: 1000 * 10**18,
            zeroForOne: true
        });
        
        (uint256 quotedAmountOut, , ) = quoter.quote(params);
        
        // 3. 执行实际交换
        uint256 balanceBefore = token1.balanceOf(alice);
        
        vm.startPrank(alice);
        token0.approve(address(manager), 1000 * 10**18);
        
        UniswapV3Pool.CallbackData memory callbackData = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: alice
        });
        
        manager.swap(
            address(pool),
            true,
            1000 * 10**18,
            abi.encode(callbackData)
        );
        vm.stopPrank();
        
        uint256 balanceAfter = token1.balanceOf(alice);
        uint256 actualAmountOut = balanceAfter - balanceBefore;
        
        // 4. 验证报价与实际结果一致
        assertEq(quotedAmountOut, actualAmountOut, "Quote should match actual swap");
        
        console.log("Quoted amount out:", quotedAmountOut);
        console.log("Actual amount out:", actualAmountOut);
    }
    
    // ============ 边界情况测试 ============
    
    /// @notice 测试零输入金额
    function testZeroAmountIn() public {
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(pool),
            amountIn: 0,
            zeroForOne: true
        });
        
        vm.expectRevert(UniswapV3Quoter.InvalidAmountIn.selector);
        quoter.quote(params);
    }
    
    /// @notice 测试无效的池地址
    function testInvalidPool() public {
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(0),
            amountIn: 1000 * 10**18,
            zeroForOne: true
        });
        
        vm.expectRevert(UniswapV3Quoter.InvalidPool.selector);
        quoter.quote(params);
    }
    
    /// @notice 测试大额交换
    function testLargeSwap() public {
        // 1. 添加大量流动性
        _addLiquidity(100000 * 10**18, 100000 * 10**18);
        
        // 2. 测试大额交换
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(pool),
            amountIn: 10000 * 10**18, // 10000 token0
            zeroForOne: true
        });
        
        (uint256 amountOut, , ) = quoter.quote(params);
        
        // 3. 验证结果合理
        assertTrue(amountOut > 0, "Large swap should work");
        assertTrue(amountOut < 10000 * 10**18, "Amount out should be less than amount in");
        
        console.log("Large swap amount out:", amountOut);
    }
    
    // ============ Fuzzing 测试 ============
    
    /// @notice 随机输入金额的报价测试
    function testFuzz_Quote(uint256 amountIn) public {
        // 限制输入范围
        vm.assume(amountIn > 0 && amountIn < 1000000 * 10**18);
        
        // 添加流动性
        _addLiquidity();
        
        // 准备报价参数
        UniswapV3Quoter.QuoteParams memory params = UniswapV3Quoter.QuoteParams({
            pool: address(pool),
            amountIn: amountIn,
            zeroForOne: true
        });
        
        // 获取报价（不应该 revert）
        (uint256 amountOut, , ) = quoter.quote(params);
        
        // 验证结果
        assertTrue(amountOut > 0, "Fuzz: Amount out should be positive");
    }
    
    // ============ 辅助函数 ============
    
    /// @notice 添加流动性
    function _addLiquidity() internal {
        _addLiquidity(10000 * 10**18, 10000 * 10**18);
    }
    
    /// @notice 添加指定数量的流动性
    function _addLiquidity(uint256 amount0, uint256 amount1) internal {
        vm.startPrank(alice);
        
        // 授权代币
        token0.approve(address(manager), amount0);
        token1.approve(address(manager), amount1);
        
        // 准备回调数据
        UniswapV3Pool.CallbackData memory callbackData = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: alice
        });
        
        // 添加流动性
        manager.mint(
            address(pool),
            MIN_TICK,
            MAX_TICK,
            1000000000000000000, // 流动性数量 (1e18)
            abi.encode(callbackData)
        );
        
        vm.stopPrank();
    }
}
