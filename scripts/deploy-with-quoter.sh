#!/bin/bash

# UniswapV3 完整部署脚本（包含 Quoter 合约）
# 用于部署包含所有合约的完整系统

set -e

echo "🚀 开始部署 UniswapV3 完整系统..."

# 检查是否在项目根目录
if [ ! -f "foundry.toml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

# 检查 anvil 是否运行
echo "🔍 检查 Anvil 节点..."
if ! curl -s http://localhost:8545 > /dev/null; then
    echo "❌ 错误：请先启动 anvil 节点"
    echo "   运行命令：anvil"
    exit 1
fi

# 检查网络连接
echo "🌐 检查网络连接..."
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    echo "❌ 错误：无法连接到 Anvil 节点"
    exit 1
fi
echo "✅ Anvil 节点连接正常"

echo "✅ 检查通过，开始部署..."

# 编译合约
echo "📦 编译合约..."
forge build

# 部署合约
echo "🚀 部署合约..."
echo "   使用发送者地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "   连接到: http://localhost:8545"
echo ""

DEPLOY_OUTPUT=$(forge script scripts/DeployDevelopment.s.sol:DeployDevelopment --broadcast --rpc-url http://localhost:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 2>&1)

# 检查部署是否成功
if [ $? -ne 0 ]; then
    echo "❌ 部署失败！"
    echo "错误输出："
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# 提取合约地址
echo "📋 提取合约地址..."

# 使用 grep 和 sed 提取地址
WETH_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "WETH 地址:" | sed 's/.*WETH 地址: //')
USDC_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "USDC 地址:" | sed 's/.*USDC 地址: //')
POOL_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Pool 地址:" | sed 's/.*Pool 地址: //')
MANAGER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Manager 地址:" | sed 's/.*Manager 地址: //')
QUOTER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Quoter 地址:" | sed 's/.*Quoter 地址: //')

echo "✅ 合约部署完成！"
echo ""
echo "📋 合约地址："
echo "   WETH:   $WETH_ADDRESS"
echo "   USDC:   $USDC_ADDRESS"
echo "   Pool:   $POOL_ADDRESS"
echo "   Manager: $MANAGER_ADDRESS"
echo "   Quoter: $QUOTER_ADDRESS"
echo ""

# 更新前端配置文件
echo "🔧 更新前端配置..."

CONFIG_FILE="ui/src/config/contracts.js"

# 备份原文件
cp "$CONFIG_FILE" "$CONFIG_FILE.backup"

# 更新合约地址
sed -i.tmp "s/WETH: '.*'/WETH: '$WETH_ADDRESS'/" "$CONFIG_FILE"
sed -i.tmp "s/USDC: '.*'/USDC: '$USDC_ADDRESS'/" "$CONFIG_FILE"
sed -i.tmp "s/Pool: '.*'/Pool: '$POOL_ADDRESS'/" "$CONFIG_FILE"
sed -i.tmp "s/Manager: '.*'/Manager: '$MANAGER_ADDRESS'/" "$CONFIG_FILE"
sed -i.tmp "s/Quoter: '.*'/Quoter: '$QUOTER_ADDRESS'/" "$CONFIG_FILE"

# 清理临时文件
rm -f "$CONFIG_FILE.tmp"

echo "✅ 前端配置已更新"
echo ""

# 生成部署报告
echo "📊 生成部署报告..."
cat > DEPLOYMENT_REPORT.md << EOF
# UniswapV3 部署报告

## 部署时间
$(date)

## 合约地址

| 合约 | 地址 |
|------|------|
| WETH | \`$WETH_ADDRESS\` |
| USDC | \`$USDC_ADDRESS\` |
| Pool | \`$POOL_ADDRESS\` |
| Manager | \`$MANAGER_ADDRESS\` |
| Quoter | \`$QUOTER_ADDRESS\` |

## 网络信息
- 网络名称: Anvil Local
- 链 ID: 31337
- RPC URL: http://localhost:8545

## 下一步操作

1. 启动前端应用：
   \`\`\`bash
   cd ui
   npm install
   npm start
   \`\`\`

2. 在 MetaMask 中添加网络：
   - 网络名称: Anvil Local
   - RPC URL: http://localhost:8545
   - 链 ID: 31337
   - 货币符号: ETH

3. 导入测试账户（使用 anvil 提供的私钥）

4. 开始使用增强版交换功能！

## 功能特性

- ✅ 双向交换（WETH ↔ USDC）
- ✅ 实时报价更新
- ✅ 方向切换
- ✅ 响应式设计
- ✅ 错误处理
- ✅ 加载状态

## 注意事项

- 这是测试环境，请勿用于生产
- 确保 anvil 节点持续运行
- 合约地址已自动更新到前端配置
EOF

echo "✅ 部署报告已生成：DEPLOYMENT_REPORT.md"
echo ""

# 运行测试
echo "🧪 运行测试..."
if forge test --match-contract UniswapV3QuoterTest; then
    echo "✅ Quoter 合约测试通过"
else
    echo "⚠️  Quoter 合约测试失败，请检查部署"
fi

echo ""
echo "🎉 部署完成！"
echo ""
echo "📋 下一步操作："
echo "   1. 启动前端：cd ui && npm start"
echo "   2. 连接 MetaMask 到 Anvil Local 网络"
echo "   3. 开始使用增强版交换功能"
echo ""
echo "📖 详细说明请查看：ui/ENHANCED_SWAP_README.md"
echo "📊 部署报告：DEPLOYMENT_REPORT.md"
