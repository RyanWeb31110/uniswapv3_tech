#!/bin/bash

# 前端缓存问题修复脚本
# 解决 "BlockOutOfRangeError" 问题

echo "🔧 修复前端缓存问题..."

# 1. 检查 Anvil 是否运行
if ! pgrep -f "anvil" > /dev/null; then
    echo "❌ Anvil 节点未运行，请先启动 Anvil"
    echo "   运行: anvil"
    exit 1
fi

# 2. 检查区块高度
BLOCK_HEIGHT=$(cast block-number --rpc-url http://localhost:8545 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ 无法连接到 Anvil 节点"
    exit 1
fi

echo "✅ 当前区块高度: $BLOCK_HEIGHT"

# 3. 检查合约是否部署
WETH_CODE=$(cast code 0x5FbDB2315678afecb367f032d93F642f64180aa3 --rpc-url http://localhost:8545 2>/dev/null)
if [ ${#WETH_CODE} -lt 10 ]; then
    echo "❌ 合约未部署，正在重新部署..."
    forge script scripts/DeployDevelopment.s.sol:DeployDevelopment \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        --broadcast > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ 合约部署成功"
    else
        echo "❌ 合约部署失败"
        exit 1
    fi
else
    echo "✅ 合约已部署"
fi

# 4. 提供前端修复建议
echo ""
echo "🎯 前端修复步骤："
echo "1. 强制刷新浏览器页面 (Ctrl+Shift+R 或 Cmd+Shift+R)"
echo "2. 清除浏览器缓存："
echo "   - 打开开发者工具 (F12)"
echo "   - 右键点击刷新按钮"
echo "   - 选择 '清空缓存并硬性重新加载'"
echo "3. 重置 MetaMask 缓存："
echo "   - 在 MetaMask 中切换到其他网络"
echo "   - 再切换回 Anvil Local 网络"
echo "4. 如果问题仍然存在，重启浏览器"

echo ""
echo "🔍 调试信息："
echo "- 当前区块高度: $(cast block-number --rpc-url http://localhost:8545)"
echo "- WETH 合约: 0x5FbDB2315678afecb367f032d93F642f64180aa3"
echo "- Manager 合约: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
echo "- 前端地址: http://localhost:3000"

echo ""
echo "✅ 修复完成！现在可以尝试在前端添加流动性了。"
