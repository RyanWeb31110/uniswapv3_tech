# UniswapV3 技术学习系列（三十五）：NFT 管理合约

## 系列介绍

在上一章中，我们详细学习了 ERC721 标准的核心概念，理解了为什么流动性仓位需要用 NFT 来表示。现在，我们将进入实战环节——**构建一个完整的 NFT 管理合约**，将流动性管理与 NFT 功能完美结合。

本章将实现一个真正的 NFT 仓位管理器，它不仅具备标准的 ERC721 功能，还能管理流动性池中的仓位。这个合约将成为用户与流动性池交互的主要入口。

**本章学习目标**：

1. 理解 NFT 管理合约的架构设计
2. 实现 NFT 与流动性仓位的同步机制
3. 掌握铸造、添加、移除、销毁流动性的完整流程
4. 了解如何使用 Solmate 的 Gas 优化合约

让我们开始构建这个强大的管理合约吧！🎯

---

## 一、设计理念：为什么需要单独的管理合约？

### 1.1 职责分离原则

在前面的章节中，我们构建了 `UniswapV3Manager` 合约来简化与池子合约的交互。现在我们要更进一步——创建一个 **NFT 管理合约**，它不会直接修改池子合约，而是作为一个独立的层来管理流动性。

这种设计遵循了 **关注点分离（Separation of Concerns）** 原则：

- **核心合约（Pool）**：专注于价格计算、交换逻辑、流动性管理等核心功能
- **外围合约（Manager）**：提供友好的用户接口，简化复杂计算
- **NFT 合约（NFT Manager）**：将流动性仓位 NFT 化，提供可视化和可交易性

**合约之间的调用关系**：

| 层级 | 合约类型 | 职责 | 举例 |
|-----|---------|------|------|
| **用户层** | 用户钱包 | 发起交易 | MetaMask 钱包发起操作 |
| **外围层** | NFT Manager | 管理 NFT 和流动性的便捷入口 | 用户调用 `mint()` 铸造 NFT |
| **核心层** | Pool 合约 | 实现核心的 AMM 逻辑 | NFT Manager 调用 `pool.mint()` |
| **基础层** | ERC20 代币 | 提供代币功能 | Pool 调用 `token.transfer()` |

**调用流程示例（添加流动性）**：

1. 用户调用 `NFTManager.mint()` → 铸造 NFT + 添加流动性
2. NFT Manager 调用 `Pool.mint()` → 在池子中添加流动性
3. Pool 通过回调让 NFT Manager 转账代币
4. NFT Manager 调用 `token.transferFrom()` → 从用户账户转入代币

### 1.2 核心设计思路

我们的 NFT 管理合约需要实现以下功能：

| 功能类别 | 具体功能 | 说明 |
|---------|---------|------|
| **ERC721 标准** | `tokenURI` | 返回 NFT 的元数据和图像 URI |
| | `balanceOf`、`ownerOf` | 查询所有权信息 |
| | `transferFrom` | 转移 NFT 所有权 |
| **流动性铸造** | `mint` | 同时铸造 NFT 和添加流动性 |
| **流动性管理** | `addLiquidity` | 为现有仓位增加流动性 |
| | `removeLiquidity` | 从仓位中移除流动性 |
| **代币收取** | `collect` | 收取移除的流动性代币 |
| **NFT 销毁** | `burn` | 销毁已清空的 NFT |

**关键设计约束**：

- ✅ NFT 管理合约是池子中流动性的**实际所有者**
- ✅ 用户不能在不铸造 NFT 的情况下添加流动性
- ✅ 用户不能在不销毁 NFT 的情况下完全移除流动性
- ✅ **NFT 与流动性仓位必须保持同步**

这种设计确保了每个流动性仓位都有对应的 NFT，两者生命周期完全一致。

---

## 二、最小可用合约：基础框架

### 2.1 选择合适的库

我们不打算从零开始实现 ERC721 标准。项目依赖中已经有了 **Solmate** 库，它提供了经过 Gas 优化的 ERC721 实现。

