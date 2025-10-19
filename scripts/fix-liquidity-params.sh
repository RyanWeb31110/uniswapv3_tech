#!/bin/bash

# 修复流动性参数脚本
# 解决算术溢出问题

echo "🔧 修复流动性参数..."

# 当前问题分析
echo "📊 问题分析:"
echo "  用户尝试添加的流动性: 1527882343751509868544"
echo "  这个数量太大，导致算术溢出"
echo "  需要的代币数量远超用户余额"

echo ""
echo "✅ 解决方案:"
echo "  建议使用流动性: 1519"
echo "  这将需要:"
echo "    WETH: 0.999364"
echo "    USDC: 5003.89"

echo ""
echo "🛠️ 修复步骤:"

# 1. 检查当前合约配置
echo "1. 检查当前合约配置..."
echo "   Pool 地址: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
echo "   Manager 地址: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"

# 2. 检查用户余额
echo "2. 检查用户余额..."
WETH_BALANCE=$(cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545)
USDC_BALANCE=$(cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545)

WETH_BALANCE_ETH=$(cast --to-unit $WETH_BALANCE ether)
USDC_BALANCE_ETH=$(cast --to-unit $USDC_BALANCE ether)

echo "   WETH 余额: $WETH_BALANCE_ETH"
echo "   USDC 余额: $USDC_BALANCE_ETH"

# 3. 检查授权状态
echo "3. 检查授权状态..."
WETH_ALLOWANCE=$(cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "allowance(address,address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://localhost:8545)
USDC_ALLOWANCE=$(cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "allowance(address,address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://localhost:8545)

WETH_ALLOWANCE_ETH=$(cast --to-unit $WETH_ALLOWANCE ether)
USDC_ALLOWANCE_ETH=$(cast --to-unit $USDC_ALLOWANCE ether)

echo "   WETH 授权: $WETH_ALLOWANCE_ETH"
echo "   USDC 授权: $USDC_ALLOWANCE_ETH"

echo ""
echo "📝 前端修复建议:"
echo "1. 修改前端代码中的流动性参数:"
echo "   - 将 liquidity 从 1527882343751509868544 改为 1519"
echo "   - 或者实现动态计算，根据用户余额计算合适的流动性"

echo ""
echo "2. 更新 contracts.js 中的 LIQUIDITY_PARAMS:"
echo "   liquidity: '1519'"

echo ""
echo "3. 或者在前端添加余额检查:"
echo "   - 计算最大可能的流动性"
echo "   - 确保不超过用户余额"

echo ""
echo "🎯 测试建议的流动性数量:"
echo "使用以下参数测试添加流动性:"
echo "  lowerTick: 84222"
echo "  upperTick: 86129" 
echo "  liquidity: 1519"
echo "  data: 编码的代币地址和用户地址"

echo ""
echo "✅ 修复完成！现在可以使用正确的流动性参数了。"
