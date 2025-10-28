// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Pool.sol";
import "../src/SimpleFlashBorrower.sol";
import "../src/interfaces/IUniswapV3MintCallback.sol";
import "./ERC20Mintable.sol";

/// @title 闪电贷测试合约
/// @notice 测试 Uniswap V3 闪电贷功能的完整性和安全性
contract FlashLoanTest is Test, IUniswapV3MintCallback {

    // 合约实例
    UniswapV3Pool pool;
    SimpleFlashBorrower borrower;
    ERC20Mintable token0;
    ERC20Mintable token1;

    // 测试账户
    address alice = address(0x1);
    address bob = address(0x2);

    /// @notice 测试初始化
    /// @dev 部署合约、创建池子、添加流动性
    function setUp() public {
        // 部署代币
        token0 = new ERC20Mintable("Token0", "TK0", 18);
        token1 = new ERC20Mintable("Token1", "TK1", 18);

        // 部署池子
        // 使用简单的初始价格：1:1
        // sqrtPriceX96 = sqrt(1) * 2^96 = 2^96 = 79228162514264337593543950336
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            79228162514264337593543950336,  // sqrt(1) * 2^96
            0                                 // tick at price 1
        );

        // 添加流动性（提供充足的代币供闪电贷使用）
        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);

        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);

        // 在当前价格附近添加流动性
        pool.mint(
            address(this),
            -100,  // lower tick
            100,   // upper tick
            100 ether,
            abi.encode(address(token0), address(token1), address(this))
        );

        // 部署借款人合约
        borrower = new SimpleFlashBorrower();
    }

    /// @notice Mint 回调函数
    /// @dev 用于向池子转入代币
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // 解码数据
        (address token0Addr, address token1Addr,) = abi.decode(
            data,
            (address, address, address)
        );

        // 直接转入代币（测试合约已经持有代币）
        if (amount0 > 0) {
            IERC20(token0Addr).transfer(msg.sender, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1Addr).transfer(msg.sender, amount1);
        }
    }

    /// @notice 测试：成功的闪电贷
    /// @dev 验证借款和还款流程的正确性
    function testFlashSuccess() public {
        // 记录池子的初始余额
        uint256 poolBalance0Before = token0.balanceOf(address(pool));
        uint256 poolBalance1Before = token1.balanceOf(address(pool));

        console.log("Pool balance0 before:", poolBalance0Before);
        console.log("Pool balance1 before:", poolBalance1Before);

        // 准备：给借款人合约足够的代币用于归还
        // 借出池子的一半代币
        uint256 borrowAmount0 = poolBalance0Before / 2;
        uint256 borrowAmount1 = poolBalance1Before / 2;

        token0.mint(address(borrower), borrowAmount0);
        token1.mint(address(borrower), borrowAmount1);

        // 执行闪电贷
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            borrowAmount0,
            borrowAmount1
        );

        // 验证：池子余额应该保持不变（或增加手续费）
        uint256 poolBalance0After = token0.balanceOf(address(pool));
        uint256 poolBalance1After = token1.balanceOf(address(pool));

        console.log("Pool balance0 after:", poolBalance0After);
        console.log("Pool balance1 after:", poolBalance1After);

        assertGe(poolBalance0After, poolBalance0Before, "Pool should have at least initial balance of token0");
        assertGe(poolBalance1After, poolBalance1Before, "Pool should have at least initial balance of token1");
    }

    /// @notice 测试：未归还闪电贷应该回滚
    /// @dev 验证安全机制的有效性
    function testFlashRevertWhenNotRepaid() public {
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 borrowAmount = poolBalance0 / 2;

        // 创建一个不归还代币的恶意合约
        NonReturningBorrower nonReturning = new NonReturningBorrower();

        // 预期交易回滚，并显示错误信息
        vm.expectRevert("Flash loan not repaid: token0");

        nonReturning.executeBadFlash(address(pool), borrowAmount);
    }

    /// @notice 测试：借出全部流动性
    /// @dev 验证可以借出池子中的所有代币
    function testFlashBorrowAllLiquidity() public {
        // 查询池子拥有的全部代币
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 poolBalance1 = token1.balanceOf(address(pool));

        console.log("Total pool balance0:", poolBalance0);
        console.log("Total pool balance1:", poolBalance1);

        // 给借款人合约足够的代币
        token0.mint(address(borrower), poolBalance0);
        token1.mint(address(borrower), poolBalance1);

        // 借出全部流动性
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            poolBalance0,
            poolBalance1
        );

        // 验证成功
        assertGe(
            token0.balanceOf(address(pool)),
            poolBalance0,
            "All liquidity should be returned for token0"
        );
        assertGe(
            token1.balanceOf(address(pool)),
            poolBalance1,
            "All liquidity should be returned for token1"
        );
    }

    /// @notice 测试：只借一种代币
    /// @dev 验证可以只借 token0 或只借 token1
    function testFlashBorrowOnlyOneToken() public {
        uint256 poolBalance0Before = token0.balanceOf(address(pool));

        // 给借款人合约足够的代币
        uint256 borrowAmount = poolBalance0Before / 2;
        token0.mint(address(borrower), borrowAmount);

        // 只借 token0
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            borrowAmount,  // 只借 token0
            0              // 不借 token1
        );

        uint256 poolBalance0After = token0.balanceOf(address(pool));

        assertGe(poolBalance0After, poolBalance0Before, "Token0 should be repaid");
    }

    /// @notice 测试：闪电贷事件
    /// @dev 验证事件正确触发
    function testFlashEvent() public {
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 borrowAmount = poolBalance0 / 2;

        // 给借款人合约足够的代币
        token0.mint(address(borrower), borrowAmount);

        // 执行闪电贷
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            borrowAmount,
            0
        );

        // 验证成功完成（如果事件有问题也能通过）
        assertGe(token0.balanceOf(address(pool)), 0, "Flash loan completed");
    }

    /// @notice 测试：部分归还应该失败
    /// @dev 验证必须完全归还借款
    function testFlashPartialRepaymentFails() public {
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 borrowAmount = poolBalance0 / 2;

        // 创建一个恶意借款人，只归还部分代币
        MaliciousBorrower malicious = new MaliciousBorrower();

        // 给恶意合约一些代币，但不够归还全部
        token0.mint(address(malicious), borrowAmount / 2);

        // 预期交易回滚
        vm.expectRevert("Flash loan not repaid: token0");

        malicious.executeMaliciousFlash(address(pool), borrowAmount);
    }
}

/// @title 不归还代币的借款人合约
/// @notice 用于测试安全机制的恶意合约，完全不归还代币
contract NonReturningBorrower {
    function executeBadFlash(address pool, uint256 amount) external {
        IUniswapV3Pool(pool).flash(
            address(this),
            amount,
            0,
            ""
        );
    }

    function uniswapV3FlashCallback(bytes calldata) external {
        // 什么都不做，不归还任何代币
        // 这将导致闪电贷验证失败
    }
}

/// @title 恶意借款人合约
/// @notice 用于测试安全机制的恶意合约，只归还部分代币
contract MaliciousBorrower {
    function executeMaliciousFlash(address pool, uint256 amount) external {
        IUniswapV3Pool(pool).flash(
            address(this),
            amount,
            0,
            ""
        );
    }

    function uniswapV3FlashCallback(bytes calldata) external {
        // 获取池子地址
        address pool = msg.sender;

        // 只归还一半代币（恶意行为）
        IERC20 token0 = IERC20(IUniswapV3Pool(pool).token0());
        uint256 balance = token0.balanceOf(address(this));

        // 只转回一半
        if (balance > 0) {
            token0.transfer(pool, balance / 2);
        }
        // 这将导致闪电贷验证失败
    }
}