**为什么选择 Solmate 而不是 OpenZeppelin？**

| 对比项 | Solmate | OpenZeppelin |
|-------|---------|--------------|
| **Gas 优化** | 极致优化，Gas 消耗更低 | 相对较高 |
| **代码复杂度** | 简洁明了 | 功能更全面但复杂 |
| **适用场景** | 高频交易、DeFi 协议 | 企业级应用、全面保护 |
| **社区支持** | 活跃的 DeFi 社区 | 最广泛的生态 |

对于 UniswapV3 这种高频交易的 DeFi 协议，**Gas 优化至关重要**，因此我们选择 Solmate。

### 2.2 最小合约实现

让我们从最基础的框架开始：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "solmate/tokens/ERC721.sol";
import "./interfaces/IUniswapV3Pool.sol";

/// @title Uniswap V3 NFT 仓位管理器
/// @notice 将流动性仓位封装为 ERC721 NFT
/// @dev 实现了 NFT 与流动性仓位的同步管理
contract UniswapV3NFTManager is ERC721 {
    // ============ 状态变量 ============

    /// @notice 工厂合约地址（用于验证池子地址）
    address public immutable factory;

    // ============ 构造函数 ============

    /// @notice 初始化 NFT 管理合约
    /// @param factoryAddress 工厂合约地址
    constructor(address factoryAddress)
        ERC721("UniswapV3 NFT Positions", "UNIV3")
    {
        factory = factoryAddress;
    }

    // ============ ERC721 元数据 ============

    /// @notice 返回代币的元数据 URI
    /// @dev 暂时返回空字符串
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return "";
    }
}
```

**代码解析**：

1. **继承 ERC721**：从 Solmate 继承 ERC721 基础实现
2. **factory 变量**：存储工厂合约地址，用于验证池子地址的合法性
3. **tokenURI 存根**：暂时返回空字符串，避免编译错误

**为什么需要 tokenURI？**

- Solmate 的 ERC721 合约中，`tokenURI` 是一个 `virtual` 函数
- 我们**必须实现**这个函数，否则编译器会报错

---

## 三、仓位数据结构：NFT 与流动性的桥梁

### 3.1 核心数据结构设计

为了将 NFT 与流动性仓位关联起来，我们需要一个映射关系：

```solidity
/// @notice 仓位信息结构体
/// @dev 存储查找池子仓位所需的最小信息
struct TokenPosition {
    address pool;       // 所属池子地址
    int24 lowerTick;    // 价格区间下限
    int24 upperTick;    // 价格区间上限
}

/// @notice tokenId => TokenPosition
/// @dev 将 NFT ID 映射到流动性仓位信息
mapping(uint256 => TokenPosition) public positions;
```

### 3.2 为什么这样设计？

**查找流动性仓位需要哪些信息？**

回顾一下 `UniswapV3Pool` 合约中的 `positions` 映射：

```solidity
// Pool 合约中的仓位存储
mapping(bytes32 => Position.Info) public positions;

