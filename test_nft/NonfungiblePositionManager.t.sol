// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NonfungiblePositionManager.sol";

/// @title NonfungiblePositionManager 测试合约
/// @notice 测试 NFT 仓位管理器的核心功能
contract NonfungiblePositionManagerTest is Test {
    NonfungiblePositionManager public manager;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public pool = address(0x123);

    function setUp() public {
        // 部署 NonfungiblePositionManager 合约
        manager = new NonfungiblePositionManager();

        // 设置测试账户余额
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    // ============ ERC721 元数据测试 ============

    /// @notice 测试 NFT 集合名称
    function test_Name() public view {
        assertEq(manager.name(), "Uniswap V3 Positions NFT-V1");
    }

    /// @notice 测试 NFT 集合符号
    function test_Symbol() public view {
        assertEq(manager.symbol(), "UNI-V3-POS");
    }

    // ============ 铸造测试 ============

    /// @notice 测试成功铸造 NFT
    function test_Mint_Success() public {
        vm.startPrank(alice);

        // 铸造 NFT
        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        // 验证 tokenId
        assertEq(tokenId, 1, "First token ID should be 1");

        // 验证所有权
        assertEq(manager.ownerOf(tokenId), alice, "Alice should own the token");

        // 验证余额
        assertEq(manager.balanceOf(alice), 1, "Alice should have 1 token");

        vm.stopPrank();
    }

    /// @notice 测试连续铸造多个 NFT
    function test_Mint_Multiple() public {
        vm.startPrank(alice);

        uint256 tokenId1 = manager.mint(pool, -600, 600, 1000);
        uint256 tokenId2 = manager.mint(pool, -1200, 1200, 2000);

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(manager.balanceOf(alice), 2);

        vm.stopPrank();
    }

    /// @notice 测试仓位信息是否正确保存
    function test_PositionData() public {
        vm.startPrank(alice);

        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        // 获取仓位信息
        (
            address savedPool,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowth0,
            uint256 feeGrowth1,
            uint128 owed0,
            uint128 owed1
        ) = manager.positions(tokenId);

        // 验证数据
        assertEq(savedPool, pool);
        assertEq(tickLower, -600);
        assertEq(tickUpper, 600);
        assertEq(liquidity, 1000);
        assertEq(feeGrowth0, 0);
        assertEq(feeGrowth1, 0);
        assertEq(owed0, 0);
        assertEq(owed1, 0);

        vm.stopPrank();
    }

    // ============ 转账测试 ============

    /// @notice 测试成功转账
    function test_Transfer_Success() public {
        // Alice 铸造 NFT
        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        // Alice 转给 Bob
        vm.prank(alice);
        manager.transferFrom(alice, bob, tokenId);

        // 验证所有权转移
        assertEq(manager.ownerOf(tokenId), bob);
        assertEq(manager.balanceOf(alice), 0);
        assertEq(manager.balanceOf(bob), 1);
    }

    /// @notice 测试未授权的转账应该失败
    function test_Transfer_RevertNotAuthorized() public {
        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        // Bob 尝试转移 Alice 的代币（未授权）
        vm.prank(bob);
        vm.expectRevert(NonfungiblePositionManager.NotAuthorized.selector);
        manager.transferFrom(alice, bob, tokenId);
    }

    /// @notice 测试转账到零地址应该失败
    function test_Transfer_RevertInvalidRecipient() public {
        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        vm.prank(alice);
        vm.expectRevert(NonfungiblePositionManager.InvalidRecipient.selector);
        manager.transferFrom(alice, address(0), tokenId);
    }

    // ============ 授权测试 ============

    /// @notice 测试单个代币授权
    function test_Approve_Success() public {
        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        // Alice 授权 Bob 操作该代币
        vm.prank(alice);
        manager.approve(bob, tokenId);

        // 验证授权
        assertEq(manager.getApproved(tokenId), bob);

        // Bob 可以转移该代币
        vm.prank(bob);
        manager.transferFrom(alice, bob, tokenId);

        assertEq(manager.ownerOf(tokenId), bob);
    }

    /// @notice 测试全局授权
    function test_SetApprovalForAll_Success() public {
        vm.prank(alice);
        uint256 tokenId1 = manager.mint(pool, -600, 600, 1000);

        vm.prank(alice);
        uint256 tokenId2 = manager.mint(pool, -1200, 1200, 2000);

        // Alice 授权 Bob 操作所有代币
        vm.prank(alice);
        manager.setApprovalForAll(bob, true);

        // 验证全局授权
        assertTrue(manager.isApprovedForAll(alice, bob));

        // Bob 可以转移 Alice 的所有代币
        vm.startPrank(bob);
        manager.transferFrom(alice, bob, tokenId1);
        manager.transferFrom(alice, bob, tokenId2);
        vm.stopPrank();

        assertEq(manager.balanceOf(bob), 2);
    }

    // ============ tokenURI 测试 ============

    /// @notice 测试 tokenURI 生成
    function test_TokenURI() public {
        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, -600, 600, 1000);

        string memory uri = manager.tokenURI(tokenId);

        // 验证返回的是 Data URI
        assertTrue(bytes(uri).length > 0, "URI should not be empty");

        // 验证前缀
        bytes memory prefix = bytes("data:application/json;base64,");
        bytes memory uriBytes = bytes(uri);

        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i], "URI should start with data:application/json;base64,");
        }

        // 输出 URI（用于手动验证）
        console.log("Token URI:");
        console.log(uri);
    }

    /// @notice 测试查询不存在的代币 URI 应该失败
    function test_TokenURI_RevertInvalidTokenId() public {
        vm.expectRevert(NonfungiblePositionManager.InvalidTokenId.selector);
        manager.tokenURI(999);
    }

    // ============ 边界情况测试 ============

    /// @notice 测试查询不存在的代币拥有者应该失败
    function test_OwnerOf_RevertInvalidTokenId() public {
        vm.expectRevert(NonfungiblePositionManager.InvalidTokenId.selector);
        manager.ownerOf(999);
    }

    /// @notice 测试查询零地址余额应该失败
    function test_BalanceOf_RevertInvalidOwner() public {
        vm.expectRevert("Invalid owner");
        manager.balanceOf(address(0));
    }

    // ============ Fuzzing 测试 ============

    /// @notice Fuzzing 测试：测试各种 Tick 范围
    function testFuzz_Mint_TickRange(int24 tickLower, int24 tickUpper) public {
        // 限制输入范围（避免无效的 Tick）
        vm.assume(tickLower < tickUpper);
        vm.assume(tickLower >= -887272);
        vm.assume(tickUpper <= 887272);

        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, tickLower, tickUpper, 1000);

        // 验证数据
        (, int24 savedLower, int24 savedUpper,,,,,) = manager.positions(tokenId);
        assertEq(savedLower, tickLower);
        assertEq(savedUpper, tickUpper);
    }

    /// @notice Fuzzing 测试：测试各种流动性数量
    function testFuzz_Mint_Liquidity(uint128 liquidity) public {
        vm.assume(liquidity > 0);

        vm.prank(alice);
        uint256 tokenId = manager.mint(pool, -600, 600, liquidity);

        (,,, uint128 savedLiquidity,,,,) = manager.positions(tokenId);
        assertEq(savedLiquidity, liquidity);
    }
}
