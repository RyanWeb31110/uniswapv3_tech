# UniswapV3 数学计算工具

这个目录包含用于计算和验证 UniswapV3 数学参数的 Python 脚本。

## 📁 文件说明

### unimath.py

UniswapV3 流动性计算的核心工具，用于：

- **价格转换**: 价格 ↔ Tick ↔ 平方根价格 ↔ Q64.96 格式
- **流动性计算**: 从代币数量计算流动性参数 L
- **代币数量计算**: 从流动性反推精确的代币数量
- **完整流程演示**: 一键计算所有参数

## 🚀 使用方法

### 方式一：运行默认示例

直接运行脚本，使用预设的 ETH/USDC 池子参数：

```bash
python scripts/unimath.py
```

**默认参数：**
- 当前价格：5000 USDC/ETH
- 价格区间：4545 - 5500 USDC/ETH
- 提供流动性：1 ETH + 5000 USDC

**输出示例：**
```
============================================================
步骤 1: 计算价格区间的 Tick 值
============================================================
当前价格 5000 USDC/ETH -> Tick 85176
下限价格 4545 USDC/ETH -> Tick 84222
上限价格 5500 USDC/ETH -> Tick 86129

============================================================
步骤 2: 转换为 Q64.96 格式
============================================================
下限 sqrtP: 5314786713428871004159001755648
当前 sqrtP: 5602277097478614198912276234240
上限 sqrtP: 5875717789736564987741329162240

============================================================
步骤 3: 计算流动性 L
============================================================
基于 ETH:  L = 1519437308014769733632
基于 USDC: L = 1517882343751509868544
选择较小值: L = 1517882343751509868544

============================================================
步骤 4: 计算精确代币数量
============================================================
精确 ETH:  998976618347425408 wei
         = 0.998976618347425408 ETH
精确 USDC: 5000000000000000000000 wei
         = 5000.00 USDC
```

### 方式二：交互模式

使用交互模式自定义参数：

```bash
python scripts/unimath.py --interactive
```

程序会提示您输入：
1. 当前价格（USDC/ETH）
2. 下限价格（USDC/ETH）
3. 上限价格（USDC/ETH）
4. ETH 数量
5. USDC 数量

### 方式三：作为模块导入

在您的 Python 代码中导入使用：

```python
from scripts.unimath import (
    price_to_tick,
    price_to_sqrtp_q96,
    liquidity_from_x,
    liquidity_from_y,
    calculate_liquidity
)

# 示例：计算自定义池子参数
results = calculate_liquidity(
    price_current=3000,
    price_lower=2500,
    price_upper=3500,
    amount_eth=2,
    amount_usdc=6000,
    verbose=True
)

print(f"流动性 L: {results['liquidity']}")
print(f"精确 ETH: {results['amount_eth_final']}")
print(f"精确 USDC: {results['amount_usdc_final']}")
```

## 📚 函数文档

### 价格和 Tick 转换

#### `price_to_tick(price)`
将价格转换为 Tick 索引。

**参数：**
- `price`: 价格（例如 5000 表示 5000 USDC/ETH）

**返回：**
- Tick 索引（整数）

**示例：**
```python
tick = price_to_tick(5000)  # 85176
```

#### `tick_to_price(tick)`
将 Tick 索引转换回价格。

**参数：**
- `tick`: Tick 索引

**返回：**
- 价格

**示例：**
```python
price = tick_to_price(85176)  # ≈ 5000
```

#### `price_to_sqrtp_q96(price)`
将价格转换为 Q64.96 格式的平方根价格。

**参数：**
- `price`: 价格

**返回：**
- Q64.96 格式的整数

**示例：**
```python
sqrtp = price_to_sqrtp_q96(5000)
# 5602277097478614198912276234240
```

### 流动性计算

#### `liquidity_from_x(amount, pa, pb)`
从 x 代币（如 ETH）数量计算流动性。

**参数：**
- `amount`: 代币数量（wei）
- `pa`: 当前平方根价格（Q64.96）
- `pb`: 上限平方根价格（Q64.96）

**返回：**
- 流动性值 L

#### `liquidity_from_y(amount, pa, pb)`
从 y 代币（如 USDC）数量计算流动性。