// 仓位的 key 计算方式
bytes32 positionKey = keccak256(
    abi.encodePacked(owner, lowerTick, upperTick)
);
```

要查找一个仓位，我们需要：

1. ✅ **owner 地址**：NFT 管理合约自己（不需要存储）
2. ✅ **pool 地址**：需要存储
3. ✅ **lowerTick**：需要存储
4. ✅ **upperTick**：需要存储

**为什么不存储 owner？**

因为 NFT 管理合约本身就是所有仓位的 owner！我们不需要存储这个信息，只需要在查询时使用 `address(this)` 即可。

这样的设计既 **节省了 Gas**，又保证了数据的一致性。

---

## 四、铸造功能：同时创建 NFT 和流动性

### 4.1 参数结构设计

铸造功能需要的参数与 `UniswapV3Manager` 类似，但增加了 `recipient` 参数：

```solidity
/// @notice 铸造参数结构体
struct MintParams {
    address recipient;      // NFT 接收者
    address tokenA;         // 代币 A 地址
    address tokenB;         // 代币 B 地址
    uint24 fee;            // 费率档位
    int24 lowerTick;       // 价格区间下限
    int24 upperTick;       // 价格区间上限
    uint256 amount0Desired; // 期望投入的代币 0 数量
    uint256 amount1Desired; // 期望投入的代币 1 数量
    uint256 amount0Min;    // 最小投入的代币 0 数量（滑点保护）
    uint256 amount1Min;    // 最小投入的代币 1 数量（滑点保护）
}
```

### 4.2 铸造函数实现

```solidity
/// @notice 铸造新的 NFT 仓位
/// @param params 铸造参数
/// @return tokenId 新铸造的 NFT ID
function mint(MintParams calldata params)
    public
    returns (uint256 tokenId)
{
    // 步骤 1: 获取池子地址
    IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

    // 步骤 2: 向池子添加流动性
    (uint128 liquidity, uint256 amount0, uint256 amount1) = _addLiquidity(
        AddLiquidityInternalParams({
            pool: pool,
            lowerTick: params.lowerTick,
            upperTick: params.upperTick,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min
        })
    );

    // 步骤 3: 铸造 NFT
    tokenId = nextTokenId++;
    _mint(params.recipient, tokenId);
    totalSupply++;

    // 步骤 4: 存储仓位信息
    TokenPosition memory tokenPosition = TokenPosition({
        pool: address(pool),
        lowerTick: params.lowerTick,
        upperTick: params.upperTick
    });

    positions[tokenId] = tokenPosition;
}
```

**代码逐步解析**：

**步骤 1：获取池子地址**

```solidity
IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);
```

- 通过工厂合约计算或查询池子地址
- 确保池子存在且有效

**步骤 2：添加流动性**

```solidity
(uint128 liquidity, uint256 amount0, uint256 amount1) = _addLiquidity(...);
```

- `_addLiquidity` 函数与 `UniswapV3Manager` 中的实现相同
- 将 Tick 转换为 `√P` 格式
- 计算流动性数量
- 调用 `pool.mint()` 添加流动性

**步骤 3：铸造 NFT**

```solidity
tokenId = nextTokenId++;
_mint(params.recipient, tokenId);
totalSupply++;
```

- `nextTokenId` 是一个递增计数器（从 1 开始）
- `_mint` 是 Solmate ERC721 提供的内部函数
- 更新 `totalSupply`（NFT 总数）

**步骤 4：存储仓位信息**

```solidity
positions[tokenId] = tokenPosition;
```

- 建立 NFT ID 与仓位信息的映射关系
- 后续可以通过 `tokenId` 查找仓位

### 4.3 流程图

```
用户调用 mint()
     ↓
获取池子地址
     ↓
调用 _addLiquidity() 添加流动性
     ↓
生成新的 tokenId
     ↓
铸造 NFT 给 recipient
     ↓
存储 tokenId -> TokenPosition 映射
     ↓
