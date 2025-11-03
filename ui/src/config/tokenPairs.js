/**
 * 代币对配置文件
 *
 * 定义所有可用的流动性池和代币对关系
 * 用于自动路由查找
 */

import { CONTRACTS } from './contracts';

/**
 * 代币信息
 */
export const TOKENS = {
  WETH: {
    address: CONTRACTS.WETH,
    symbol: 'WETH',
    name: 'Wrapped Ether',
    decimals: 18,
  },
  USDC: {
    address: CONTRACTS.USDC,
    symbol: 'USDC',
    name: 'USD Coin',
    decimals: 18, // 注意：实际项目中 USDC 通常是 6 decimals，但这里为了简化使用 18
  },
};

/**
 * 代币对列表
 *
 * 每个代币对代表一个流动性池
 * tickSpacing 决定了池子的费率档位：
 * - 10: 0.05% (适合稳定币对)
 * - 60: 0.30% (标准费率)
 * - 200: 1.00% (高波动性代币对)
 */
export const TOKEN_PAIRS = [
  {
    token0: TOKENS.WETH,
    token1: TOKENS.USDC,
    tickSpacing: 60, // 0.30% 费率
    poolAddress: CONTRACTS.Pool,
  },
  // 未来可以添加更多代币对
  // 例如：
  // {
  //   token0: TOKENS.USDC,
  //   token1: TOKENS.USDT,
  //   tickSpacing: 10,
  //   poolAddress: '0x...',
  // },
  // {
  //   token0: TOKENS.WETH,
  //   token1: TOKENS.DAI,
  //   tickSpacing: 60,
  //   poolAddress: '0x...',
  // },
];

/**
 * 根据两个代币地址获取代币对信息
 * @param {String} token0Address - 代币0地址
 * @param {String} token1Address - 代币1地址
 * @returns {Object|null} 代币对信息，如果不存在返回 null
 */
export function getTokenPair(token0Address, token1Address) {
  const addr0 = token0Address.toLowerCase();
  const addr1 = token1Address.toLowerCase();

  return TOKEN_PAIRS.find(pair => {
    const pairAddr0 = pair.token0.address.toLowerCase();
    const pairAddr1 = pair.token1.address.toLowerCase();

    return (
      (pairAddr0 === addr0 && pairAddr1 === addr1) ||
      (pairAddr0 === addr1 && pairAddr1 === addr0)
    );
  });
}

/**
 * 根据符号获取代币信息
 * @param {String} symbol - 代币符号（如 'WETH', 'USDC'）
 * @returns {Object|null} 代币信息，如果不存在返回 null
 */
export function getTokenBySymbol(symbol) {
  return TOKENS[symbol.toUpperCase()] || null;
}

/**
 * 根据地址获取代币信息
 * @param {String} address - 代币地址
 * @returns {Object|null} 代币信息，如果不存在返回 null
 */
export function getTokenByAddress(address) {
  const addr = address.toLowerCase();
  return Object.values(TOKENS).find(
    token => token.address.toLowerCase() === addr
  ) || null;
}
