// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solmate/tokens/ERC721.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IERC20.sol";
import "./lib/TickMath.sol";
import "./lib/LiquidityAmounts.sol";
import "./lib/PoolAddress.sol";
import "./lib/NFTRenderer.sol";

/// @title Uniswap V3 NFT 仓位管理器
/// @notice 将流动性仓位封装为 ERC721 NFT
/// @dev 实现了 NFT 与流动性仓位的同步管理
contract UniswapV3NFTManager is ERC721 {
    // ============ 错误定义 ============

    error WrongToken();
    error NotEnoughLiquidity();
    error PositionNotCleared();
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    // ============ 数据结构 ============

    /// @notice 仓位信息结构体
    /// @dev 存储查找池子仓位所需的最小信息
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

    /// @notice 内部使用的添加流动性参数
    struct AddLiquidityInternalParams {
        IUniswapV3Pool pool;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
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
    /// @dev 同时创建 NFT 和添加流动性
    /// @param params 铸造参数
    /// @return tokenId 新铸造的 NFT ID
    /// @return liquidity 实际添加的流动性
    /// @return amount0 实际投入的代币 0 数量
    /// @return amount1 实际投入的代币 1 数量
    function mint(MintParams calldata params)
        public
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // 获取池子
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

        // 添加流动性
        (liquidity, amount0, amount1) = _addLiquidity(
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
    /// @dev 只有 NFT 所有者或被授权者才能调用
    /// @param params 添加流动性参数
    /// @return liquidity 实际添加的流动性
    /// @return amount0 实际投入的代币 0 数量
    /// @return amount1 实际投入的代币 1 数量
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
    /// @dev 只有 NFT 所有者或被授权者才能调用
    /// @param params 移除流动性参数
    /// @return amount0 移除的代币 0 数量
    /// @return amount1 移除的代币 1 数量
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
    /// @dev 只有 NFT 所有者或被授权者才能调用
    /// @param params 收取参数
    /// @return amount0 实际收取的代币 0 数量
    /// @return amount1 实际收取的代币 1 数量
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
    /// @dev 只能销毁已清空的仓位（流动性和待领取代币都为 0）
    /// @param tokenId NFT ID
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

    /// @notice 返回 NFT 的元数据 URI
    /// @dev 生成链上 SVG 图像和 JSON 元数据
    /// @param tokenId NFT ID
    /// @return 完整的 Data URI（Base64 编码的 JSON）
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

        // 步骤 3: 调用渲染器生成 Data URI
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

    // ============ 内部辅助函数 ============

    /// @notice 权限检查修饰器
    modifier isApprovedOrOwner(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        _;
    }

    /// @notice 检查地址是否有权限操作代币
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        return (
            spender == owner ||
            getApproved[tokenId] == spender ||
            isApprovedForAll[owner][spender]
        );
    }

    /// @notice 计算池子中仓位的 key
    function poolPositionKey(TokenPosition memory position)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(address(this), position.lowerTick, position.upperTick)
        );
    }

    /// @notice 获取池子地址
    function getPool(address tokenA, address tokenB, uint24 fee)
        internal
        view
        returns (IUniswapV3Pool pool)
    {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, fee)
        );
    }

    /// @notice 回调数据结构
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    /// @notice 内部添加流动性逻辑
    function _addLiquidity(AddLiquidityInternalParams memory params)
        internal
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        // 获取当前价格
        (uint160 sqrtPriceX96, , , , , ) = params.pool.slot0();

        // 将 tick 转换为 sqrtPrice
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(params.lowerTick);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(params.upperTick);

        // 计算流动性
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            params.amount0Desired,
            params.amount1Desired
        );

        // 调用池子的 mint 函数
        (amount0, amount1) = params.pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            liquidity,
            abi.encode(
                CallbackData({
                    token0: params.pool.token0(),
                    token1: params.pool.token1(),
                    payer: msg.sender
                })
            )
        );

        // 滑点检查
        if (amount0 < params.amount0Min || amount1 < params.amount1Min) {
            revert SlippageCheckFailed(amount0, amount1);
        }
    }

    /// @notice Uniswap V3 Mint 回调
    /// @dev 池子调用此函数来收取代币
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        CallbackData memory callbackData = abi.decode(
            data,
            (CallbackData)
        );

        // 从 payer 转账到池子
        if (amount0 > 0) {
            IERC20(callbackData.token0).transferFrom(
                callbackData.payer,
                msg.sender,
                amount0
            );
        }
        if (amount1 > 0) {
            IERC20(callbackData.token1).transferFrom(
                callbackData.payer,
                msg.sender,
                amount1
            );
        }
    }
}