返回 tokenId
```

---

## 五、添加流动性：为现有仓位增加资金

### 5.1 功能说明

有时候，用户希望为已有的仓位增加更多流动性，而不是创建一个新的 NFT。这时候就需要 `addLiquidity` 函数。

**使用场景**：

- 📈 价格回到自己的仓位区间，想增加流动性赚取更多手续费
- 💰 有了更多资金，想在同一价格区间追加投入
- 🔄 想保持仓位数量不变，只增加流动性规模

### 5.2 参数设计

```solidity
/// @notice 添加流动性参数
struct AddLiquidityParams {
    uint256 tokenId;        // 要增加流动性的 NFT ID
    uint256 amount0Desired; // 期望投入的代币 0 数量
    uint256 amount1Desired; // 期望投入的代币 1 数量
    uint256 amount0Min;     // 最小投入的代币 0 数量
    uint256 amount1Min;     // 最小投入的代币 1 数量
}
```

注意：不需要 `pool`、`lowerTick`、`upperTick` 参数，因为这些信息已经存储在 `positions` 映射中。

### 5.3 函数实现

```solidity
/// @notice 为现有仓位添加流动性
/// @param params 添加流动性参数
/// @return liquidity 实际添加的流动性
/// @return amount0 实际投入的代币 0 数量
/// @return amount1 实际投入的代币 1 数量
function addLiquidity(AddLiquidityParams calldata params)
    public
    isApprovedOrOwner(params.tokenId)  // 添加权限检查！
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
{
    // 步骤 1: 获取仓位信息
    TokenPosition memory tokenPosition = positions[params.tokenId];
    if (tokenPosition.pool == address(0x00)) revert WrongToken();

    // 步骤 2: 调用内部函数添加流动性
    (liquidity, amount0, amount1) = _addLiquidity(
        AddLiquidityInternalParams({
            pool: IUniswapV3Pool(tokenPosition.pool),
            lowerTick: tokenPosition.lowerTick,
            upperTick: tokenPosition.upperTick,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min
        })
    );
}
```

**关键点解析**：

1. **权限检查**：使用 `isApprovedOrOwner` 修饰器，**只有 NFT 所有者或被授权者**才能添加流动性
2. **仓位验证**：通过检查 `pool == address(0x00)` 来判断 NFT 是否存在
3. **复用逻辑**：直接使用 `_addLiquidity` 内部函数，代码简洁

**为什么必须有权限检查？**

这是一个非常重要的设计问题！让我们深入分析：

**问题场景：如果任何人都能为别人的仓位添加流动性**

```solidity
// 假设 Alice 拥有 tokenId = 1 的 NFT
// Bob 调用 addLiquidity 为 Alice 的仓位添加流动性

nftManager.addLiquidity({
    tokenId: 1,           // Alice 的 NFT
    amount0Desired: 1000, // Bob 提供的代币
    amount1Desired: 1000
});
```

**会发生什么？**

1. ❌ Bob 的代币被转入池子
2. ❌ 流动性增加到 tokenId = 1 的仓位中
3. ❌ **但 Alice 是 NFT 的所有者，她获得了所有的流动性权益**
4. ❌ Bob 白白损失了代币，却没有得到任何凭证！

**池子中如何存储流动性？**

回忆一下 Pool 合约中仓位的存储结构：

```solidity
// Pool 合约中的仓位存储
mapping(bytes32 => Position.Info) public positions;

// 仓位 key 的计算
bytes32 positionKey = keccak256(
    abi.encodePacked(
        owner,      // NFT Manager 合约地址（固定）
        lowerTick,  // 价格区间下限
        upperTick   // 价格区间上限
    )
);

