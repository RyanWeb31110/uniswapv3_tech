#!/bin/bash

# 前端功能测试脚本

echo "🧪 测试前端功能..."

# 1. 检查前端服务状态
echo "1. 检查前端服务状态..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ 前端服务正常运行 (HTTP $FRONTEND_STATUS)"
else
    echo "❌ 前端服务异常 (HTTP $FRONTEND_STATUS)"
    exit 1
fi

# 2. 检查 Anvil 节点状态
echo "2. 检查 Anvil 节点状态..."
if pgrep -f "anvil" > /dev/null; then
    echo "✅ Anvil 节点正在运行"
else
    echo "❌ Anvil 节点未运行"
    exit 1
fi

# 3. 检查区块高度
echo "3. 检查区块高度..."
BLOCK_HEIGHT=$(cast block-number --rpc-url http://localhost:8545 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ 当前区块高度: $BLOCK_HEIGHT"
else
    echo "❌ 无法获取区块高度"
    exit 1
fi

# 4. 检查合约部署状态
echo "4. 检查合约部署状态..."
WETH_CODE=$(cast code 0x5FbDB2315678afecb367f032d93F642f64180aa3 --rpc-url http://localhost:8545 2>/dev/null)
if [ ${#WETH_CODE} -gt 10 ]; then
    echo "✅ WETH 合约已部署"
else
    echo "❌ WETH 合约未部署"
    exit 1
fi

MANAGER_CODE=$(cast code 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://localhost:8545 2>/dev/null)
if [ ${#MANAGER_CODE} -gt 10 ]; then
    echo "✅ Manager 合约已部署"
else
    echo "❌ Manager 合约未部署"
    exit 1
fi

# 5. 测试合约调用
echo "5. 测试合约调用..."
ALLOWANCE=$(cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "allowance(address,address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://localhost:8545 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ 合约调用测试成功 (allowance: $ALLOWANCE)"
else
    echo "❌ 合约调用测试失败"
    exit 1
fi

echo ""
echo "🎉 所有测试通过！前端应该可以正常工作了。"
echo ""
echo "📋 使用说明："
echo "1. 打开浏览器访问: http://localhost:3000"
echo "2. 连接 MetaMask 到 Anvil Local 网络"
echo "3. 尝试添加流动性或进行代币交换"
echo "4. 查看界面底部显示的区块高度信息"
echo ""
echo "🔧 如果遇到问题，可以运行:"
echo "   ./scripts/fix-frontend-cache.sh"
