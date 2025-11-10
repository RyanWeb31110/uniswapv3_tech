# UniswapV3 技术学习系列（三十六）：NFT 渲染器

## 系列介绍

在前面的章节中,我们已经完成了 NFT 管理合约的核心功能实现——铸造、添加、移除和销毁流动性仓位。现在,我们要让这些 NFT 真正"活"起来——为每个仓位生成独特的可视化图像！

在第三十四章中,我们学习了 ERC721 标准的 `tokenURI` 函数,它负责返回 NFT 的元数据和图像。在第三十五章中,我们实现了 NFT 管理合约,但 `tokenURI` 函数还只是返回空字符串。现在,我们将填补这个空白——**构建一个链上 NFT 渲染器**!

**本章学习目标**:

1. 理解链上 NFT 渲染的技术原理
2. 掌握 SVG 图像的动态生成技术
3. 学习 Base64 编码在 Solidity 中的应用
4. 实现完整的 NFT 元数据和图像渲染
5. 了解链上存储的成本优化策略

让我们一起来打造独一无二的链上 NFT 吧! 🎨

---

## 一、为什么需要 NFT 渲染器?

### 1.1 链下存储 vs 链上存储

在大多数 NFT 项目中,图像和元数据都存储在**链下**（IPFS、HTTP 服务器等）,`tokenURI` 只是返回一个链接:

```solidity
// 典型的链下存储方案
function tokenURI(uint256 tokenId) public view returns (string memory) {
    return string(abi.encodePacked(
        "https://api.example.com/metadata/",
        Strings.toString(tokenId),
        ".json"
    ));
}
```

**链下存储的问题**:

- ❌ **中心化风险**: 服务器可能宕机或被关闭
- ❌ **数据可变**: 元数据可能被篡改
- ❌ **依赖性**: 依赖外部服务的可用性

**链上存储的优势**:

- ✅ **完全去中心化**: 数据永久存储在区块链上
- ✅ **不可篡改**: 一旦部署,数据无法更改
- ✅ **无需信任**: 不依赖任何第三方服务
- ✅ **动态生成**: 可以根据链上数据动态生成图像

### 1.2 UniswapV3 NFT 的特殊性

UniswapV3 的流动性仓位 NFT 非常适合链上存储,因为:

1. **数据量小**: 只需要存储 SVG 模板和少量仓位数据
2. **动态生成**: 每个仓位的图像都是根据参数动态生成的
3. **永久性**: 流动性仓位信息应该永久可访问
4. **可组合性**: 链上数据便于与其他合约交互

---

## 二、NFT 图像设计: 简化版 UniswapV3 NFT

### 2.1 设计思路

我们将构建一个简化版的 UniswapV3 NFT,它包含以下信息:

- 🎨 **独特的背景色**: 每个 NFT 有不同的色调
- 💱 **代币对信息**: 显示池子的代币符号（如 WETH/USDC）
- 📊 **费率档位**: 显示池子的费率（如 0.05%）
- 📍 **价格区间**: 显示仓位的 Tick 边界

### 2.2 SVG 模板结构

这是我们的 SVG 模板结构:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 480">
  <!-- CSS 样式 -->
  <style>
    .tokens { font: bold 30px sans-serif; }
    .fee { font: normal 26px sans-serif; }
    .tick { font: normal 18px sans-serif; }
  </style>

  <!-- 背景层（深色） -->
  <rect width="300" height="480" fill="hsl(330,40%,40%)" />

  <!-- 主体层（浅色，圆角） -->
  <rect x="30" y="30" width="240" height="420" rx="15" ry="15"
        fill="hsl(330,90%,50%)" stroke="#000" />

  <!-- 代币对信息 -->
  <rect x="30" y="87" width="240" height="42" />
  <text x="39" y="120" class="tokens" fill="#fff">
    WETH/USDC
  </text>

  <!-- 费率信息 -->
  <rect x="30" y="132" width="240" height="30" />
  <text x="39" y="120" dy="36" class="fee" fill="#fff">
    0.05%
  </text>

  <!-- 下限 Tick -->
  <rect x="30" y="342" width="240" height="24" />
  <text x="39" y="360" class="tick" fill="#fff">
    Lower tick: 123456
  </text>

  <!-- 上限 Tick -->
  <rect x="30" y="372" width="240" height="24" />
  <text x="39" y="360" dy="30" class="tick" fill="#fff">
    Upper tick: 123456
  </text>