// 仓位信息
struct Info {
    uint128 liquidity;  // 流动性数量（会累加）
    // ... 其他字段
}
```

**关键点**：

- 池子中的 `owner` 永远是 **NFT Manager 合约地址**
- 流动性是按 `(owner, lowerTick, upperTick)` 组合存储的
- **同一个 tokenId 对应的仓位，流动性会累加在一起**
- 池子合约**不关心**是谁调用的 mint，它只更新对应仓位的流动性数量

**正确的设计**：

✅ 必须添加 `isApprovedOrOwner` 权限检查，确保只有 NFT 所有者才能增加流动性

✅ 这样保证了：
- 谁添加流动性，流动性就属于谁（通过 NFT 所有权体现）
- 不会出现代币被"捐赠"给别人的情况
- NFT 的流动性数量与实际投入的资金对应

### 5.4 与 mint 的区别

| 对比项 | `mint` | `addLiquidity` |
|-------|--------|----------------|
| **创建 NFT** | ✅ 创建新的 NFT | ❌ 不创建 NFT |
| **存储仓位信息** | ✅ 创建新的映射 | ❌ 使用已有映射 |
| **参数数量** | 较多（需要 pool 信息） | 较少（只需 tokenId） |
| **适用场景** | 首次提供流动性 | 追加流动性 |

---

## 六、移除流动性：从仓位中取出资金

### 6.1 功能说明

当用户想要减少或完全移除流动性时，需要调用 `removeLiquidity` 函数。

**重要提醒**：

- ⚠️ 移除流动性 ≠ 销毁 NFT
- ⚠️ 移除流动性后，代币不会立即到账，需要调用 `collect` 收取
- ⚠️ 只有清空流动性并收取代币后，才能销毁 NFT

### 6.2 参数设计

```solidity
/// @notice 移除流动性参数
struct RemoveLiquidityParams {
    uint256 tokenId;   // NFT ID
    uint128 liquidity; // 要移除的流动性数量
}
```

### 6.3 函数实现

```solidity
/// @notice 从仓位中移除流动性
/// @param params 移除流动性参数
/// @return amount0 移除的代币 0 数量
/// @return amount1 移除的代币 1 数量
function removeLiquidity(RemoveLiquidityParams memory params)
    public
    isApprovedOrOwner(params.tokenId)
    returns (uint256 amount0, uint256 amount1)
{
    // 步骤 1: 获取仓位信息
    TokenPosition memory tokenPosition = positions[params.tokenId];
    if (tokenPosition.pool == address(0x00)) revert WrongToken();

    // 步骤 2: 获取池子合约
    IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

    // 步骤 3: 检查可用流动性
    (uint128 availableLiquidity, , , , ) = pool.positions(
        poolPositionKey(tokenPosition)
    );
    if (params.liquidity > availableLiquidity) revert NotEnoughLiquidity();

    // 步骤 4: 调用池子的 burn 函数
    (amount0, amount1) = pool.burn(
        tokenPosition.lowerTick,
        tokenPosition.upperTick,
        params.liquidity
    );
}
```

**关键点解析**：

**修饰器 `isApprovedOrOwner`**：

```solidity
modifier isApprovedOrOwner(uint256 tokenId) {
    require(
        _isApprovedOrOwner(msg.sender, tokenId),
        "Not authorized"
    );
    _;
}
```

- 只有 NFT 的所有者或被授权者才能移除流动性
- 防止恶意用户移除别人的流动性

**流动性检查**：

```solidity
(uint128 availableLiquidity, , , , ) = pool.positions(...);
if (params.liquidity > availableLiquidity) revert NotEnoughLiquidity();
```

- 确保仓位有足够的流动性可以移除
- 避免移除超过实际拥有的流动性

**计算仓位 Key**：

```solidity
function poolPositionKey(TokenPosition memory position)
    internal
    view
    returns (bytes32)
{
    return keccak256(
        abi.encodePacked(
            address(this),  // owner 是 NFT 管理合约
            position.lowerTick,
            position.upperTick
        )
    );
}
```

### 6.4 流动性移除后的状态

调用 `removeLiquidity` 后：

- ✅ 池子中的流动性减少
- ✅ 代币被标记为"待领取"（`tokensOwed0`、`tokensOwed1`）
- ❌ 代币**还没有**转账到用户账户
- ❌ NFT **还没有**被销毁

用户需要调用 `collect` 函数才能真正拿到代币。

---

## 七、收取代币：领取移除的流动性

### 7.1 功能说明

`collect` 函数用于收取移除流动性后的代币，或者收取累积的手续费。

### 7.2 参数设计

```solidity
/// @notice 收取代币参数
struct CollectParams {
    uint256 tokenId; // NFT ID
    uint128 amount0; // 要收取的代币 0 数量
    uint128 amount1; // 要收取的代币 1 数量
}
```

**为什么需要指定数量？**

- 用户可能只想收取部分代币
- 用户可能想分批收取（减少 Gas 消耗）
- 灵活性更高

### 7.3 函数实现

```solidity
/// @notice 收取代币
/// @param params 收取参数
/// @return amount0 实际收取的代币 0 数量
/// @return amount1 实际收取的代币 1 数量
function collect(CollectParams memory params)
    public
    isApprovedOrOwner(params.tokenId)
    returns (uint128 amount0, uint128 amount1)
{
    // 步骤 1: 获取仓位信息
    TokenPosition memory tokenPosition = positions[params.tokenId];
    if (tokenPosition.pool == address(0x00)) revert WrongToken();

    // 步骤 2: 调用池子的 collect 函数
    IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

    (amount0, amount1) = pool.collect(
        msg.sender,  // 代币发送给调用者
        tokenPosition.lowerTick,
        tokenPosition.upperTick,
        params.amount0,
        params.amount1
    );
}
```

**关键设计**：

**代币发送给 `msg.sender`**：

```solidity
pool.collect(msg.sender, ...)
```

- 代币直接发送给调用者，而不是 NFT 管理合约
- NFT 管理合约只是代理，不持有用户资金
- 更安全、更透明

**权限检查**：

- 使用 `isApprovedOrOwner` 修饰器
- 只有 NFT 所有者或被授权者才能收取代币

---

## 八、销毁 NFT：完整的生命周期

### 8.1 销毁前提条件

要销毁一个 NFT，必须满足以下**所有**条件：

1. ✅ 仓位中没有任何流动性（`liquidity == 0`）
2. ✅ 没有待领取的代币（`tokensOwed0 == 0` 且 `tokensOwed1 == 0`）
3. ✅ 调用者是 NFT 所有者或被授权者

这确保了 **NFT 与流动性仓位的完全同步**。

### 8.2 销毁流程

要完全销毁一个 NFT 仓位，需要按以下顺序操作：

```
1. removeLiquidity(tokenId, 全部流动性)
   ↓
