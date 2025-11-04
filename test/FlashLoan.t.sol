// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Factory.sol";
import "../src/SimpleFlashBorrower.sol";
import "../src/interfaces/IUniswapV3MintCallback.sol";
import "./ERC20Mintable.sol";

/// @title 闪电贷测试合约
/// @notice 测试 Uniswap V3 闪电贷功能的完整性和安全性（包含手续费）
contract FlashLoanTest is Test, IUniswapV3MintCallback {

    // 合约实例
    UniswapV3Factory factory;
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
        // 部署 Factory
        factory = new UniswapV3Factory();

        // 部署代币
        token0 = new ERC20Mintable("Token0", "TK0", 18);
        token1 = new ERC20Mintable("Token1", "TK1", 18);

        // 确保 token0 < token1（地址排序）
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // 创建池子（手续费 0.3% = 3000，tickSpacing = 60）
        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            60,   // tickSpacing
            3000  // fee (0.3%)
        );
        pool = UniswapV3Pool(poolAddress);

        // 初始化池子价格：1:1
        // sqrtPriceX96 = sqrt(1) * 2^96 = 2^96 = 79228162514264337593543950336
        pool.initialize(79228162514264337593543950336);

        // 添加流动性（提供充足的代币供闪电贷使用）
        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);

        // 在当前价格附近添加流动性
        pool.mint(
            address(this),
            -600,  // lower tick (必须是 tickSpacing 的倍数)
            600,   // upper tick
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

    /// @notice 测试：成功的闪电贷（包含手续费）
    /// @dev 验证借款和还款流程的正确性，以及手续费的收取
    function testFlashSuccess() public {
        // 记录池子的初始余额
        uint256 poolBalance0Before = token0.balanceOf(address(pool));
        uint256 poolBalance1Before = token1.balanceOf(address(pool));

        console.log("Pool balance0 before:", poolBalance0Before);
        console.log("Pool balance1 before:", poolBalance1Before);

        // 准备：给借款人合约足够的代币用于归还（包含手续费）
        // 借出池子的一半代币
        uint256 borrowAmount0 = poolBalance0Before / 2;
        uint256 borrowAmount1 = poolBalance1Before / 2;

        // 计算手续费（模拟池子的计算逻辑）
        uint24 poolFee = pool.fee();
        // 向上取整：(amount * fee + 999999) / 1e6
        uint256 expectedFee0 = (borrowAmount0 * poolFee + 999999) / 1e6;
        uint256 expectedFee1 = (borrowAmount1 * poolFee + 999999) / 1e6;

        // 给借款人足够的代币：借款金额 + 手续费
        token0.mint(address(borrower), borrowAmount0 + expectedFee0);
        token1.mint(address(borrower), borrowAmount1 + expectedFee1);

        // 执行闪电贷
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            borrowAmount0,
            borrowAmount1
        );

        // 验证：池子余额应该增加手续费
        uint256 poolBalance0After = token0.balanceOf(address(pool));
        uint256 poolBalance1After = token1.balanceOf(address(pool));

        console.log("Pool balance0 after:", poolBalance0After);
        console.log("Pool balance1 after:", poolBalance1After);
        console.log("Fee0 paid:", poolBalance0After - poolBalance0Before);
        console.log("Fee1 paid:", poolBalance1After - poolBalance1Before);

        assertEq(poolBalance0After, poolBalance0Before + expectedFee0, "Pool balance0 should increase by fee");
        assertEq(poolBalance1After, poolBalance1Before + expectedFee1, "Pool balance1 should increase by fee");
    }

    /// @notice 测试：未归还闪电贷应该回滚
    /// @dev 验证安全机制的有效性
    function testFlashRevertWhenNotRepaid() public {
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 borrowAmount = poolBalance0 / 2;

        // 创建一个不归还代币的恶意合约
        NonReturningBorrower nonReturning = new NonReturningBorrower();

        // 预期交易回滚
        vm.expectRevert(UniswapV3Pool.FlashLoanNotPaid.selector);

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

        // 计算手续费
        uint24 poolFee = pool.fee();
        uint256 fee0 = (poolBalance0 * poolFee + 999999) / 1e6;
        uint256 fee1 = (poolBalance1 * poolFee + 999999) / 1e6;

        // 给借款人合约足够的代币（只需要手续费，因为借的会还回来）
        token0.mint(address(borrower), fee0);
        token1.mint(address(borrower), fee1);

        // 借出全部流动性
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            poolBalance0,
            poolBalance1
        );

        // 验证成功
        assertEq(
            token0.balanceOf(address(pool)),
            poolBalance0 + fee0,
            "Pool should have initial balance + fee for token0"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            poolBalance1 + fee1,
            "Pool should have initial balance + fee for token1"
        );
    }

    /// @notice 测试：只借一种代币
    /// @dev 验证可以只借 token0 或只借 token1
    function testFlashBorrowOnlyOneToken() public {
        uint256 poolBalance0Before = token0.balanceOf(address(pool));

        // 给借款人合约足够的代币
        uint256 borrowAmount = poolBalance0Before / 2;
        uint24 poolFee = pool.fee();
        uint256 expectedFee = (borrowAmount * poolFee + 999999) / 1e6;

        token0.mint(address(borrower), expectedFee);

        // 只借 token0
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            borrowAmount,  // 只借 token0
            0              // 不借 token1
        );

        uint256 poolBalance0After = token0.balanceOf(address(pool));

        assertEq(poolBalance0After, poolBalance0Before + expectedFee, "Token0 should be repaid with fee");
    }

    /// @notice 测试：闪电贷事件
    /// @dev 验证事件正确触发
    function testFlashEvent() public {
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 borrowAmount = poolBalance0 / 2;

        // 给借款人合约足够的代币
        uint24 poolFee = pool.fee();
        uint256 expectedFee = (borrowAmount * poolFee + 999999) / 1e6;
        token0.mint(address(borrower), expectedFee);

        // 期望事件被触发
        vm.expectEmit(true, true, false, true);
        emit Flash(address(borrower), address(borrower), borrowAmount, 0);

        // 执行闪电贷
        vm.prank(alice);
        borrower.executeFlashLoan(
            address(pool),
            borrowAmount,
            0
        );
    }

    /// @notice 测试：部分归还应该失败
    /// @dev 验证必须完全归还借款 + 手续费
    function testFlashPartialRepaymentFails() public {
        uint256 poolBalance0 = token0.balanceOf(address(pool));
        uint256 borrowAmount = poolBalance0 / 2;

        // 创建一个恶意借款人，只归还部分代币
        MaliciousBorrower malicious = new MaliciousBorrower();

        // 给恶意合约一些代币，但不够归还全部
        token0.mint(address(malicious), borrowAmount / 2);

        // 预期交易回滚
        vm.expectRevert(UniswapV3Pool.FlashLoanNotPaid.selector);

        malicious.executeMaliciousFlash(address(pool), borrowAmount);
    }

    /// @notice 测试：手续费计算的正确性
    /// @dev 验证向上取整的手续费计算
    function testFlashFeeCalculation() public {
        // 记录池子初始余额
        uint256 poolBalance0Before = token0.balanceOf(address(pool));

        // 借出 100 token0
        uint256 borrowAmount = 100 ether;

        // 预期手续费 = 100 * 3000 / 1e6 = 0.3 ether
        uint24 poolFee = pool.fee();
        uint256 expectedFee = (borrowAmount * poolFee + 999999) / 1e6;

        console.log("Borrow amount:", borrowAmount / 1 ether);
        console.log("Pool fee:", poolFee);
        console.log("Expected fee:", expectedFee);

        // 给借款人足够的代币支付手续费
        token0.mint(address(borrower), expectedFee);

        // 执行闪电贷
        borrower.executeFlashLoan(address(pool), borrowAmount, 0);

        // 验证：池子余额应该增加手续费金额
        uint256 poolBalance0After = token0.balanceOf(address(pool));
        assertEq(
            poolBalance0After,
            poolBalance0Before + expectedFee,
            "Pool balance should increase by fee amount"
        );

        console.log("Borrowed:", borrowAmount / 1 ether);
        console.log("Fee paid:", expectedFee / 1 ether);
        console.log("Pool profit:", (poolBalance0After - poolBalance0Before) / 1 ether);
    }

    /// @notice 测试：向上取整的手续费计算
    /// @dev 即使借出极小金额也要收取手续费
    function testFlashFeeRoundingUp() public {
        // 借出极小金额，测试向上取整
        uint256 tinyAmount = 1000; // 1000 wei

        // 预期手续费会向上取整
        uint24 poolFee = pool.fee();
        uint256 expectedFee = (tinyAmount * poolFee + 999999) / 1e6;

        // 给借款人足够的代币
        token0.mint(address(borrower), expectedFee);

        uint256 poolBalanceBefore = token0.balanceOf(address(pool));

        borrower.executeFlashLoan(address(pool), tinyAmount, 0);

        uint256 poolBalanceAfter = token0.balanceOf(address(pool));

        // 验证：即使是极小的借款也要收取手续费
        assertGt(
            poolBalanceAfter,
            poolBalanceBefore,
            "Even tiny amounts should incur fees"
        );

        assertEq(
            poolBalanceAfter - poolBalanceBefore,
            expectedFee,
            "Fee should match expected value"
        );
    }

    /// @notice Flash 事件定义（用于测试）
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1
    );
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

    function uniswapV3FlashCallback(
        uint256,
        uint256,
        bytes calldata
    ) external {
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

    function uniswapV3FlashCallback(
        uint256,
        uint256,
        bytes calldata
    ) external {
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