</svg>
```

**SVG 结构解析**:

| 元素类型 | 作用 | 动态字段 |
|---------|------|---------|
| `<style>` | CSS 样式定义 | 固定不变 |
| 背景 `<rect>` | 深色背景 | 色调值（hue）动态变化 |
| 主体 `<rect>` | 浅色圆角矩形 | 色调值（hue）动态变化 |
| 代币对 `<text>` | 显示代币符号 | 代币符号动态生成 |
| 费率 `<text>` | 显示费率 | 费率动态生成 |
| Tick `<text>` | 显示价格区间 | Tick 值动态生成 |

### 2.3 色调（Hue）的计算

为了让每个 NFT 都有独特的颜色,我们使用以下算法:

$$
\text{hue} = \text{keccak256}(\text{owner}, \text{lowerTick}, \text{upperTick}) \mod 360
$$

其中:
- `owner` 是 NFT 管理合约地址
- `lowerTick` 是价格区间下限
- `upperTick` 是价格区间上限
- `360` 是色调的取值范围（0-360 度）

**HSL 颜色模型**:

- **H (Hue)**: 色调,取值 0-360 度（0=红色,120=绿色,240=蓝色）
- **S (Saturation)**: 饱和度,取值 0-100%
- **L (Lightness)**: 亮度,取值 0-100%

示例: `hsl(330, 40%, 40%)` 表示粉红色调、中等饱和度、中等亮度。

---

## 三、依赖库准备

### 3.1 Base64 编码库

Solidity 本身不提供 Base64 编码功能,我们需要使用第三方库。我们选择 **OpenZeppelin** 的 Base64 实现:

```bash
# 安装 OpenZeppelin 合约库
forge install OpenZeppelin/openzeppelin-contracts
```

在 Solidity 中引入:

```solidity
import "@openzeppelin/contracts/utils/Base64.sol";
```

### 3.2 字符串处理库

Solidity 对字符串操作的支持非常有限,甚至不能直接将整数转换为字符串。我们需要使用 OpenZeppelin 的 `Strings` 库:

```solidity
import "@openzeppelin/contracts/utils/Strings.sol";
```

**Strings 库的核心功能**:

```solidity
// 将 uint256 转换为字符串
Strings.toString(123456) // => "123456"

// 将地址转换为十六进制字符串
Strings.toHexString(address(0x1234...)) // => "0x1234..."
```

---

## 四、数据 URI 格式详解

### 4.1 什么是 Data URI?

**Data URI Scheme** 是一种在 URI 中直接嵌入数据的格式,而不是引用外部资源。

**格式规范**:

```
data:[<mediatype>][;base64],<data>
```

**参数说明**:
- `data:` — 协议标识符
- `<mediatype>` — MIME 类型（可选,默认 `text/plain;charset=US-ASCII`）
- `;base64` — 编码方式（可选,表示数据是 Base64 编码的）
- `<data>` — 实际数据内容

### 4.2 应用示例

**JSON 元数据**:

```
data:application/json;base64,eyJuYW1lIjoiVW5pc3dhcCBWMyBQb3NpdGlvbiJ9
```

Base64 解码后:

```json
{
  "name": "Uniswap V3 Position"
}
```

**SVG 图像**:

```
data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+
```

Base64 解码后:

```svg
<svg width="100" height="100"></svg>
```

### 4.3 NFT 元数据格式

我们的 NFT 元数据将采用以下格式:

```json
{
  "name": "Uniswap V3 Position",
  "description": "USDC/DAI 0.05%, Lower tick: -520, Upper tick: 490",
  "image": "data:image/svg+xml;base64,<BASE64_ENCODED_SVG>"
}
```

最终,整个 JSON 也会被 Base64 编码:

```
data:application/json;base64,<BASE64_ENCODED_JSON>
```

---

## 五、NFT 渲染器实现

### 5.1 渲染器库结构

我们将渲染器实现为一个独立的**库合约**（Library）,以保持代码的模块化:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/IERC20.sol";

/// @title NFT 渲染器
/// @notice 为 UniswapV3 仓位生成链上 SVG 和 JSON 元数据
library NFTRenderer {
    using Strings for uint256;

    /// @notice 渲染参数结构体
    struct RenderParams {
        address pool;       // 池子地址
        address owner;      // NFT 管理合约地址
        int24 lowerTick;    // 价格区间下限
        int24 upperTick;    // 价格区间上限
        uint24 fee;         // 费率档位
    }

    /// @notice 渲染 NFT 元数据
    /// @param params 渲染参数
    /// @return 完整的 Data URI（包含 JSON 和 SVG）
    function render(RenderParams memory params)
        internal
        view
        returns (string memory)
    {
        // 实现将在后面章节展开
    }
}
```

