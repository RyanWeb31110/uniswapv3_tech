# UniswapV3 用户界面

这是一个基于 React 和 Ethers.js 构建的 UniswapV3 去中心化交易所演示应用。

## 功能特性

- 🔗 **MetaMask 集成** - 连接钱包并管理账户
- 💧 **添加流动性** - 向池子提供流动性并铸造仓位
- 🔄 **代币交换** - 在价格区间内进行代币兑换
- 📊 **实时事件** - 订阅并显示链上 Mint 和 Swap 事件

## 前置要求

1. **Node.js** (v14 或更高版本)
2. **MetaMask** 浏览器扩展
3. **Anvil** 本地以太坊节点（正在运行）
4. **已部署的合约**（参见主项目的部署说明）

## 安装依赖

```bash
# 进入 ui 目录
cd ui

# 安装依赖
npm install
# 或
yarn install
```

## 配置合约地址

在 `src/config/contracts.js` 文件中，确保合约地址与实际部署的地址一致：

```javascript
export const CONTRACTS = {
  WETH: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  USDC: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
  Pool: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
  Manager: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
};
```

这些地址可以从部署脚本的输出或 `broadcast/DeployDevelopment.s.sol/31337/run-latest.json` 文件中获取。

## 运行应用

```bash
npm start
# 或
yarn start
```

应用将在 `http://localhost:3000` 启动。

## 配置 MetaMask

### 1. 添加 Anvil 本地网络

1. 打开 MetaMask
2. 点击网络下拉列表
3. 点击"添加网络"
4. 填写以下信息：
   - 网络名称：`Anvil Local`
   - RPC URL：`http://localhost:8545`
   - 链 ID：`31337`
   - 货币符号：`ETH`
5. 保存并切换到新网络

### 2. 导入测试账户

1. 点击账户图标
2. 选择"导入账户"
3. 选择"私钥"
4. 粘贴 Anvil 默认账户的私钥：
   ```
   0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```
5. 点击导入

⚠️ **安全警告**：这是测试网络的私钥，仅用于本地开发。切勿在主网使用或向这些地址发送真实资产。

### 3. 添加代币

1. 切换到"资产"标签页
2. 点击"导入代币"
3. 选择"自定义代币"
4. 分别添加 WETH 和 USDC 的合约地址
5. MetaMask 会自动识别代币信息

### 4. 重置账户（如果需要）

如果重启了 Anvil 节点，可能需要重置 MetaMask 账户缓存：

1. 打开 MetaMask 设置
2. 选择"高级"
3. 点击"重置账户"
4. 确认操作

## 使用说明

### 连接钱包

1. 点击"连接 MetaMask"按钮
2. 在弹出窗口中选择账户并授权
3. 确认连接到 Anvil Local 网络

### 添加流动性

1. 确保已连接钱包并在正确的网络上
2. 应用会使用预设的参数（WETH 和 USDC 数量、Tick 范围等）
3. 点击"添加流动性"按钮
4. 在 MetaMask 中确认代币授权交易（如果需要）
5. 确认 Mint 交易
6. 等待交易完成

### 代币交换

1. 选择要交换的输入代币（WETH 或 USDC）
2. 输入交换数量（默认 0.01）
3. 点击"交换"按钮
4. 在 MetaMask 中确认授权（如果需要）
5. 确认 Swap 交易
6. 等待交易完成

### 查看事件

右侧的事件列表会实时显示所有 Mint 和 Swap 事件：
- 绿色标签表示 Mint 事件
- 蓝色标签表示 Swap 事件
- 点击事件可展开查看详细信息
- 点击"刷新"按钮可手动刷新事件列表

## 技术栈

- **React 19** - UI 框架
- **Ethers.js 5** - 以太坊库
- **MetaMask** - 钱包和签名者
- **CSS3** - 样式

## 项目结构

```
ui/
├── public/              # 静态资源
├── src/
│   ├── abi/            # 合约 ABI 文件
│   ├── components/     # React 组件
│   │   ├── WalletConnect.js    # 钱包连接
│   │   ├── AddLiquidity.js     # 添加流动性
│   │   ├── Swap.js             # 代币交换
│   │   └── EventFeed.js        # 事件订阅
│   ├── config/         # 配置文件
│   │   └── contracts.js        # 合约地址和 ABI
│   ├── contexts/       # React 上下文
│   │   └── MetaMaskContext.js  # MetaMask 状态管理
│   ├── App.js          # 主应用程序
│   ├── App.css         # 全局样式
│   └── index.js        # 入口文件
└── package.json        # 项目配置
```

## 常见问题

### 1. MetaMask 显示旧的余额

重启 Anvil 节点后，MetaMask 可能缓存旧的状态。解决方法：
- 打开 MetaMask 设置 > 高级 > 重置账户

### 2. 交易失败："insufficient funds"

可能的原因：
- 账户 ETH 余额不足（需要支付 Gas）
- 代币余额不足
- 未铸造测试代币（参见主项目的部署说明）

### 3. 无法连接到本地节点

确认：
- Anvil 节点正在运行（`anvil`）
- MetaMask 已添加本地网络配置
- RPC URL 正确：`http://localhost:8545`

### 4. 事件列表为空

可能的原因：
- 尚未执行任何交易
- 未连接到正确的网络
- 合约地址配置错误

## 开发和调试

### 查看控制台日志

应用在关键操作时会输出详细日志到浏览器控制台：
- 打开浏览器开发者工具（F12）
- 切换到"控制台"标签页
- 查看交易参数、事件信息等

### 修改流动性参数

编辑 `src/config/contracts.js` 文件中的 `LIQUIDITY_PARAMS`：

```javascript
export const LIQUIDITY_PARAMS = {
  amount0: '0.998976618347425280', // WETH 数量
  amount1: '5000',                  // USDC 数量
  lowerTick: 84222,                 // 价格下限
  upperTick: 86129,                 // 价格上限
  liquidity: '1517882343751509868544', // 流动性
};
```

## 构建生产版本

```bash
npm run build
# 或
yarn build
```

构建结果将输出到 `build/` 目录。

## 相关链接

- [主项目 GitHub](https://github.com/RyanWeb31110/uniswapv3_tech)
- [Uniswap V3 文档](https://docs.uniswap.org/)
- [Ethers.js 文档](https://docs.ethers.io/)
- [MetaMask 文档](https://docs.metamask.io/)

## 许可证

MIT
