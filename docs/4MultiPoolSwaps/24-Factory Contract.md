# UniswapV3 技术学习系列（二十四）：工厂合约

## 开篇导读

在去中心化交易所（DEX）的世界里，**如何高效地管理成千上万个流动性池**是一个核心挑战。想象一下，如果每个代币对都需要手动部署合约、记录地址、维护状态，整个系统将变得混乱不堪。而 Uniswap V3 通过**工厂合约（Factory Contract）**和**确定性部署（Deterministic Deployment）**优雅地解决了这个问题。

本章我们将深入探讨 Uniswap V3 的池子管理架构，学习如何通过工厂模式批量创建池子，以及如何利用 EVM 的 CREATE2 操作码实现地址的确定性计算。这不仅是 Uniswap 的核心设计，也是现代 DeFi 协议的重要设计模式。

**核心要点**：

- 🏭 **工厂模式**：通过单一入口统一管理所有池子的创建和注册
- 🔮 **确定性地址**：使用 CREATE2 让池子地址可预测、可验证
- 📐 **Tick Spacing**：通过价格间距优化不同类型代币对的交易效率
- 🔄 **控制反转**：巧妙的参数传递机制，让合约部署更加优雅

通过本章学习，你将掌握如何构建一个可扩展、高效且安全的去中心化交易所基础设施。

