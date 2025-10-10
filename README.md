# 🦄 UniswapV3 技术学习项目

<div align="center">

![Solidity](https://img.shields.io/badge/Solidity-0.8.30-363636?style=flat-square&logo=solidity)
![Foundry](https://img.shields.io/badge/Foundry-Latest-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

**从零开始实现 UniswapV3 核心机制**

一个面向中文开发者的 UniswapV3 深度学习项目

</div>

---

## 📖 项目简介

这是继 [UniswapV1 技术学习项目](https://github.com/RyanWeb31110/uniswapv1_tech) 和 [UniswapV2 技术学习项目](https://github.com/RyanWeb31110/uniswapv2_tech) 之后的第三个系列学习项目。

本项目基于 [Uniswap V3 Development Book](https://uniswapv3book.com/index.html) 教程，通过**逐步实现 + 深度解析**的方式，系统性地学习 UniswapV3 的核心技术原理。

### 🎯 学习目标

通过本项目，你将深入理解：

* **集中流动性（Concentrated Liquidity）** - UniswapV3 的核心创新
* **多层级价格区间（Price Ranges）** - 精细化的流动性管理
* **Tick 机制** - 离散化价格点的设计原理
* **非同质化 LP 代币（NFT LP Tokens）** - ERC721 标准的流动性凭证
* **灵活手续费层级** - 0.05%、0.30%、1.00% 多档手续费
* **预言机增强** - 累积价格和流动性的时间加权平均
* **Flash Swaps 升级** - 更强大的闪电交换机制
* **高级数学库** - 定点数运算和平方根算法

## 🏗️ 项目架构

### 项目目标

本项目的目标是构建 UniswapV3 的核心实现。我们不会构建完全一致的副本，而是专注于 Uniswap 最核心和最重要的机制。原因是 Uniswap 是一个庞大的项目，包含许多细节和辅助功能——完整拆解所有内容会让本系列过于冗长。相反，我们将构建 Uniswap 的核心部分，包括流动性管理、交换、手续费、外围合约、报价合约和 NFT 合约。

### 核心智能合约

完成本项目学习后，您将实现以下合约：

#### 核心合约

**UniswapV3Pool** - 核心池子合约
```
功能：实现流动性管理和交换功能
特点：
  - 与原始实现非常接近，但为了简化有一些实现细节不同
  - 只处理"精确输入"交换（已知输入金额的交换）
  - 原始实现还支持"精确输出"交换（指定购买数量的交换）
```

**UniswapV3Factory** - 工厂合约
```
功能：部署新池子并记录所有已部署的池子
特点：
  - 与原始实现基本相同
  - 去除了更改所有者和手续费的能力
```

#### 外围合约

**UniswapV3Manager** - 外围管理合约
```
功能：简化与池子合约的交互
特点：
  - SwapRouter 的简化实现
  - 只实现"精确输入"交换
  - 提供友好的用户接口
```

**UniswapV3Quoter** - 链上报价合约
```
功能：允许在链上计算交换价格
特点：
  - Quoter 和 QuoterV2 的最小化实现
  - 只支持"精确输入"交换
  - 可用于前端价格预估
```

**UniswapV3NFTManager** - NFT 仓位管理器
```
功能：将流动性仓位转换为 NFT
特点：
  - NonfungiblePositionManager 的简化实现
  - 支持 ERC721 标准的流动性凭证
  - 可视化展示仓位信息
```

### 合约目录结构

```
src/
├── core/
│   ├── UniswapV3Pool.sol          # 核心池子合约，实现集中流动性
│   ├── UniswapV3Factory.sol       # 工厂合约，管理池子创建
│   └── libraries/
│       ├── Tick.sol               # Tick 数据结构和操作
│       ├── Position.sol           # 仓位管理
│       ├── TickBitmap.sol         # Tick 位图索引
│       ├── FixedPoint96.sol       # 定点数数学库
│       └── SqrtPriceMath.sol      # 平方根价格计算
├── periphery/
│   ├── UniswapV3Manager.sol       # 交换管理器（简化版 SwapRouter）
│   ├── UniswapV3Quoter.sol        # 报价合约
│   ├── UniswapV3NFTManager.sol    # NFT 仓位管理器
│   └── libraries/
│       ├── Path.sol               # 交易路径编码
│       └── PoolAddress.sol        # 池子地址计算
└── test/
    ├── ERC20Mintable.sol          # 可铸造的测试代币
    └── TestUtils.sol              # 测试辅助工具
```

### 测试框架

```
test/
├── UniswapV3Pool.t.sol            # 核心池子测试
├── UniswapV3PoolLiquidity.t.sol   # 流动性管理测试
├── UniswapV3PoolSwaps.t.sol       # 交换功能测试
├── UniswapV3Factory.t.sol         # 工厂合约测试
├── UniswapV3Manager.t.sol         # 管理器测试
├── UniswapV3Quoter.t.sol          # 报价合约测试
├── UniswapV3NFTManager.t.sol      # NFT 管理器测试
└── libraries/
    ├── Tick.t.sol                 # Tick 库测试
    ├── TickBitmap.t.sol           # Bitmap 测试
    └── Math.t.sol                 # 数学库测试
```

### 技术文档

```
docs/
├── 0Backendground/                # 背景知识
│   ├── 01-市场机制与AMM原理.md
│   ├── 02-恒定函数做市商.md
│   ├── 03-UniswapV3核心创新.md
│   └── 04-开发环境搭建.md
└── 1FirstSwap/                    # 第一次交换
    └── 05-第一次交换：流动性计算.md
```

### 数学计算工具

```
scripts/
└── unimath.py                     # UniswapV3 流动性计算工具
```

Python 脚本用于验证和计算 UniswapV3 的数学参数，包括：
- 价格与 Tick 的转换
- Q64.96 定点数格式转换
- 流动性参数计算
- 精确代币数量计算

### 前端应用

本项目还包含一个简化版的 Uniswap UI 克隆：

```
ui/
├── src/
│   ├── components/            # React 组件
│   ├── hooks/                # 自定义 Hooks
│   └── utils/                # 工具函数
└── public/                   # 静态资源
```

**功能特点：**
- 使用 React 构建用户界面
- 通过 Ethers.js 与智能合约交互
- 集成 MetaMask 钱包连接
- 展示如何构建完整的 DApp

> 💡 **学习收获**
>
> 完成本项目后，您将能够阅读 Uniswap V3 的源代码，并理解本项目范围之外的所有机制。我们的实现虽然简化，但保留了最核心的架构和算法，这将为您深入研究完整实现打下坚实基础。

## 🚀 快速开始

### 环境要求

* **Foundry** - 最新版本
* **Solidity** - 0.8.30
* **Python** - 3.7+ (用于数学计算工具)
* **Node.js** - 16+ (用于前端开发)

### 安装依赖

```bash
# 克隆项目
git clone https://github.com/RyanWeb31110/uniswapv3_tech.git
cd uniswapv3_tech

# 安装 Foundry 依赖
forge install
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 详细输出测试过程
forge test -vvv

# 运行特定测试
forge test --match-test testMint -vvv

# 生成 Gas 报告
forge test --gas-report
```

### 代码格式化

```bash
forge fmt
```

### 使用 Python 数学工具

```bash
# 运行默认示例（ETH/USDC 池子）
python scripts/unimath.py

# 交互模式，自定义参数
python scripts/unimath.py --interactive
```

**示例输出：**
```
============================================================
步骤 1: 计算价格区间的 Tick 值
============================================================
当前价格 5000 USDC/ETH -> Tick 85176
下限价格 4545 USDC/ETH -> Tick 84222
上限价格 5500 USDC/ETH -> Tick 86129

============================================================
步骤 3: 计算流动性 L
============================================================
基于 ETH:  L = 1519437308014769733632
基于 USDC: L = 1517882343751509868544
选择较小值: L = 1517882343751509868544
```

## 📋 UniswapV3 核心创新

### 1. 集中流动性（Concentrated Liquidity）

与 V1/V2 的全价格范围流动性不同，V3 允许 LP 选择特定价格区间提供流动性：

```
传统 AMM (V1/V2):
价格范围: [0, ∞]
资金利用率: 低

UniswapV3:
价格范围: [价格下限, 价格上限]
资金利用率: 高达 4000x
```

**优势**：
- 相同资金获得更多手续费收益
- 降低交易者的滑点
- 灵活的做市策略

### 2. Tick 机制

将连续的价格空间离散化为 Tick：

```solidity
// 价格与 Tick 的关系
price = 1.0001^tick

// 例如:
tick = 0    -> price = 1.0
tick = 100  -> price ≈ 1.01
tick = -100 -> price ≈ 0.99
```

**设计理由**：
- 标准化价格点，便于流动性聚合
- 高效的数据结构（位图索引）
- 精确的范围边界控制

### 3. 非同质化流动性（NFT LP Tokens）

每个流动性仓位都是独特的 ERC721 NFT：

```
V2: 同质化 LP 代币（ERC20）
    - 所有 LP 共享相同价格范围
    - 可互换

V3: 非同质化 LP 代币（ERC721）
    - 每个仓位有独特的价格区间
    - 不可互换
    - 支持可视化展示
```

### 4. 多层级手续费

提供三档手续费选择：

| 费率 | 适用场景 |
|------|----------|
| **0.05%** | 稳定币交易对（USDC/USDT） |
| **0.30%** | 主流代币对（ETH/USDC） |
| **1.00%** | 高风险/低流动性代币对 |

### 5. 增强型预言机

提供时间加权平均价格（TWAP）和流动性数据：

```solidity
// V2: 仅支持价格预言机
// V3: 支持价格 + 流动性预言机

function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    );
```

## 🔬 核心技术原理

### 恒定乘积公式的演进

**V1/V2 公式**:
```
x × y = k
```

**V3 虚拟储备公式**:
```
(x + L/√Pb) × (y + L×√Pa) = L²

其中:
- L: 流动性
- Pa: 价格下限
- Pb: 价格上限
```

### 流动性计算

```solidity
// 根据代币数量计算流动性
L = Δy / (√Pb - √Pa)
L = Δx × √Pa × √Pb / (√Pb - √Pa)

// 取较小值确保比例正确
L = min(L_x, L_y)
```

### 交换价格计算

使用 sqrt(price) 进行计算，避免溢出：

```solidity
// sqrtPriceX96 = sqrt(price) × 2^96
uint160 sqrtPriceX96;

// 价格转换
price = (sqrtPriceX96 / 2^96)²
```

## 🧪 测试策略

采用 Foundry 测试框架，利用其高性能和丰富的作弊码：

```solidity
// 模拟用户操作
vm.startPrank(alice);
pool.mint(tickLower, tickUpper, liquidity);
vm.stopPrank();

// 时间操作
vm.warp(block.timestamp + 1 days);

// 状态快照
uint256 snapshot = vm.snapshot();
// ... 执行测试 ...
vm.revertTo(snapshot);
```

### 测试覆盖

- ✅ 流动性添加和移除
- ✅ 单 Tick 范围内交换
- ✅ 跨多个 Tick 的交换
- ✅ 手续费累积和收取
- ✅ 价格预言机数据
- ✅ 边界情况处理
- ✅ Gas 优化验证

## 🎓 学习路径

### 基础阶段（准备中）

1. **第一步**：理解 V2 与 V3 的核心差异
2. **第二步**：学习 Tick 和价格区间的概念
3. **第三步**：实现基础的流动性管理

### 进阶阶段（准备中）

4. **第四步**：实现单 Tick 范围内的交换
5. **第五步**：实现跨 Tick 的复杂交换
6. **第六步**：添加手续费机制

### 高级阶段（准备中）

7. **第七步**：实现价格预言机
8. **第八步**：构建 NFT 仓位管理器
9. **第九步**：实现 Flash Swaps
10. **第十步**：开发交换路由器

## 🛠️ 技术栈

### 智能合约开发

* **Foundry** - 高性能智能合约开发框架
* **Solidity 0.8.30** - 智能合约编程语言
* **OpenZeppelin** - 安全的合约库（ERC20、ERC721）

### 数学计算工具

* **Python 3.7+** - 流动性计算和验证
* **标准库** - 无需额外依赖，仅使用内置 math 模块

### 前端开发（规划中）

* **React** - UI 框架
* **ethers.js** - 以太坊交互库
* **Web3Modal** - 钱包连接

## 📖 参考资源

### 官方文档

* [Uniswap V3 官方文档](https://docs.uniswap.org/protocol/concepts/V3-overview/concentrated-liquidity)
* [Uniswap V3 白皮书](https://uniswap.org/whitepaper-v3.pdf)
* [Uniswap V3 Core 代码仓库](https://github.com/Uniswap/v3-core)
* [Uniswap V3 Periphery 代码仓库](https://github.com/Uniswap/v3-periphery)

### 学习教程

* [Uniswap V3 Development Book](https://uniswapv3book.com/index.html) - **本项目主要参考教程**
* [Foundry Book](https://book.getfoundry.sh/) - Foundry 官方文档

### 技术文章

* [Uniswap v3 Core](https://uniswap.org/blog/uniswap-v3) - 官方博客介绍
* [Introducing Uniswap V3](https://uniswap.org/blog/uniswap-v3) - V3 核心特性解析

## 🎯 项目特色

* ✨ **系统化学习路径** - 从基础到高级的完整教学体系
* 📝 **中文深度解析** - 面向中文开发者的详细技术讲解
* 💻 **实战代码演示** - 每个概念都配有完整的代码实现
* 🧪 **全面测试覆盖** - 确保代码质量和功能完整性
* 📚 **渐进式学习** - 跟随 Uniswap V3 Book 循序渐进
* 🎨 **可视化界面** - 交互式前端帮助理解抽象概念

## 🔧 开发指南

### Gas 优化

```bash
# 生成 Gas 使用报告
forge snapshot

# 查看详细 Gas 消耗
forge test --gas-report

# 对比 Gas 优化效果
forge snapshot --diff
```

### 本地开发环境

```bash
# 启动本地测试网络
anvil

# 部署到本地网络
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

### 代码覆盖率

```bash
# 生成覆盖率报告
forge coverage

# 生成 LCOV 格式报告
forge coverage --report lcov
```

## 📈 项目进度

### 已完成
- [x] 项目初始化和开发环境搭建
- [x] Python 数学计算工具（`scripts/unimath.py`）
- [x] 流动性计算原理文档

### 进行中
- [ ] 核心数学库实现（Solidity）
- [ ] Tick 机制实现
- [ ] 流动性管理

### 计划中
- [ ] 交换功能
- [ ] 费用机制
- [ ] 预言机功能
- [ ] NFT 仓位管理
- [ ] 路由器实现
- [ ] 前端界面

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来完善本教学项目！

### 贡献方式

* 📖 改进文档和注释
* 🧪 添加更多测试用例
* ⚡ 优化合约 Gas 消耗
* 🌐 提供英文版本翻译
* 🎨 改进前端界面

## 📊 系列项目

| 项目 | 仓库 | 核心特性 |
|------|------|----------|
| **UniswapV1** | [uniswapv1_tech](https://github.com/RyanWeb31110/uniswapv1_tech) | 单一 ETH 交易对、基础 AMM |
| **UniswapV2** | [uniswapv2_tech](https://github.com/RyanWeb31110/uniswapv2_tech) | ERC20-ERC20、闪电交换、价格预言机 |
| **UniswapV3** | [uniswapv3_tech](https://github.com/RyanWeb31110/uniswapv3_tech) | 集中流动性、多档费率、NFT LP |

## 📄 许可证

MIT License

---

## 🔗 相关链接

* **项目仓库**: <https://github.com/RyanWeb31110/uniswapv3_tech>
* **V1 项目**: <https://github.com/RyanWeb31110/uniswapv1_tech>
* **V2 项目**: <https://github.com/RyanWeb31110/uniswapv2_tech>
* **学习教程**: <https://uniswapv3book.com/index.html>

---

<div align="center">

**⭐ 如果这个项目对你有帮助，欢迎 Star 支持！**

Made with ❤️ by [RyanWeb31110](https://github.com/RyanWeb31110)

</div>