2. collect(tokenId, 全部代币)
   ↓
3. burn(tokenId)
```

### 8.3 函数实现

```solidity
/// @notice 销毁 NFT
/// @dev 只能销毁已清空的仓位
/// @param tokenId NFT ID
function burn(uint256 tokenId)
    public
    isApprovedOrOwner(tokenId)
{
    // 步骤 1: 获取仓位信息
    TokenPosition memory tokenPosition = positions[tokenId];
    if (tokenPosition.pool == address(0x00)) revert WrongToken();

    // 步骤 2: 检查仓位是否已清空
    IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);
    (
        uint128 liquidity,
        ,
        ,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) = pool.positions(poolPositionKey(tokenPosition));

    // 步骤 3: 确保仓位完全清空
    if (liquidity > 0 || tokensOwed0 > 0 || tokensOwed1 > 0) {
        revert PositionNotCleared();
    }

    // 步骤 4: 删除仓位信息
    delete positions[tokenId];

    // 步骤 5: 销毁 NFT
    _burn(tokenId);
    totalSupply--;
}
```

**代码解析**：

**检查仓位状态**：

```solidity
(uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) =
    pool.positions(poolPositionKey(tokenPosition));
```

- 从池子合约中读取仓位的完整状态
- 包括流动性数量和待领取代币数量

**三重检查**：

```solidity
if (liquidity > 0 || tokensOwed0 > 0 || tokensOwed1 > 0) {
    revert PositionNotCleared();
}
```

- 确保没有剩余流动性
- 确保没有待领取的代币 0
- 确保没有待领取的代币 1

**清理存储**：

```solidity
delete positions[tokenId];
_burn(tokenId);
totalSupply--;
```

- 删除 `positions` 映射中的记录（释放存储空间，退还 Gas）
- 调用 Solmate 的 `_burn` 函数销毁 NFT
- 更新 `totalSupply`

### 8.4 错误处理示例

**场景 1：忘记移除流动性**

```solidity
// ❌ 错误：直接销毁（会失败）
nftManager.burn(tokenId);
// 错误：PositionNotCleared (流动性 > 0)
```

**场景 2：忘记收取代币**

```solidity
// ✅ 正确：先移除流动性
nftManager.removeLiquidity(tokenId, liquidity);

// ❌ 错误：直接销毁（会失败）
nftManager.burn(tokenId);
// 错误：PositionNotCleared (tokensOwed > 0)
```

**场景 3：正确的销毁流程**

```solidity
// ✅ 步骤 1: 移除所有流动性
nftManager.removeLiquidity(tokenId, liquidity);

// ✅ 步骤 2: 收取所有代币
nftManager.collect(tokenId, amount0, amount1);