**原文链接**：[Factory Contract - Uniswap V3 Development Book](https://uniswapv3book.com/milestone_4/factory-contract.html)

---

## 一、多池交换概述

### 1.1 什么是多池交换？

多池交换允许我们通过多个流动性池完成代币兑换。例如，将 WETH → USDC → USDT → WBTC 这样的复杂路径自动化处理。

**核心优势**：

- 💡 **扩展交易范围**：即使没有直接交易对，也能完成兑换
- ⚡ **自动化路由**：智能合约自动处理中间交换
- 💰 **优化交易成本**：选择最优路径减少滑点

### 1.2 本章实现计划

我们将按以下步骤实现多池交换功能：

1. **Factory 合约**：集中管理所有池子的注册表
2. **Path 库**：处理多跳交易路径的编码和解码
3. **前端更新**：支持多池交换的用户界面
4. **路由器**：自动查找最优交换路径
5. **Tick Spacing**：优化交换效率的价格间距机制

---

## 二、Factory 合约详解

### 2.1 为什么需要 Factory？

Uniswap 采用了**池子分离架构**：每个代币对都有独立的 Pool 合约。这种设计虽然灵活，但也带来了管理上的挑战。Factory 合约就是为了解决这些问题而诞生的。

**Factory 的三大核心功能**：

1. **📋 集中注册表**：记录所有已部署的池子地址
   - 通过代币地址快速查找对应的池子
   - 提供统一的查询接口

2. **🏭 简化部署流程**：使用工厂模式批量创建池子
   - EVM 支持合约部署合约
   - 标准化池子的初始化过程

3. **🔮 可预测地址**：使用 CREATE2 生成确定性地址
   - 无需调用注册表即可计算池子地址
   - 提高跨合约调用的效率

### 2.2 CREATE 与 CREATE2 的区别

在理解 Factory 实现之前，我们需要先了解 EVM 的两种合约部署方式。

#### CREATE 操作码

使用部署者的 **nonce**（交易计数器）生成地址：

```
地址 = KECCAK256(部署者地址, 部署者nonce)
```

**缺点**：
- ❌ 地址不可预测（nonce 会随交易变化）
- ❌ 需要扫描历史交易才能找到某个合约的部署 nonce
- ❌ 难以在其他合约中提前计算地址

#### CREATE2 操作码

使用自定义的 **salt**（盐值）生成地址：

```
地址 = KECCAK256(0xff, 部署者地址, salt, 合约代码哈希)
```

**优点**：
- ✅ 地址完全确定（只要 salt 相同，地址不变）
- ✅ 可以在部署前预先计算地址
- ✅ 便于跨合约引用和验证

**Uniswap V3 的 salt 计算**：

```solidity
salt = keccak256(abi.encodePacked(token0, token1, tickSpacing))
```

**这意味着相同的代币对 + tick spacing 组合，永远会生成相同的池子地址！**

---

## 三、Tick Spacing（价格间距）

### 3.1 什么是 Tick Spacing？

回顾一下我们在 `swap` 函数中的循环逻辑：

```solidity
while (
    state.amountSpecifiedRemaining > 0 &&
    state.sqrtPriceX96 != sqrtPriceLimitX96
) {
    // 查找下一个有流动性的 tick
    (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(...);

    // 计算交换步骤
    (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath.computeSwapStep(...);
}
```

这个循环需要**逐个遍历 tick**，直到找到有流动性的位置。如果目标 tick 很远，就需要遍历大量的 tick，**消耗大量 gas**！

**Tick Spacing 的作用**：设置 tick 之间的最小间隔，减少遍历次数。

### 3.2 Tick Spacing 的权衡

| 属性 | 大间距 | 小间距 |
|------|--------|--------|
| **Gas 效率** | 高（遍历少） | 低（遍历多） |
| **价格精度** | 低 | 高 |
| **适用场景** | 高波动率代币对 | 稳定币对 |

**Uniswap V3 的 Tick Spacing 选项**：
- **10**：高精度，适合稳定币对（如 USDC/USDT）
- **60**：中等精度，适合主流代币对（如 ETH/USDC）
- **200**：低精度，适合高波动率代币对

> 📌 **注意**：Tick spacing 只限制**流动性范围的边界**，不限制**当前价格**。当前价格可以是任意 tick，以保证最高精度。

### 3.3 Tick Spacing 的技术约束

当 tick spacing = 60 时，只有能被 60 整除的 tick 才能被标记为"已初始化"：

```
✅ 有效的 tick: -120, -60, 0, 60, 120, 180...
❌ 无效的 tick: -59, -1, 10, 61, 100...
```

**代码验证示例**：

```solidity
// 检查 tick 是否符合 spacing 要求
require(tick % tickSpacing == 0, "Invalid tick");
```

从现在开始，我们将在示例中使用：
- 常规池子：tick spacing = **60**
- 稳定币池：tick spacing = **10**

---

## 四、Factory 合约实现

### 4.1 构造函数 - 初始化支持的 Tick Spacing

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3Pool.sol";

/// @title Uniswap V3 池子工厂合约
/// @notice 负责创建和管理所有的交易池
contract UniswapV3Factory is IUniswapV3PoolDeployer {
    /// @notice 记录哪些 tick spacing 是被支持的
    mapping(uint24 => bool) public tickSpacings;

    /// @notice 临时存储池子初始化参数（仅在部署期间使用）
    PoolParameters public parameters;

    /// @notice 三维映射：token0 => token1 => tickSpacing => pool地址
    mapping(address => mapping(address => mapping(uint24 => address))) public pools;

    /// @notice 池子创建事件
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed tickSpacing,
        address pool
    );

    // 自定义错误（节省 gas）
    error TokensMustBeDifferent();
    error UnsupportedTickSpacing();
    error TokenXCannotBeZero();
    error PoolAlreadyExists();

    constructor() {
        // 初始化支持的 tick spacing
        tickSpacings[10] = true;  // 稳定币对
        tickSpacings[60] = true;  // 常规代币对
    }

    // ... 其他函数
}
```

**设计说明**：
- 使用 `mapping` 而非常量，便于未来扩展不同费率的 tick spacing
- 自定义错误比 `require` 字符串节省大量 gas
- 三维映射可以快速定位任意池子

### 4.2 createPool 函数 - 创建新池子

```solidity
/// @notice 创建一个新的交易池
/// @param tokenX 代币 X 地址
/// @param tokenY 代币 Y 地址
/// @param tickSpacing Tick 间距（决定价格精度）
/// @return pool 新创建的池子地址
function createPool(
    address tokenX,
    address tokenY,
    uint24 tickSpacing
) public returns (address pool) {
    // ========== 1. 输入验证 ==========

    // 检查代币地址不能相同
    if (tokenX == tokenY) revert TokensMustBeDifferent();

    // 检查 tick spacing 是否被支持
    if (!tickSpacings[tickSpacing]) revert UnsupportedTickSpacing();

    // ========== 2. 代币排序 ==========
    // 确保 token0 < token1（地址数值比较）
    (tokenX, tokenY) = tokenX < tokenY
        ? (tokenX, tokenY)
        : (tokenY, tokenX);

    // token0 不能是零地址
    if (tokenX == address(0)) revert TokenXCannotBeZero();

    // 检查池子是否已存在
    if (pools[tokenX][tokenY][tickSpacing] != address(0)) {
        revert PoolAlreadyExists();
    }

    // ========== 3. 设置部署参数 ==========
    // 使用控制反转模式传递参数
    parameters = PoolParameters({
        factory: address(this),
        token0: tokenX,
        token1: tokenY,
        tickSpacing: tickSpacing
    });

    // ========== 4. 使用 CREATE2 部署池子 ==========
    pool = address(
        new UniswapV3Pool{
            salt: keccak256(abi.encodePacked(tokenX, tokenY, tickSpacing))
        }()
    );

    // ========== 5. 清理临时参数 ==========
    // 删除参数可以退还 gas
    delete parameters;

    // ========== 6. 记录池子地址 ==========
    // 双向记录，方便查询
    pools[tokenX][tokenY][tickSpacing] = pool;
    pools[tokenY][tokenX][tickSpacing] = pool;

    // 发出事件
    emit PoolCreated(tokenX, tokenY, tickSpacing, pool);
}
```

**关键点解析**：

#### 🔐 代币排序的重要性

```solidity
(tokenX, tokenY) = tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
```

**为什么要排序？**
- 确保同一代币对只有唯一的 salt
- 避免 ETH/USDC 和 USDC/ETH 创建两个不同的池子
- 使地址计算具有确定性

**影响范围**：
- 部署脚本需要确保 WETH 是 token0
- 测试代码需要按地址大小排序代币
- 否则价格计算会出现倒数问题（1/5000 vs 5000）

#### 🔄 控制反转（IoC）模式

这是一个巧妙的设计模式：

**传统方式**（不推荐）：
```solidity
// 需要在构造函数中传递大量参数
new UniswapV3Pool(factory, token0, token1, tickSpacing);
```

**控制反转方式**（Uniswap 使用）：
```solidity
// Factory 端
parameters = PoolParameters({...});
new UniswapV3Pool();
delete parameters;