**参数：**
- `amount`: 代币数量（wei）
- `pa`: 下限平方根价格（Q64.96）
- `pb`: 当前平方根价格（Q64.96）

**返回：**
- 流动性值 L

### 代币数量计算

#### `calc_amount_x(liquidity, pa, pb)`
从流动性计算 x 代币数量。

**参数：**
- `liquidity`: 流动性值 L
- `pa`: 当前平方根价格（Q64.96）
- `pb`: 上限平方根价格（Q64.96）

**返回：**
- 代币数量（wei）

#### `calc_amount_y(liquidity, pa, pb)`
从流动性计算 y 代币数量。

**参数：**
- `liquidity`: 流动性值 L
- `pa`: 下限平方根价格（Q64.96）
- `pb`: 当前平方根价格（Q64.96）

**返回：**
- 代币数量（wei）

### 完整计算流程

#### `calculate_liquidity(price_current, price_lower, price_upper, amount_eth, amount_usdc, verbose=True)`
一键计算完整的流动性参数。

**参数：**
- `price_current`: 当前价格
- `price_lower`: 下限价格
- `price_upper`: 上限价格
- `amount_eth`: ETH 数量
- `amount_usdc`: USDC 数量
- `verbose`: 是否打印详细信息（默认 True）

**返回：**
- 包含所有计算结果的字典

## 🎯 使用场景

### 1. 验证 Solidity 合约计算

在编写智能合约之前，使用 Python 验证数学逻辑：

```python
# 计算预期结果
results = calculate_liquidity(5000, 4545, 5500, 1, 5000)

# 在 Solidity 测试中对比
# assertEq(liquidity, results['liquidity'])
```

### 2. 价格区间分析

分析不同价格区间对流动性的影响：

```python
# 测试窄区间
narrow = calculate_liquidity(5000, 4900, 5100, 1, 5000, verbose=False)

# 测试宽区间
wide = calculate_liquidity(5000, 4000, 6000, 1, 5000, verbose=False)

print(f"窄区间 L: {narrow['liquidity']}")
print(f"宽区间 L: {wide['liquidity']}")
```

### 3. LP 策略模拟

模拟不同的流动性提供策略：

```python
# 保守策略：宽价格区间
conservative = calculate_liquidity(5000, 3000, 7000, 1, 5000, verbose=False)

# 激进策略：窄价格区间
aggressive = calculate_liquidity(5000, 4800, 5200, 1, 5000, verbose=False)

print(f"保守策略流动性: {conservative['liquidity']}")
print(f"激进策略流动性: {aggressive['liquidity']}")
```

## 🔬 技术细节

### Q64.96 定点数格式

Uniswap V3 使用 Q64.96 格式存储平方根价格：

```
Q64.96 = 整数 × 2^96

示例：
  浮点数: 70.71
  Q64.96: 5602277097478614198912276234240
```

这样可以在 Solidity 中进行高精度计算而无需浮点数。

### 流动性公式

**从代币数量计算 L：**

```
L_x = Δx × (√P_b × √P_c) / (√P_b - √P_c)
L_y = Δy / (√P_c - √P_a)
```

**从 L 计算代币数量：**

```
Δx = L × (√P_b - √P_c) / (√P_b × √P_c)
Δy = L × (√P_c - √P_a)
```

### 为什么选择较小的 L？

当从两种代币分别计算出 L_x 和 L_y 时，我们选择较小的那个，原因是：

1. **均匀分布**：流动性必须在价格曲线上均匀分布
2. **价格不变**：新增流动性不能改变当前价格
3. **比例正确**：较小的 L 确保两种代币的比例匹配

## 📖 相关文档

- [05-第一次交换：流动性计算.md](../docs/1FirstSwap/05-第一次交换：流动性计算.md)
- [Uniswap V3 Development Book](https://uniswapv3book.com/)
- [Uniswap V3 白皮书](https://uniswap.org/whitepaper-v3.pdf)

## 🐛 注意事项

1. **精度问题**：Python 使用浮点数，而 Solidity 使用整数。计算结果可能有微小差异。
2. **Wei 单位**：所有代币数量内部使用 wei（10^18）单位。
3. **价格顺序**：确保 `price_lower < price_current < price_upper`。
4. **正数检查**：代币数量必须大于 0。

## 📝 许可证

MIT License

