#!/bin/bash

# 快速部署脚本 - 解决 sender 问题
# 用于快速部署包含 Quoter 合约的完整系统

set -e

echo "🚀 快速部署 UniswapV3 系统（包含 Quoter 合约）"
echo "=============================================="
echo ""

# 检查环境
echo "🔍 检查环境..."

# 检查是否在项目根目录
if [ ! -f "foundry.toml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

# 检查 anvil 是否运行
if ! curl -s http://localhost:8545 > /dev/null; then
    echo "❌ 错误：请先启动 anvil 节点"
    echo "   运行命令：anvil"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# 编译合约
echo "📦 编译合约..."
forge build

# 部署合约
echo "🚀 部署合约..."
echo "   发送者: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "   RPC: http://localhost:8545"
echo ""

# 使用正确的参数部署
forge script scripts/DeployDevelopment.s.sol:DeployDevelopment \
    --broadcast \
    --rpc-url http://localhost:8545 \
    --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo ""
echo "✅ 部署完成！"
echo ""

# 显示合约地址
echo "📋 合约地址（从部署输出中复制）："
echo "   请从上面的输出中复制合约地址"
echo "   并更新 ui/src/config/contracts.js 文件"
echo ""

# 提供更新配置的指导
echo "🔧 手动更新配置："
echo "   1. 从上面的部署输出中复制合约地址"
echo "   2. 编辑 ui/src/config/contracts.js"
echo "   3. 更新 CONTRACTS 对象中的地址"
echo "   4. 特别注意更新 Quoter 地址"
echo ""

echo "🎉 部署完成！现在可以启动前端应用了。"
echo ""
echo "📋 下一步："
echo "   1. 更新前端配置文件中的合约地址"
echo "   2. 启动前端：cd ui && npm start"
echo "   3. 在浏览器中打开 http://localhost:3000"
echo ""
echo "📖 详细说明请查看：ui/ENHANCED_SWAP_README.md"