### 5.2 主渲染函数实现

```solidity
/// @notice 渲染 NFT 元数据
function render(RenderParams memory params)
    internal
    view
    returns (string memory)
{
    // 步骤 1: 获取代币符号
    IUniswapV3Pool pool = IUniswapV3Pool(params.pool);
    IERC20 token0 = IERC20(pool.token0());
    IERC20 token1 = IERC20(pool.token1());
    string memory symbol0 = token0.symbol();
    string memory symbol1 = token1.symbol();

    // 步骤 2: 渲染 SVG 图像
    string memory image = string.concat(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 480'>",
        "<style>.tokens { font: bold 30px sans-serif; }",
        ".fee { font: normal 26px sans-serif; }",
        ".tick { font: normal 18px sans-serif; }</style>",
        renderBackground(params.owner, params.lowerTick, params.upperTick),
        renderTop(symbol0, symbol1, params.fee),
        renderBottom(params.lowerTick, params.upperTick),
        "</svg>"
    );

    // 步骤 3: 渲染描述文本
    string memory description = renderDescription(
        symbol0,
        symbol1,
        params.fee,
        params.lowerTick,
        params.upperTick
    );

    // 步骤 4: 组装 JSON 元数据
    string memory json = string.concat(
        '{"name":"Uniswap V3 Position",',
        '"description":"',
        description,
        '",',
        '"image":"data:image/svg+xml;base64,',
        Base64.encode(bytes(image)),
        '"}'
    );

    // 步骤 5: 返回 Base64 编码的 Data URI
    return string.concat(
        "data:application/json;base64,",
        Base64.encode(bytes(json))
    );
}
```

**渲染流程图**:

```
1. 获取代币符号（symbol0, symbol1）
     ↓
2. 生成 SVG 图像
   ├── 渲染背景（动态色调）
   ├── 渲染顶部信息（代币对 + 费率）
   └── 渲染底部信息（Tick 区间）
     ↓
3. 生成描述文本
     ↓
4. 组装 JSON 元数据
     ↓
5. Base64 编码并返回 Data URI
```

---

## 六、SVG 渲染: 分步实现

### 6.1 背景渲染: 动态色调计算

```solidity
/// @notice 渲染背景（包含动态色调）
/// @param owner NFT 管理合约地址
/// @param lowerTick 价格区间下限
/// @param upperTick 价格区间上限
/// @return background 背景 SVG 代码
function renderBackground(
    address owner,
    int24 lowerTick,
    int24 upperTick
) internal pure returns (string memory background) {
    // 计算唯一的色调值（0-360）
    bytes32 key = keccak256(abi.encodePacked(owner, lowerTick, upperTick));
    uint256 hue = uint256(key) % 360;

    // 拼接 SVG 代码
    background = string.concat(
        // 深色背景层
        '<rect width="300" height="480" fill="hsl(',
        Strings.toString(hue),
        ',40%,40%)"/>',
        // 浅色主体层（圆角矩形）
        '<rect x="30" y="30" width="240" height="420" rx="15" ry="15" fill="hsl(',
        Strings.toString(hue),
        ',100%,50%)" stroke="#000"/>'
    );
}
```

**关键技术点**:

