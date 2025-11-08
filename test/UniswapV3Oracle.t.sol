// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestHelper.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Factory.sol";
import "../src/lib/TickMath.sol";

/// @title UniswapV3Oracle 测试
/// @notice 测试价格预言机功能
contract UniswapV3OracleTest is Test {
    using TestHelper for uint256;

    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;
    UniswapV3Factory factory;

    function setUp() public {
        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");

        factory = new UniswapV3Factory();

        uint24 fee = 500;
        int24 tickSpacing = 10;

        // 创建池子
        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            tickSpacing,
            fee
        );

        pool = UniswapV3Pool(poolAddress);

        // 初始化池子价格
        pool.initialize(uint256(5000).sqrtP());

        // 铸造代币
        token0.mint(address(this), 10000 ether);
        token1.mint(address(this), 10000 ether);

        // 添加初始流动性
        token0.approve(address(pool), 10000 ether);
        token1.approve(address(pool), 10000 ether);

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        pool.mint(
            address(this),
            uint256(4000).tick(),
            uint256(6000).tick(),
            1 ether,
            extra
        );
    }

    function encodeExtra(address token0_, address token1_, address payer_)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            UniswapV3Pool.CallbackData({
                token0: token0_,
                token1: token1_,
                payer: payer_
            })
        );
    }

    /// @notice 测试观测值初始化
    function testObservationInitialization() public view {
        (,, uint16 observationIndex, uint16 observationCardinality,
         uint16 observationCardinalityNext, ) = pool.slot0();

        assertEq(observationIndex, 0, "Initial observation index should be 0");
        assertEq(observationCardinality, 1, "Initial cardinality should be 1");
        assertEq(observationCardinalityNext, 1, "Initial cardinalityNext should be 1");
    }

    /// @notice 测试增加观测容量
    function testIncreaseObservationCardinality() public {
        pool.increaseObservationCardinalityNext(3);

        (,,,, uint16 observationCardinalityNext, ) = pool.slot0();
        assertEq(observationCardinalityNext, 3, "Cardinality next should be 3");
    }

    /// @notice 测试观测值记录
    function testObserve() public {
        // 扩展观测容量到 3
        pool.increaseObservationCardinalityNext(3);

        uint256 swapAmount = 0.01 ether;
        uint256 swapAmount2 = 0.005 ether;
        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        // 时间戳 2: 第一次交换
        vm.warp(2);
        pool.swap(address(this), false, swapAmount, uint256(6000).sqrtP(), extra);

        // 时间戳 7: 第二次交换
        vm.warp(7);
        pool.swap(address(this), true, swapAmount2, uint256(4000).sqrtP(), extra);

        // 时间戳 20: 第三次交换
        vm.warp(20);
        pool.swap(address(this), false, swapAmount, uint256(6000).sqrtP(), extra);

        // 查询观测值
        uint32[] memory secondsAgos = new uint32[](4);
        secondsAgos[0] = 0;   // 当前时刻（时间 20）
        secondsAgos[1] = 13;  // 13秒前（时间 7）
        secondsAgos[2] = 17;  // 17秒前（时间 3）
        secondsAgos[3] = 18;  // 18秒前（时间 2）

        int56[] memory tickCumulatives = pool.observe(secondsAgos);

        // 验证观测值存在
        assertTrue(tickCumulatives.length == 4, "Should return 4 observations");

        // 验证累计值是递减的（因为我们从当前往回查）
        assertTrue(tickCumulatives[0] >= tickCumulatives[1], "Current should >= 13s ago");
        assertTrue(tickCumulatives[1] >= tickCumulatives[2], "13s ago should >= 17s ago");
        assertTrue(tickCumulatives[2] >= tickCumulatives[3], "17s ago should >= 18s ago");

        console.log("Observation 0 (current):", uint256(tickCumulatives[0]));
        console.log("Observation 1 (13s ago):", uint256(tickCumulatives[1]));
        console.log("Observation 2 (17s ago):", uint256(tickCumulatives[2]));
        console.log("Observation 3 (18s ago):", uint256(tickCumulatives[3]));
    }

    /// @notice 测试插值计算
    function testObserveWithInterpolation() public {
        pool.increaseObservationCardinalityNext(5);

        uint256 swapAmount = 0.01 ether;
        uint256 swapAmount2 = 0.005 ether;
        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        // 时间戳 2: 第一次交换
        vm.warp(2);
        pool.swap(address(this), false, swapAmount, uint256(6000).sqrtP(), extra);

        // 时间戳 7: 第二次交换
        vm.warp(7);
        pool.swap(address(this), true, swapAmount2, uint256(4000).sqrtP(), extra);

        // 时间戳 20: 第三次交换
        vm.warp(20);
        pool.swap(address(this), false, swapAmount, uint256(6000).sqrtP(), extra);

        // 请求包含插值的观测值
        uint32[] memory secondsAgos = new uint32[](5);
        secondsAgos[0] = 0;   // 当前（时间 20）
        secondsAgos[1] = 5;   // 5秒前（时间 15，需要插值）
        secondsAgos[2] = 10;  // 10秒前（时间 10，需要插值）
        secondsAgos[3] = 15;  // 15秒前（时间 5，需要插值）
        secondsAgos[4] = 18;  // 18秒前（时间 2）

        int56[] memory tickCumulatives = pool.observe(secondsAgos);

        assertTrue(tickCumulatives.length == 5, "Should return 5 observations");

        console.log("Observation 0 (current):", uint256(tickCumulatives[0]));
        console.log("Observation 1 (5s ago, interpolated):", uint256(tickCumulatives[1]));
        console.log("Observation 2 (10s ago, interpolated):", uint256(tickCumulatives[2]));
        console.log("Observation 3 (15s ago, interpolated):", uint256(tickCumulatives[3]));
        console.log("Observation 4 (18s ago):", uint256(tickCumulatives[4]));

        // 计算各时间段的平均价格
        // TWAP 计算公式: (tickCumulative[i] - tickCumulative[i+1]) / (secondsAgo[i+1] - secondsAgo[i])
        for (uint i = 0; i < tickCumulatives.length - 1; i++) {
            int56 tickDelta = tickCumulatives[i] - tickCumulatives[i + 1];
            uint32 timeDelta = secondsAgos[i + 1] - secondsAgos[i];
            int24 avgTick = int24(tickDelta / int56(uint56(timeDelta)));

            console.log("Average tick from", secondsAgos[i+1], "to", secondsAgos[i], "seconds ago:", uint256(int256(avgTick)));
        }
    }

    /// @notice uniswapV3MintCallback 回调函数
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        }
        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    /// @notice uniswapV3SwapCallback 回调函数
    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
        }
        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
        }
    }
}
