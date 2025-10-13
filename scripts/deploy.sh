#!/bin/bash

# UniswapV3 一键部署脚本
# 使用方法: ./scripts/deploy.sh

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}\n"
}

# 检查 Anvil 是否在运行
check_anvil() {
    print_info "检查 Anvil 是否在运行..."
    if curl -s -X POST -H 'Content-Type: application/json' \
        --data '{"id":1,"jsonrpc":"2.0","method":"eth_chainId"}' \
        http://127.0.0.1:8545 > /dev/null 2>&1; then
        print_success "Anvil 正在运行"
        return 0
    else
        print_error "Anvil 未运行！"
        print_warning "请在另一个终端运行: anvil --code-size-limit 50000"
        return 1
    fi
}

# 设置环境变量
setup_env() {
    print_header "设置环境变量"
    
    # 使用 Anvil 默认的第一个测试私钥
    export PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}
    export RPC_URL=${RPC_URL:-http://localhost:8545}
    
    print_info "私钥: ${PRIVATE_KEY:0:10}...${PRIVATE_KEY: -10}"
    print_info "RPC URL: $RPC_URL"
}

# 编译合约
compile_contracts() {
    print_header "编译合约"
    
    if forge build; then
        print_success "合约编译成功"
        return 0
    else
        print_error "合约编译失败"
        return 1
    fi
}

# 部署合约
deploy_contracts() {
    print_header "部署合约"
    
    print_info "开始部署..."
    
    if forge script scripts/DeployDevelopment.s.sol \
        --broadcast \
        --fork-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --code-size-limit 50000 \
        -vv; then
        print_success "合约部署成功"
        return 0
    else
        print_error "合约部署失败"
        return 1
    fi
}

# 提取合约地址（从最新的部署记录中）
extract_addresses() {
    print_header "提取合约地址"
    
    local broadcast_file="broadcast/DeployDevelopment.s.sol/31337/run-latest.json"
    
    if [ ! -f "$broadcast_file" ]; then
        print_warning "未找到部署记录文件"
        print_info "请从部署输出中手动复制地址"
        return 1
    fi
    
    print_success "找到部署记录"
    print_info "从 $broadcast_file 提取地址"
    
    # 提取合约地址（需要 jq 工具）
    if command -v jq &> /dev/null; then
        echo ""
        echo "请将以下命令复制并执行以设置环境变量："
        echo ""
        echo "export WETH=<从输出中复制 WETH 地址>"
        echo "export USDC=<从输出中复制 USDC 地址>"
        echo "export POOL=<从输出中复制 Pool 地址>"
        echo "export MANAGER=<从输出中复制 Manager 地址>"
        echo "export USER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        echo ""
    else
        print_info "提示: 安装 jq 工具可自动提取地址"
    fi
}

# 显示验证命令
show_verification_commands() {
    print_header "验证部署"
    
    echo "使用以下命令验证部署（需要先设置环境变量）："
    echo ""
    echo "# 检查 WETH 余额"
    echo "cast call \$WETH \"balanceOf(address)\" \$USER --ether"
    echo ""
    echo "# 检查 USDC 余额"
    echo "cast call \$USDC \"balanceOf(address)\" \$USER --ether"
    echo ""
    echo "# 检查池子状态"
    echo "cast call \$POOL \"slot0()\" | xargs cast --abi-decode \"a()(uint160,int24)\""
    echo ""
}

# 主函数
main() {
    print_header "UniswapV3 部署脚本"
    
    # 检查 Anvil
    if ! check_anvil; then
        exit 1
    fi
    
    # 设置环境变量
    setup_env
    
    # 编译合约
    if ! compile_contracts; then
        exit 1
    fi
    
    # 部署合约
    if ! deploy_contracts; then
        exit 1
    fi
    
    # 提取地址
    extract_addresses
    
    # 显示验证命令
    show_verification_commands
    
    print_success "部署流程完成！"
    print_info "查看详细文档: docs/1FirstSwap/09-合约部署与本地测试.md"
}

# 运行主函数
main "$@"

