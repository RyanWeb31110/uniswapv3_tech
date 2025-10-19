// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Manager.sol";
import "../src/UniswapV3Quoter.sol";
import "../test/ERC20Mintable.sol";

/**
 * @title DeployDevelopment
 * @notice 本地开发环境部署脚本
 * @dev 部署池合约、管理合约和测试代币
 */
contract DeployDevelopment is Script {
    
    /**
     * @notice 部署脚本的主入口函数
     * @dev Foundry 会自动调用这个 run() 函数
     */
    function run() public {
        // 部署参数定义
        uint256 wethBalance = 1 ether;      // 部署者的 WETH 初始余额
        uint256 usdcBalance = 5042 ether;   // 部署者的 USDC 初始余额
        int24 currentTick = 85176;          // 初始价格 Tick
        uint160 currentSqrtP = 5602277097478614198912276234240; // 初始平方根价格
        
        // 开始广播交易
        vm.startBroadcast();
        
        // 步骤 1: 部署 ERC20 代币
        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);
        
        // 步骤 2: 部署池合约
        UniswapV3Pool pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            currentSqrtP,
            currentTick
        );
        
        // 步骤 3: 部署管理合约
        UniswapV3Manager manager = new UniswapV3Manager();
        
        // 步骤 4: 部署 Quoter 合约
        UniswapV3Quoter quoter = new UniswapV3Quoter();
        
        // 步骤 5: 为部署者铸造测试代币
        // msg.sender 是发起广播交易的地址
        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);
        
        // 停止广播
        vm.stopBroadcast();
        
        // 打印部署结果
        console.log(unicode"=== 部署成功 ===");
        console.log(unicode"WETH 地址:", address(token0));
        console.log(unicode"USDC 地址:", address(token1));
        console.log(unicode"Pool 地址:", address(pool));
        console.log(unicode"Manager 地址:", address(manager));
        console.log(unicode"Quoter 地址:", address(quoter));
    }
}

