// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/lib/NFTRenderer.sol";
import "../src/lib/Strings.sol";
import "../src/lib/Base64.sol";

contract MockPool {
    address public token0;
    address public token1;
    uint24 public fee;

    constructor(address _token0, address _token1, uint24 _fee) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }
}

contract MockToken {
    string private _symbol;

    constructor(string memory symbol_) {
        _symbol = symbol_;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }
}

/// @title NFTRenderer 测试
/// @notice 测试 NFT 渲染器的各项功能
contract NFTRendererTest is Test {
    MockToken token0;
    MockToken token1;
    MockPool pool;

    function setUp() public {
        // 创建模拟代币
        token0 = new MockToken("WETH");
        token1 = new MockToken("USDC");

        // 创建模拟池子（费率 0.05%）
        pool = new MockPool(address(token0), address(token1), 500);
    }

    /// @notice 测试基本的渲染功能
    function testRender() public {
        // 调用渲染器
        string memory uri = NFTRenderer.render(
            NFTRenderer.RenderParams({
                pool: address(pool),
                owner: address(this),
                lowerTick: -600,
                upperTick: 600,
                fee: 500
            })
        );

        // 验证返回的是 Data URI
        assertTrue(bytes(uri).length > 0, "URI should not be empty");

        // 验证 Data URI 格式
        bytes memory uriBytes = bytes(uri);
        assertTrue(
            uriBytes[0] == 'd' &&
            uriBytes[1] == 'a' &&
            uriBytes[2] == 't' &&
            uriBytes[3] == 'a' &&
            uriBytes[4] == ':',
            "Should start with 'data:'"
        );

        // 输出 URI 便于手动验证
        console.log("Generated URI:");
        console.log(uri);
    }

    /// @notice 测试负数 Tick 的转换
    function testTickToText() public {
        assertEq(
            NFTRenderer.tickToText(-123),
            "-123",
            "Negative tick conversion failed"
        );

        assertEq(
            NFTRenderer.tickToText(456),
            "456",
            "Positive tick conversion failed"
        );

        assertEq(
            NFTRenderer.tickToText(0),
            "0",
            "Zero tick conversion failed"
        );
    }

    /// @notice 测试费率转换
    function testFeeToText() public {
        assertEq(
            NFTRenderer.feeToText(500),
            "0.05%",
            "Fee 500 conversion failed"
        );

        assertEq(
            NFTRenderer.feeToText(3000),
            "0.3%",
            "Fee 3000 conversion failed"
        );

        assertEq(
            NFTRenderer.feeToText(10000),
            "1%",
            "Fee 10000 conversion failed"
        );
    }
}