// ✅ 步骤 3: 销毁 NFT
nftManager.burn(tokenId);
```

---

## 九、完整合约代码

将所有功能整合在一起，完整的 NFT 管理合约代码如下：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "solmate/tokens/ERC721.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3Factory.sol";

/// @title Uniswap V3 NFT 仓位管理器
/// @notice 将流动性仓位封装为 ERC721 NFT
/// @dev 实现了 NFT 与流动性仓位的同步管理
contract UniswapV3NFTManager is ERC721 {
    // ============ 错误定义 ============

    error WrongToken();
    error NotEnoughLiquidity();
    error PositionNotCleared();

    // ============ 数据结构 ============

    /// @notice 仓位信息结构体
    struct TokenPosition {
        address pool;       // 所属池子地址
        int24 lowerTick;    // 价格区间下限
        int24 upperTick;    // 价格区间上限
    }

    /// @notice 铸造参数
    struct MintParams {
        address recipient;      // NFT 接收者
        address tokenA;         // 代币 A
        address tokenB;         // 代币 B
        uint24 fee;            // 费率
        int24 lowerTick;       // 下限
        int24 upperTick;       // 上限
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice 添加流动性参数
    struct AddLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice 移除流动性参数
    struct RemoveLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
    }

    /// @notice 收取代币参数
    struct CollectParams {
        uint256 tokenId;
        uint128 amount0;
        uint128 amount1;
    }

    // ============ 状态变量 ============

    /// @notice 工厂合约地址
    address public immutable factory;

    /// @notice 下一个 tokenId
    uint256 public nextTokenId = 1;

    /// @notice NFT 总供应量
    uint256 public totalSupply;

    /// @notice tokenId => TokenPosition
    mapping(uint256 => TokenPosition) public positions;

    // ============ 构造函数 ============

    constructor(address factoryAddress)
        ERC721("UniswapV3 NFT Positions", "UNIV3")
    {
        factory = factoryAddress;
    }

    // ============ 核心功能 ============

    /// @notice 铸造新的 NFT 仓位
    function mint(MintParams calldata params)
        public
        returns (uint256 tokenId)
    {
        // 获取池子
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

        // 添加流动性
        (uint128 liquidity, uint256 amount0, uint256 amount1) = _addLiquidity(
            AddLiquidityInternalParams({
                pool: pool,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        // 铸造 NFT
        tokenId = nextTokenId++;
        _mint(params.recipient, tokenId);
        totalSupply++;

        // 存储仓位信息
        positions[tokenId] = TokenPosition({
            pool: address(pool),
            lowerTick: params.lowerTick,
            upperTick: params.upperTick
        });
    }

    /// @notice 为现有仓位添加流动性
    function addLiquidity(AddLiquidityParams calldata params)
        public
        isApprovedOrOwner(params.tokenId)
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        TokenPosition memory tokenPosition = positions[params.tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        (liquidity, amount0, amount1) = _addLiquidity(
            AddLiquidityInternalParams({
                pool: IUniswapV3Pool(tokenPosition.pool),
                lowerTick: tokenPosition.lowerTick,
                upperTick: tokenPosition.upperTick,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );
    }

    /// @notice 从仓位中移除流动性
    function removeLiquidity(RemoveLiquidityParams memory params)
        public
        isApprovedOrOwner(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        TokenPosition memory tokenPosition = positions[params.tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

        (uint128 availableLiquidity, , , , ) = pool.positions(
            poolPositionKey(tokenPosition)
        );
        if (params.liquidity > availableLiquidity) revert NotEnoughLiquidity();

        (amount0, amount1) = pool.burn(
            tokenPosition.lowerTick,
            tokenPosition.upperTick,
            params.liquidity
        );
    }

    /// @notice 收取代币
    function collect(CollectParams memory params)
        public
        isApprovedOrOwner(params.tokenId)
        returns (uint128 amount0, uint128 amount1)
    {
        TokenPosition memory tokenPosition = positions[params.tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

        (amount0, amount1) = pool.collect(
            msg.sender,
            tokenPosition.lowerTick,
            tokenPosition.upperTick,
            params.amount0,
            params.amount1
        );
    }

    /// @notice 销毁 NFT
    function burn(uint256 tokenId)
        public
        isApprovedOrOwner(tokenId)
    {
        TokenPosition memory tokenPosition = positions[tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) =
            pool.positions(poolPositionKey(tokenPosition));

        if (liquidity > 0 || tokensOwed0 > 0 || tokensOwed1 > 0) {
            revert PositionNotCleared();
        }

        delete positions[tokenId];
        _burn(tokenId);
        totalSupply--;
    }

    // ============ ERC721 元数据 ============

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return "";
    }

    // ============ 内部辅助函数 ============

    modifier isApprovedOrOwner(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        _;
    }

    function poolPositionKey(TokenPosition memory position)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(address(this), position.lowerTick, position.upperTick)
        );
    }

    // ... 其他辅助函数（getPool、_addLiquidity 等）
}
```