1. **唯一性保证**: 使用 `keccak256(owner, lowerTick, upperTick)` 确保每个仓位有独特的颜色
2. **取模运算**: `% 360` 将哈希值映射到色调范围（0-360 度）
3. **HSL 颜色**: 深色背景使用 `hsl(hue, 40%, 40%)`,浅色主体使用 `hsl(hue, 100%, 50%)`

### 6.2 顶部信息渲染: 代币对 + 费率

```solidity
/// @notice 渲染顶部信息（代币对 + 费率）
/// @param symbol0 代币 0 的符号
/// @param symbol1 代币 1 的符号
/// @param fee 费率档位（500/3000/10000）
/// @return top 顶部 SVG 代码
function renderTop(
    string memory symbol0,
    string memory symbol1,
    uint24 fee
) internal pure returns (string memory top) {
    top = string.concat(
        // 代币对背景
        '<rect x="30" y="87" width="240" height="42"/>',
        // 代币对文本
        '<text x="39" y="120" class="tokens" fill="#fff">',
        symbol0,
        "/",
        symbol1,
        "</text>",
        // 费率背景
        '<rect x="30" y="132" width="240" height="30"/>',
        // 费率文本
        '<text x="39" y="120" dy="36" class="fee" fill="#fff">',
        feeToText(fee),
        "</text>"
    );
}
```

**费率转换函数**:

```solidity
/// @notice 将费率数值转换为百分比文本
/// @param fee 费率档位（500 = 0.05%、3000 = 0.3%、10000 = 1%）
/// @return feeString 费率文本
function feeToText(uint256 fee)
    internal
    pure
    returns (string memory feeString)
{
    if (fee == 500) {
        feeString = "0.05%";
    } else if (fee == 3000) {
        feeString = "0.3%";
    } else if (fee == 10000) {
        feeString = "1%";
    }
}
```

**为什么硬编码费率?**

- UniswapV3 只支持三个标准费率: 0.05%、0.3%、1%
- 硬编码避免了复杂的浮点数计算
- 节省 Gas 消耗

### 6.3 底部信息渲染: Tick 区间

```solidity
/// @notice 渲染底部信息（Tick 区间）
/// @param lowerTick 价格区间下限
/// @param upperTick 价格区间上限
/// @return bottom 底部 SVG 代码
function renderBottom(int24 lowerTick, int24 upperTick)
    internal
    pure
    returns (string memory bottom)
{
    bottom = string.concat(
        // Lower Tick 背景
        '<rect x="30" y="342" width="240" height="24"/>',
        // Lower Tick 文本
        '<text x="39" y="360" class="tick" fill="#fff">Lower tick: ',
        tickToText(lowerTick),
        "</text>",
        // Upper Tick 背景
        '<rect x="30" y="372" width="240" height="24"/>',
        // Upper Tick 文本
        '<text x="39" y="360" dy="30" class="tick" fill="#fff">Upper tick: ',
        tickToText(upperTick),
        "</text>"
    );
}
```

**Tick 转字符串函数**:

```solidity
/// @notice 将 Tick 值转换为字符串（支持负数）
/// @param tick Tick 值（可能为负数）
/// @return tickString Tick 字符串表示
function tickToText(int24 tick)
    internal
    pure
    returns (string memory tickString)
{
    tickString = string.concat(
        // 添加负号（如果是负数）
        tick < 0 ? "-" : "",
        // 转换绝对值为字符串
        tick < 0
            ? Strings.toString(uint256(uint24(-tick)))
            : Strings.toString(uint256(uint24(tick)))
    );
}
```

**处理负数的技巧**:

1. **符号处理**: 通过 `tick < 0 ? "-" : ""` 添加负号
2. **类型转换**: `int24 → uint24 → uint256 → string`
3. **绝对值**: 负数需要先取反 `-tick`,再转换

---

## 七、JSON 元数据渲染

### 7.1 描述文本生成

