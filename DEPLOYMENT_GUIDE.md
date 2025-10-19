# 🚀 UniswapV3 系统部署指南

## 📋 概述

本指南将帮助您完整部署 UniswapV3 系统，包括核心合约、Quoter 合约和前端应用。

## 🛠️ 环境要求

- Node.js 16+
- Foundry (forge, anvil)
- Git

## 📦 快速部署

### 1. 启动本地节点

```bash
# 在第一个终端中启动 Anvil
anvil
```

### 2. 部署合约

```bash
# 在第二个终端中运行部署脚本
./scripts/quick-deploy.sh
```

### 3. 启动前端应用

```bash
# 在第三个终端中启动前端
cd ui && npm start
```

## 📋 部署结果

### 合约地址

根据最新部署，合约地址如下：

```javascript
export const CONTRACTS = {
  WETH: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  USDC: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
  Pool: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
  Manager: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
  Quoter: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
};
```

### 部署日志

```
=== 部署成功 ===
WETH 地址: 0x5FbDB2315678afecb367f032d93F642f64180aa3
USDC 地址: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Pool 地址: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
Manager 地址: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
Quoter 地址: 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
```

## 🎯 功能验证

### 1. 基础功能

- ✅ 代币铸造和转账
- ✅ 流动性添加和移除
- ✅ 基础代币交换
- ✅ 事件监听和显示

### 2. 增强功能

- ✅ 双向代币交换
- ✅ 实时价格查询
- ✅ 交换方向切换
- ✅ 防抖优化
- ✅ 错误处理

## 🔧 故障排除

### 常见问题

1. **部署失败：sender 错误**
   ```bash
   # 解决方案：使用 quick-deploy.sh 脚本
   ./scripts/quick-deploy.sh
   ```

2. **前端连接失败**
   ```bash
   # 检查 Anvil 是否运行
   curl -s http://localhost:8545
   
   # 检查合约地址是否正确
   cat ui/src/config/contracts.js
   ```

3. **MetaMask 连接问题**
   - 确保网络设置为 Anvil Local (Chain ID: 31337)
   - 确保 RPC URL 为 http://localhost:8545
   - 导入测试账户私钥

### 测试账户

Anvil 默认测试账户：
- 地址: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- 私钥: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

## 📖 使用说明

### 1. 连接钱包

1. 打开 http://localhost:3000
2. 点击"连接钱包"按钮
3. 在 MetaMask 中确认连接

### 2. 添加流动性

1. 在"添加流动性"部分输入金额
2. 点击"添加流动性"按钮
3. 在 MetaMask 中确认交易

### 3. 执行交换

1. 在"代币交换"部分输入交换金额
2. 点击"交换"按钮
3. 在 MetaMask 中确认交易

### 4. 使用增强版交换

1. 在"增强版代币交换"部分输入金额
2. 系统会自动显示实时报价
3. 可以切换交换方向
4. 点击"执行交换"按钮

## 🎉 成功标志

部署成功后，您应该能够：

1. ✅ 在浏览器中访问 http://localhost:3000
2. ✅ 连接 MetaMask 钱包
3. ✅ 添加流动性到池子
4. ✅ 执行代币交换
5. ✅ 查看实时价格报价
6. ✅ 在事件流中看到交易记录

## 📚 相关文档

- [增强版交换功能说明](ui/ENHANCED_SWAP_README.md)
- [项目更新总结](UPDATE_SUMMARY.md)
- [技术实现文档](docs/)

## 🆘 获取帮助

如果遇到问题，请检查：

1. 所有服务是否正常运行
2. 合约地址是否正确配置
3. MetaMask 网络设置是否正确
4. 浏览器控制台是否有错误信息

---

🎉 **恭喜！您已成功部署 UniswapV3 系统！**