---

## 十、核心知识点总结

### 10.1 设计模式与原则

**1. 关注点分离（Separation of Concerns）**

- ✅ 核心合约（Pool）：专注于核心逻辑
- ✅ 外围合约（Manager）：提供友好接口
- ✅ NFT 合约：实现可视化和可交易性

**2. 代理模式（Proxy Pattern）**

- NFT 管理合约作为用户的代理
- 它是池子中流动性的实际所有者
- 用户通过 NFT 间接拥有流动性

**3. 同步约束（Synchronization Constraint）**

- NFT 与流动性仓位必须保持同步
- 不能在不铸造 NFT 的情况下添加流动性
- 不能在不销毁 NFT 的情况下完全移除流动性

### 10.2 关键技术点

| 技术点 | 说明 |
|-------|------|
| **Solmate ERC721** | Gas 优化的 NFT 实现 |
| **TokenPosition 映射** | 将 NFT ID 映射到仓位信息 |
| **修饰器 isApprovedOrOwner** | 权限检查 |
| **三步销毁流程** | removeLiquidity → collect → burn |
| **Gas 优化** | 使用 `delete` 释放存储空间 |

### 10.3 生命周期管理

**完整的 NFT 仓位生命周期**：

```
1. mint()
   → 创建 NFT + 添加流动性

2. addLiquidity() (可选)
   → 增加流动性

3. removeLiquidity()
   → 移除部分或全部流动性

4. collect()
   → 收取代币

5. burn()
   → 销毁 NFT
```

### 10.4 安全注意事项

**权限控制**：

- ✅ `addLiquidity` 需要 `isApprovedOrOwner` 检查
- ✅ `removeLiquidity` 需要 `isApprovedOrOwner` 检查
- ✅ `collect` 需要 `isApprovedOrOwner` 检查
- ✅ `burn` 需要 `isApprovedOrOwner` 检查

**为什么所有操作都需要权限检查？**

因为池子中的流动性是按 `(NFT Manager, lowerTick, upperTick)` 存储的，如果允许任何人添加流动性，就会出现"捐赠"问题——出资者无法获得对应的权益

**状态检查**：

- ✅ 销毁前检查流动性是否为 0
- ✅ 销毁前检查待领取代币是否为 0
- ✅ 移除流动性前检查可用流动性是否足够

**Gas 优化**：

- ✅ 使用 `delete` 释放存储空间
- ✅ 使用 Solmate 的 Gas 优化实现
- ✅ 使用 `immutable` 标记不可变变量

---

## 项目仓库

本项目 GitHub 仓库：
https://github.com/RyanWeb31110/uniswapv3_tech

系列项目：
- [UniswapV1 技术学习](https://github.com/RyanWeb31110/uniswapv1_tech)
- [UniswapV2 技术学习](https://github.com/RyanWeb31110/uniswapv2_tech)
- [UniswapV3 技术学习](https://github.com/RyanWeb31110/uniswapv3_tech)

欢迎 Star 和 Fork，一起学习交流！

**原文链接**：https://uniswapv3book.com/milestone_6/nft-manager.html