```solidity
/// @notice 渲染描述文本
/// @param symbol0 代币 0 的符号
/// @param symbol1 代币 1 的符号
/// @param fee 费率档位
/// @param lowerTick 价格区间下限
/// @param upperTick 价格区间上限
/// @return description 描述文本
function renderDescription(
    string memory symbol0,
    string memory symbol1,
    uint24 fee,
    int24 lowerTick,
    int24 upperTick
) internal pure returns (string memory description) {
    description = string.concat(
        symbol0,
        "/",
        symbol1,
        " ",
        feeToText(fee),
        ", Lower tick: ",
        tickToText(lowerTick),
        ", Upper tick: ",
        tickToText(upperTick)
    );
}
```

**示例输出**:

```
USDC/DAI 0.05%, Lower tick: -520, Upper tick: 490
```

### 7.2 完整流程回顾

让我们回顾一下 `render` 函数的完整流程:

```solidity
function render(RenderParams memory params)
    internal
    view
    returns (string memory)
{
    // 1 获取代币符号
    string memory symbol0 = ...;
    string memory symbol1 = ...;

    // 2 生成 SVG 图像
    string memory image = string.concat(
        "<svg ...>",
        renderBackground(...),  // 背景 + 色调
        renderTop(...),         // 代币对 + 费率
        renderBottom(...),      // Tick 区间
        "</svg>"
    );

    // 3 生成描述文本
    string memory description = renderDescription(...);

    // 4 组装 JSON
    string memory json = string.concat(
        '{"name":"Uniswap V3 Position",',
        '"description":"', description, '",',
        '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(image)), '"}'
    );

    // 5 返回 Data URI
    return string.concat(
        "data:application/json;base64,",
        Base64.encode(bytes(json))
    );
}
```

---

## 八、集成到 NFT 管理合约

### 8.1 填补 tokenURI 的空白

现在,我们可以在 NFT 管理合约中调用渲染器了:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./libraries/NFTRenderer.sol";

contract UniswapV3NFTManager is ERC721 {
    // ... 其他代码 ...

    /// @notice 返回 NFT 的元数据 URI
    /// @param tokenId NFT ID
    /// @return 完整的 Data URI
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        // 步骤 1: 获取仓位信息
        TokenPosition memory tokenPosition = positions[tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        // 步骤 2: 获取池子合约
        IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

        // 步骤 3: 调用渲染器
        return NFTRenderer.render(
            NFTRenderer.RenderParams({
                pool: tokenPosition.pool,
                owner: address(this),        // NFT 管理合约地址
                lowerTick: tokenPosition.lowerTick,
                upperTick: tokenPosition.upperTick,
                fee: pool.fee()
            })
        );
    }
}
```

**关键点**:

1. **仓位验证**: 检查 `pool == address(0x00)` 确保 NFT 存在
2. **获取费率**: 从池子合约中读取 `fee()`
3. **owner 参数**: 传入 `address(this)`（NFT 管理合约地址）用于计算色调

### 8.2 完整调用流程

```
用户/钱包调用 tokenURI(tokenId)
     ↓
NFT 管理合约
├── 验证 tokenId 有效性
├── 读取 positions[tokenId]
└── 调用 NFTRenderer.render()
     ↓
NFT 渲染器
├── 读取代币符号
├── 生成 SVG 图像
│   ├── renderBackground() → 计算色调
│   ├── renderTop() → 代币对 + 费率
│   └── renderBottom() → Tick 区间
├── 生成描述文本
├── 组装 JSON 元数据
└── Base64 编码并返回
     ↓
