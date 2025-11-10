// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base64.sol";
import "./Strings.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/IERC20.sol";

/// @title NFT 渲染器
/// @notice 为 UniswapV3 仓位生成链上 SVG 和 JSON 元数据
/// @dev 将流动性仓位的信息渲染为 Base64 编码的 Data URI
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
}
