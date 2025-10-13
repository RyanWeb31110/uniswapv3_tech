# 部署指南

本文档提供快速部署和测试 UniswapV3 合约的步骤。

## 快速开始

### 1. 启动本地节点

在一个终端窗口中运行：

```bash
anvil --code-size-limit 50000
```

记下输出的第一个账户信息：
- 地址：`0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
- 私钥：`0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

### 2. 设置环境变量

在另一个终端窗口中：

```bash
# 设置私钥
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 设置 RPC URL
export RPC_URL=http://localhost:8545
```

### 3. 编译合约

```bash
forge build
```

### 4. 运行测试（可选）

```bash
forge test -vv
```

### 5. 部署合约

```bash
forge script scripts/DeployDevelopment.s.sol \
  --broadcast \
  --fork-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --code-size-limit 50000 \
  -vv
```

### 6. 记录部署地址

从输出中复制合约地址并保存为环境变量：

```bash
export WETH=0x5FbDB2315678afecb367f032d93F642f64180aa3
export USDC=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export POOL=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
export MANAGER=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
export USER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

> ⚠️ **注意**：你的合约地址可能与上面的示例不同，请使用实际部署输出的地址。

## 验证部署

### 检查代币余额

```bash
# 查询 WETH 余额（注意：cast call 不支持 --ether，需要用管道）
cast call $WETH "balanceOf(address)" $USER | cast --from-wei

# 查询 USDC 余额
cast call $USDC "balanceOf(address)" $USER | cast --from-wei
```

预期输出：
- WETH: `1.000000000000000000`
- USDC: `5042.000000000000000000`

### 检查池子状态

```bash
# 查询当前价格和 Tick
cast call $POOL "slot0()" | xargs cast --abi-decode "a()(uint160,int24)"
```

预期输出：
```
5602277097478614198912276234240
85176
```

### 检查池子的代币地址

```bash
cast call $POOL "token0()"
cast call $POOL "token1()"
```

## 测试合约交互

### 1. 授权 Manager 使用代币

```bash
# 授权 WETH
cast send $WETH "approve(address,uint256)" $MANAGER $(cast --to-wei 1) \
  --private-key $PRIVATE_KEY

# 授权 USDC
cast send $USDC "approve(address,uint256)" $MANAGER $(cast --to-wei 5000) \
  --private-key $PRIVATE_KEY
```

### 2. 提供流动性

```bash
# 首先编码回调数据
DATA=$(cast abi-encode "f(address,address,address)" $WETH $USDC $USER)

# 提供流动性（使用正确的流动性值）
cast send $MANAGER "mint(address,int24,int24,uint128,bytes)" \
  $POOL \
  84222 \
  86129 \
  1517882343751509868544 \
  $DATA \
  --private-key $PRIVATE_KEY
```

> **重要**：流动性值 `1517882343751509868544` 是通过 `python3 scripts/unimath.py` 计算得出的，不要随意修改。

### 3. 执行 Swap

```bash
# 重新授权 USDC（之前的额度已被 mint 消耗）
cast send $USDC "approve(address,uint256)" $MANAGER $(cast --to-wei 42) \
  --private-key $PRIVATE_KEY

# 用 42 USDC 买入 WETH
cast send $MANAGER "swap(address,bytes)" \
  $POOL \
  $DATA \
  --private-key $PRIVATE_KEY