返回 Data URI 给用户
```

---

## 九、Gas 成本优化

### 9.1 链上存储的成本问题

链上存储 NFT 数据有一个**巨大的缺点**: **合约部署成本非常高**。

**为什么这么贵?**

1. **按字节收费**: 部署合约时,每个字节的代码都需要支付 Gas
2. **字符串占用大**: SVG 模板中的大量字符串会显著增加合约大小
3. **重复代码**: 模板中的 `<rect>` 、`<text>` 等标签重复出现

**示例对比**:

| 合约类型 | 代码大小 | 部署成本（估算） |
|---------|---------|----------------|
| 简单 ERC20 | ~5 KB | ~500,000 Gas |
| 无渲染器的 NFT | ~15 KB | ~1,500,000 Gas |
| **带渲染器的 NFT** | **~40 KB** | **~4,000,000 Gas** |

### 9.2 优化策略

#### 策略 1: 提取重复字符串

**优化前**:

```solidity
function renderBottom(...) internal pure returns (string memory) {
    return string.concat(
        '<rect x="30" y="342" width="240" height="24"/>',
        '<text x="39" y="360" class="tick" fill="#fff">Lower tick: ',
        tickToText(lowerTick),
        "</text>",
        '<rect x="30" y="372" width="240" height="24"/>',
        '<text x="39" y="360" dy="30" class="tick" fill="#fff">Upper tick: ',
        tickToText(upperTick),
        "</text>"
    );
}
```

**优化后**:

```solidity
function renderBottom(...) internal pure returns (string memory) {
    string memory RECT = '<rect x="30" y="';
    string memory TEXT = '<text x="39" y="360" class="tick" fill="#fff">';

    return string.concat(
        RECT, '342" width="240" height="24"/>',
        TEXT, 'Lower tick: ', tickToText(lowerTick), '</text>',
        RECT, '372" width="240" height="24"/>',
        TEXT, 'Upper tick: ', tickToText(upperTick), '</text>'
    );
}
```

#### 策略 2: 压缩 SVG 代码

- 删除不必要的空格和换行
- 使用更短的 CSS 类名
- 合并相同的样式

#### 策略 3: 使用库合约

将渲染器实现为 **Library**,而不是直接写在主合约中,可以:

- 减少主合约的代码大小
- 通过 `delegatecall` 调用,节省部署成本

### 9.3 本教程的选择

在本教程中,我们**优先考虑代码可读性**,而不是 Gas 优化:

- ✅ 代码结构清晰,易于理解
- ✅ 便于学习和修改
- ❌ 没有进行极致的 Gas 优化

**生产环境的考量**:

在实际的 NFT 项目中,开发者通常会:

- 牺牲可读性,进行极致的 Gas 优化
- 使用代码混淆和压缩技术
- 权衡链上存储和链下存储的成本

---

## 十、测试 NFT 渲染

### 10.1 为什么测试很重要?

NFT 渲染的测试非常重要,因为:

- ✅ 确保所有变更不会破坏图像生成
- ✅ 验证 Base64 编码的正确性
- ✅ 检查不同参数组合的渲染结果
- ✅ 预览整个 NFT 集合的视觉效果

### 10.2 自定义断言: 文件对比

我们可以创建一个自定义断言,将 `tokenURI` 的输出与预期文件进行对比:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

contract NFTRendererTest is Test {
    /// @notice 自定义断言: 对比 tokenURI 输出与预期文件
    /// @param actual 实际输出
    /// @param expectedFixture 预期文件名（相对于 test/fixtures/ 目录）
    /// @param errMessage 错误信息
    function assertTokenURI(
        string memory actual,
        string memory expectedFixture,
        string memory errMessage
    ) internal {
        // 读取预期文件内容
        string memory expected = vm.readFile(
            string.concat("./test/fixtures/", expectedFixture)
        );

        // 对比实际输出和预期内容
        assertEq(actual, string(expected), errMessage);
    }
}
```

**使用 Foundry 的 cheat code**:

- `vm.readFile()` 是 forge-std 提供的作弊码
- 可以读取本地文件系统的文件内容
- 需要在 `foundry.toml` 中配置文件系统权限

### 10.3 配置文件系统权限

在 `foundry.toml` 中添加:

```toml
[profile.default]
# 允许读取当前目录下的文件
fs_permissions = [{access = "read", path = "."}]
```

### 10.4 测试用例示例

```solidity
function testTokenURI() public {
    // 铸造一个 NFT
    uint256 tokenId = nftManager.mint(
        MintParams({
            recipient: alice,
            tokenA: address(token0),
            tokenB: address(token1),
            fee: 500,
            lowerTick: -600,
            upperTick: 600,
            amount0Desired: 1 ether,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0
        })
    );

    // 获取 tokenURI 输出
    string memory uri = nftManager.tokenURI(tokenId);

    // 对比预期文件
    assertTokenURI(uri, "tokenuri0", "invalid token URI");
}
```

### 10.5 提取和查看 SVG

如何从 Data URI 中提取并查看 SVG 图像?