// Pool 端
constructor() {
    (factory, token0, token1, tickSpacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
}
```

**优势**：
- ✅ 减少构造函数参数
- ✅ Pool 合约代码更简洁
- ✅ 使用 `delete` 退还 gas

### 4.3 Pool 合约的更新

```solidity
// src/UniswapV3Pool.sol
contract UniswapV3Pool is IUniswapV3Pool {
    address public factory;
    address public token0;
    address public token1;
    uint24 public tickSpacing;

    /// @notice 构造函数 - 从 Factory 读取参数
    constructor() {
        // msg.sender 就是 Factory 合约地址
        (factory, token0, token1, tickSpacing) = IUniswapV3PoolDeployer(
            msg.sender
        ).parameters();
    }

    // ... 其他函数
}
```

**执行流程**：

1. Factory 设置 `parameters` 状态变量
2. Factory 调用 `new UniswapV3Pool()`
3. Pool 构造函数中调用 `msg.sender.parameters()`
4. Pool 获取初始化参数
5. Factory 清理 `parameters`（退还 gas）

**完整执行时序图**

```
时间轴
  │
  ├─ 1. 用户调用 factory.createPool(tokenX, tokenY, tickSpacing)
  │
  ├─ 2. Factory 设置临时参数
  │     parameters = PoolParameters({...})
  │
  ├─ 3. Factory 使用 CREATE2 部署 Pool
  │     new UniswapV3Pool{salt: ...}()
  │     │
  │     ├─ 4. Pool 构造函数执行
  │     │     constructor() {
  │     │         // 主动回调 Factory 读取参数
  │     │         (...) = IUniswapV3PoolDeployer(msg.sender).parameters();
  │     │     }
  │     │
  │     └─ 5. Pool 初始化完成
  │
  ├─ 6. Factory 清空临时参数（可选）
  │     delete parameters;
  │
  └─ 7. 返回 Pool 地址
```

---

## 五、池子初始化

### 5.1 分离构造和初始化

之前我们在构造函数中设置 `sqrtPriceX96` 和 `tick`，现在改为独立的 `initialize` 函数：

```solidity
// src/UniswapV3Pool.sol

/// @notice 池子初始化错误
error AlreadyInitialized();

/// @notice 初始化池子价格
/// @param sqrtPriceX96 初始价格的 Q64.96 格式平方根
/// @dev 该函数只能调用一次
function initialize(uint160 sqrtPriceX96) public {
    // 防止重复初始化
    if (slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();

    // 根据价格计算对应的 tick
    int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

    // 设置初始状态
    slot0 = Slot0({
        sqrtPriceX96: sqrtPriceX96,
        tick: tick
    });
}
```

**为什么要分离？**

1. **灵活性**：部署和初始化可以由不同账户完成
2. **安全性**：初始化参数可以在部署后再确定
3. **标准化**：所有池子遵循统一的部署流程

### 5.2 新的部署流程

```solidity
// 测试代码示例
function testDeployPool() public {
    // 1. 部署工厂合约
    UniswapV3Factory factory = new UniswapV3Factory();

    // 2. 通过工厂创建池子
    address poolAddress = factory.createPool(
        address(token0),  // WETH
        address(token1),  // USDC
        60               // tick spacing
    );

    // 3. 获取池子实例
    UniswapV3Pool pool = UniswapV3Pool(poolAddress);

    // 4. 初始化池子价格
    uint160 sqrtPrice = sqrtP(5000); // 1 ETH = 5000 USDC
    pool.initialize(sqrtPrice);

    // 现在池子可以正常使用了
}
```

---

## 六、PoolAddress 库 - 计算池子地址

### 6.1 为什么需要这个库？

在其他合约中，我们经常需要：
- 验证池子地址是否合法
- 在不调用 Factory 的情况下找到池子
- 节省 gas（避免外部调用）

### 6.2 实现 computeAddress 函数

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../UniswapV3Pool.sol";

/// @title 池子地址计算库
/// @notice 提供离线计算池子地址的功能
library PoolAddress {
    /// @notice 计算池子的确定性地址
    /// @param factory Factory 合约地址
    /// @param token0 代币0地址（必须 < token1）
    /// @param token1 代币1地址
    /// @param tickSpacing Tick 间距
    /// @return pool 计算出的池子地址
    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 tickSpacing
    ) internal pure returns (address pool) {
        // 确保代币已排序
        require(token0 < token1, "Tokens not sorted");

        // 按照 CREATE2 规则计算地址
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            // CREATE2 的标识前缀
                            hex"ff",

                            // 部署者（Factory）地址
                            factory,

                            // Salt（代币对 + tick spacing）
                            keccak256(
                                abi.encodePacked(token0, token1, tickSpacing)
                            ),

                            // 池子合约的代码哈希
                            keccak256(type(UniswapV3Pool).creationCode)
                        )
                    )
                )
            )
        );
    }
}
```

### 6.3 CREATE2 地址计算详解

CREATE2 地址由以下四部分决定：

| 组成部分 | 说明 | 示例/值 |
|---------|------|--------|
| **0xff** | CREATE2 标识符 | 固定值，区分 CREATE 和 CREATE2 |
| **部署者地址** | Factory 合约地址 | `0x1234...5678` |
| **Salt** | 唯一标识符 | `keccak256(token0, token1, tickSpacing)` |
| **代码哈希** | 合约字节码哈希 | `keccak256(UniswapV3Pool.creationCode)` |

**计算流程**：

```
1. 计算 salt
   salt = keccak256(abi.encodePacked(WETH, USDC, 60))

2. 获取合约代码哈希
   codeHash = keccak256(type(UniswapV3Pool).creationCode)

3. 组合所有参数并哈希
   data = abi.encodePacked(0xff, factory, salt, codeHash)
   hash = keccak256(data)

4. 取哈希的后 20 字节作为地址
   pool = address(uint160(uint256(hash)))
```

**关键特性**：
- 🔐 **确定性**：相同输入永远产生相同地址
- 🚀 **无需查询**：可以在任何地方计算地址
- ✅ **可验证**：任何人都可以验证地址的正确性

### 6.4 使用示例

```solidity
// 在 Manager 合约中使用
function swap(
    address tokenIn,
    address tokenOut,
    uint24 tickSpacing,
    uint256 amountIn
) external {
    // 排序代币
    (address token0, address token1) = tokenIn < tokenOut
        ? (tokenIn, tokenOut)
        : (tokenOut, tokenIn);

    // 计算池子地址（无需调用 Factory）
    address pool = PoolAddress.computeAddress(
        factory,
        token0,
        token1,
        tickSpacing
    );

    // 执行交换
    IUniswapV3Pool(pool).swap(...);
}
```

---

## 七、简化 Manager 和 Quoter 接口

### 7.1 不再需要池子地址参数

**之前的接口**（繁琐）：
```solidity
function swap(
    address poolAddress,  // 用户需要手动查找
    bool zeroForOne,      // 用户需要判断方向
    uint256 amountIn
) external;
```

**优化后的接口**（简洁）：
```solidity
function swap(
    address tokenIn,      // 输入代币
    address tokenOut,     // 输出代币
    uint24 tickSpacing,   // Tick 间距
    uint256 amountIn      // 输入数量
) external;
```

### 7.2 自动判断交换方向

```solidity
// 根据代币排序自动判断 zeroForOne
function getSwapDirection(
    address tokenIn,
    address tokenOut
) internal pure returns (bool zeroForOne) {
    // token0 → token1: zeroForOne = true
    // token1 → token0: zeroForOne = false
    zeroForOne = tokenIn < tokenOut;
}
```

**原理**：
- 地址是哈希值，可以比较大小
- 池子中 token0 永远小于 token1
- 如果 tokenIn < tokenOut，则 tokenIn = token0，方向为 `true`

### 7.3 完整示例

```solidity
// src/UniswapV3Manager.sol

function swap(
    address tokenIn,
    address tokenOut,
    uint24 tickSpacing,
    uint256 amountIn,
    uint160 sqrtPriceLimitX96
) external returns (uint256 amountOut) {
    // 1. 排序代币
    (address token0, address token1) = tokenIn < tokenOut
        ? (tokenIn, tokenOut)
        : (tokenOut, tokenIn);

    // 2. 计算池子地址
    address pool = PoolAddress.computeAddress(
        factory,
        token0,
        token1,
        tickSpacing
    );

    // 3. 确定交换方向
    bool zeroForOne = tokenIn < tokenOut;

    // 4. 执行交换
    (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
        msg.sender,
        zeroForOne,
        int256(amountIn),
        sqrtPriceLimitX96,
        abi.encode(msg.sender)
    );

    // 5. 返回输出数量
    amountOut = uint256(-(zeroForOne ? amount1 : amount0));
}
```

---

## 八、核心知识点回顾

### 8.1 Factory 合约的三大功能

| 功能 | 说明 | 收益 |
|------|------|------|
| **集中注册表** | 记录所有池子的映射关系 | 快速查找池子地址 |
| **标准化部署** | 使用工厂模式创建池子 | 降低部署复杂度 |
| **确定性地址** | 使用 CREATE2 生成地址 | 无需查询即可计算地址 |

### 8.2 Tick Spacing 的权衡

```
Gas 效率 ↑ ←→ 价格精度 ↓

大间距 (200) → 高波动率代币对 → 节省 gas
中间距 (60)  → 常规代币对       → 平衡
小间距 (10)  → 稳定币对         → 高精度
```

### 8.3 CREATE2 vs CREATE

| 特性 | CREATE | CREATE2 |
|------|--------|---------|
| **地址计算** | `hash(部署者, nonce)` | `hash(0xff, 部署者, salt, 代码哈希)` |
| **确定性** | ❌ 依赖 nonce | ✅ 完全确定 |
| **可预测性** | ❌ 需要查询历史 | ✅ 可提前计算 |
| **Uniswap 使用** | ❌ | ✅ |

### 8.4 控制反转模式的优势

**传统构造函数**：
```solidity
constructor(address _factory, address _token0, address _token1, uint24 _tickSpacing) {
    // 参数多，gas 消耗高
}
```

**控制反转**：
```solidity
constructor() {
    // 从部署者读取参数，更优雅
    (...) = IDeployer(msg.sender).parameters();
}
```

---

## 九、实践要点

### 9.1 部署时的注意事项

```solidity
// ✅ 正确：确保 WETH 地址更小
require(address(weth) < address(usdc), "Wrong token order");

// ❌ 错误：未排序可能导致价格倒数
factory.createPool(usdc, weth, 60); // 可能创建错误的池子
```

### 9.2 测试代码更新

```solidity
function setUp() public {
    factory = new UniswapV3Factory();

    // 确保代币顺序正确
    if (address(weth) > address(usdc)) {
        (weth, usdc) = (usdc, weth);
    }

    address poolAddress = factory.createPool(
        address(weth),
        address(usdc),
        60
    );

    pool = UniswapV3Pool(poolAddress);
    pool.initialize(sqrtP(5000));
}
```

### 9.3 前端集成

```typescript
// 计算池子地址（TypeScript 版本）
function computePoolAddress(
    factory: string,
    token0: string,
    token1: string,
    tickSpacing: number
): string {
    // 确保代币排序
    if (token0 > token1) {
        [token0, token1] = [token1, token0];
    }

    // 计算 salt
    const salt = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['address', 'address', 'uint24'],
            [token0, token1, tickSpacing]
        )
    );

    // 获取合约代码哈希
    const codeHash = ethers.utils.keccak256(PoolBytecode);

    // CREATE2 地址计算
    const address = ethers.utils.getCreate2Address(
        factory,
        salt,
        codeHash
    );

    return address;
}
```

---

## 项目仓库

本项目 GitHub 仓库：
https://github.com/RyanWeb31110/uniswapv3_tech

系列项目：
- [UniswapV1 技术学习](https://github.com/RyanWeb31110/uniswapv1_tech)
- [UniswapV2 技术学习](https://github.com/RyanWeb31110/uniswapv2_tech)
- [UniswapV3 技术学习](https://github.com/RyanWeb31110/uniswapv3_tech)

欢迎 Star ⭐ 和 Fork，一起学习交流！
