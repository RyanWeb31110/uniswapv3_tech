#!/bin/bash

# 验证部署脚本
# 检查所有必要的文件和配置是否正确

set -e

echo "🔍 验证项目部署状态..."

# 检查项目结构
echo "📁 检查项目结构..."
required_files=(
    "src/UniswapV3Quoter.sol"
    "ui/src/components/EnhancedSwap.js"
    "ui/src/components/EnhancedSwap.css"
    "ui/src/abi/UniswapV3Quoter.json"
    "ui/ENHANCED_SWAP_README.md"
    "scripts/deploy-with-quoter.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - 文件不存在"
        exit 1
    fi
done

# 检查合约编译
echo "📦 检查合约编译..."
if forge build > /dev/null 2>&1; then
    echo "✅ 合约编译成功"
else
    echo "❌ 合约编译失败"
    exit 1
fi

# 检查前端构建
echo "🎨 检查前端构建..."
cd ui
if npm run build > /dev/null 2>&1; then
    echo "✅ 前端构建成功"
else
    echo "❌ 前端构建失败"
    exit 1
fi
cd ..

# 检查部署脚本权限
echo "🔧 检查部署脚本权限..."
if [ -x "scripts/deploy-with-quoter.sh" ]; then
    echo "✅ 部署脚本可执行"
else
    echo "⚠️  部署脚本不可执行，正在修复..."
    chmod +x scripts/deploy-with-quoter.sh
    echo "✅ 权限已修复"
fi

# 检查配置文件
echo "⚙️  检查配置文件..."
if grep -q "Quoter" ui/src/config/contracts.js; then
    echo "✅ Quoter 合约配置存在"
else
    echo "❌ Quoter 合约配置缺失"
    exit 1
fi

# 检查 App 组件集成
echo "🔗 检查组件集成..."
if grep -q "EnhancedSwap" ui/src/App.js; then
    echo "✅ 增强版交换组件已集成"
else
    echo "❌ 增强版交换组件未集成"
    exit 1
fi

# 检查文档
echo "📚 检查文档..."
if [ -f "ui/ENHANCED_SWAP_README.md" ] && [ -f "UPDATE_SUMMARY.md" ]; then
    echo "✅ 文档完整"
else
    echo "❌ 文档不完整"
    exit 1
fi

echo ""
echo "🎉 验证完成！所有检查都通过了。"
echo ""
echo "📋 下一步操作："
echo "   1. 启动 Anvil: anvil"
echo "   2. 部署合约: ./scripts/deploy-with-quoter.sh"
echo "   3. 启动前端: cd ui && npm start"
echo "   4. 开始使用增强版交换功能！"
echo ""
echo "📖 详细说明请查看："
echo "   - ui/ENHANCED_SWAP_README.md"
echo "   - UPDATE_SUMMARY.md"