```

### 4. 查看余额变化

```bash
cast call $WETH "balanceOf(address)" $USER | cast --from-wei
cast call $USDC "balanceOf(address)" $USER | cast --from-wei
```

## 常用命令

### 查询链 ID

```bash
cast chain-id
```

### 查询账户余额

```bash
cast balance $USER --ether
```

### 查看区块号

```bash
cast block-number
```

### 查看交易回执

```bash
cast receipt <交易哈希>
```

### 查看合约 ABI

```bash
forge inspect UniswapV3Pool abi
forge inspect UniswapV3Manager abi
```

## 故障排除

### 问题：合约大小超限

```bash
Error: contract size exceeds 24576 bytes
```

**解决方案**：确保在 `anvil` 和 `forge script` 命令中都添加 `--code-size-limit 50000`

### 问题：Gas 不足

```bash
Error: insufficient funds for gas * price + value
```

**解决方案**：
1. 确保使用正确的私钥
2. 检查账户余额：`cast balance $USER --ether`
3. 重启 Anvil 节点

### 问题：Nonce 不匹配

```bash
Error: nonce too low
```

**解决方案**：重启 Anvil 节点（Ctrl+C 然后重新运行 `anvil --code-size-limit 50000`）

### 问题：找不到合约

```bash
Error: contract source info format must be `<path>:<contractname>` or `<contractname>`
```

**解决方案**：
1. 确保脚本文件存在：`ls scripts/DeployDevelopment.s.sol`
2. 运行 `forge build` 重新编译
3. 检查脚本文件语法是否正确

### 问题：环境变量未设置

```bash
error: invalid value 'balanceOf(address)' for '[TO]': invalid string length
```

**解决方案**：检查并设置环境变量
```bash
# 检查
echo "WETH: $WETH"

# 从部署记录提取地址
cat broadcast/DeployDevelopment.s.sol/31337/run-latest.json | \
  python3 -c "import sys, json; data = json.load(sys.stdin); \
  [print(f\"{tx.get('contractName', 'Unknown'):20s} {tx.get('contractAddress', 'N/A')}\") \
  for tx in data.get('transactions', []) if tx.get('transactionType') == 'CREATE']"

# 设置环境变量
export WETH=<地址>
export USDC=<地址>
export POOL=<地址>
export MANAGER=<地址>
```

### 问题：cast call 使用 --ether 报错

```bash
error: unexpected argument '--ether' found
```

**解决方案**：`cast call` 不支持 `--ether`，使用管道
```bash
# 错误
cast call $WETH "balanceOf(address)" $USER --ether

# 正确
cast call $WETH "balanceOf(address)" $USER | cast --from-wei
```

### 问题：mint/swap execution reverted

```bash
Error: Failed to estimate gas: execution reverted
```

**常见原因**：
1. **未授权代币**
   ```bash
   # 检查授权
   cast call $WETH "allowance(address,address)" $USER $MANAGER | cast --from-wei
   
   # 授权
   cast send $WETH "approve(address,uint256)" $MANAGER $(cast --to-wei 1) \
     --private-key $PRIVATE_KEY
   ```

2. **授权额度已用完**
   - mint 会消耗授权额度
   - swap 前需要重新授权

3. **回调数据错误**
   ```bash
   # 错误：使用空 bytes
   ... 0x ...
   
   # 正确：编码回调数据
   DATA=$(cast abi-encode "f(address,address,address)" $WETH $USDC $USER)
   ... $DATA ...
   ```

4. **流动性值不正确**
   - 使用 `python3 scripts/unimath.py` 计算正确的值
   - 不要随意使用小数值

## 一键部署脚本

创建 `scripts/deploy.sh` 文件：

```bash
#!/bin/bash

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 设置私钥
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://localhost:8545

echo -e "${YELLOW}开始部署...${NC}"

# 编译
echo -e "${GREEN}1. 编译合约${NC}"
forge build

# 部署
echo -e "${GREEN}2. 部署合约${NC}"
forge script scripts/DeployDevelopment.s.sol \
  --broadcast \
  --fork-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --code-size-limit 50000 \
  -vv

echo -e "${YELLOW}部署完成！${NC}"
echo -e "${YELLOW}请从输出中复制合约地址并设置环境变量${NC}"
```

使脚本可执行：

```bash
chmod +x scripts/deploy.sh
```

运行：

```bash
./scripts/deploy.sh
```

## 参考文档

- [Foundry Book](https://book.getfoundry.sh/)
- [Cast 命令参考](https://book.getfoundry.sh/reference/cast/)
- [Anvil 参考](https://book.getfoundry.sh/reference/anvil/)
- [详细教程](docs/1FirstSwap/09-合约部署与本地测试.md)