使用以下 Shell 命令:

```bash
# 读取 fixture 文件
cat test/fixtures/tokenuri0 \
  # 提取 Base64 编码的 JSON（逗号分隔的第 2 部分）
  | awk -F ',' '{print $2}' \
  # Base64 解码
  | base64 -d - \
  # 提取 image 字段
  | jq -r .image \
  # 提取 Base64 编码的 SVG（逗号分隔的第 2 部分）
  | awk -F ',' '{print $2}' \
  # Base64 解码并保存为 nft.svg
  | base64 -d - > nft.svg \
  # 在浏览器中打开
  && open nft.svg
```

**工具要求**:

- `awk`: 文本处理工具（macOS/Linux 自带）
- `base64`: Base64 编解码工具（macOS/Linux 自带）
- `jq`: JSON 处理工具（需安装: `brew install jq`）

---

## 十一、核心知识点总结

### 11.1 链上 NFT 渲染的核心技术

| 技术点 | 说明 | 应用 |
|-------|------|------|
| **Data URI** | 在 URI 中直接嵌入数据 | 实现链上存储 |
| **Base64 编码** | 将二进制数据编码为 ASCII 字符串 | 嵌入 SVG 和 JSON |
| **SVG 动态生成** | 在 Solidity 中拼接 SVG 代码 | 生成独特的 NFT 图像 |
| **HSL 颜色模型** | 通过色调、饱和度、亮度定义颜色 | 为每个 NFT 生成独特颜色 |
| **字符串处理** | 使用 Strings 库转换类型 | 将整数转换为字符串 |

### 11.2 渲染流程回顾

```
1. 获取仓位数据（tokenId → pool, lowerTick, upperTick）
     ↓
2. 获取代币符号（pool → token0, token1 → symbol0, symbol1）
     ↓
3. 生成 SVG 图像
   ├── 计算色调（keccak256(owner, lowerTick, upperTick) % 360）
   ├── 渲染背景（HSL 颜色）
   ├── 渲染代币对和费率
   └── 渲染 Tick 区间
     ↓
4. 生成描述文本
     ↓
5. 组装 JSON 元数据
     ↓
6. Base64 编码（SVG 和 JSON）
     ↓
7. 返回 Data URI
```

### 11.3 优势与权衡

**链上存储的优势**:

- ✅ 完全去中心化,永久可访问
- ✅ 不可篡改,数据安全
- ✅ 无需信任第三方服务
- ✅ 动态生成,可根据链上数据变化

**链上存储的成本**:

- ❌ 部署成本高（可能是普通合约的 2-3 倍）
- ❌ 代码可读性差（需要极致优化）
- ❌ 图像复杂度受限（文件大小限制）

### 11.4 实践要点

1. **模块化设计**: 使用 Library 将渲染器与主合约分离
2. **可测试性**: 使用文件对比断言,确保渲染输出正确
3. **Gas 优化**: 生产环境需要权衡可读性和成本
4. **字符串处理**: 充分利用 OpenZeppelin 的 Strings 库
5. **颜色设计**: 使用 HSL 颜色模型,基于哈希值生成独特颜色

---

## 相关资源

- [Data URI Scheme 规范](https://datatracker.ietf.org/doc/html/rfc2397)
- [SVG 完整教程](https://developer.mozilla.org/zh-CN/docs/Web/SVG)
- [OpenZeppelin Base64 实现](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Base64.sol)
- [OpenZeppelin Strings 库](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol)
- [Forge 文件系统权限配置](https://book.getfoundry.sh/reference/config/testing#fs_permissions)

---

## 项目仓库

本项目 GitHub 仓库:
https://github.com/RyanWeb31110/uniswapv3_tech

系列项目:
- [UniswapV1 技术学习](https://github.com/RyanWeb31110/uniswapv1_tech)
- [UniswapV2 技术学习](https://github.com/RyanWeb31110/uniswapv2_tech)
- [UniswapV3 技术学习](https://github.com/RyanWeb31110/uniswapv3_tech)

欢迎 Star 和 Fork,一起学习交流!

**原文链接**: https://uniswapv3book.com/milestone_6/nft-renderer.html
