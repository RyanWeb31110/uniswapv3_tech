/**
 * 价格转换工具函数
 *
 * 提供价格、sqrtPriceX96 和 Tick 之间的转换功能
 */

import { encodeSqrtRatioX96, TickMath } from '@uniswap/v3-sdk';
import JSBI from 'jsbi';

/**
 * 将价格转换为 sqrtPriceX96
 * @param {number} price - 价格（例如：5000 表示 1 ETH = 5000 USDC）
 * @returns {JSBI} sqrtPriceX96 格式的价格
 */
export const priceToSqrtP = (price) => {
  // encodeSqrtRatioX96 接受两个数量，计算它们的比率
  // 传入 price 和 1，得到 price:1 的比率
  const amount0 = JSBI.BigInt(Math.floor(price * 1e6)); // 乘以 1e6 以保持精度
  const amount1 = JSBI.BigInt(1e6);
  return encodeSqrtRatioX96(amount0, amount1);
};

/**
 * 将价格转换为 Tick 索引
 * @param {number} price - 价格
 * @returns {number} Tick 索引
 */
export const priceToTick = (price) => {
  try {
    const sqrtP = priceToSqrtP(price);
    return TickMath.getTickAtSqrtRatio(sqrtP);
  } catch (error) {
    console.error('价格转换为 Tick 失败:', error);
    throw new Error(`无法将价格 ${price} 转换为 Tick: ${error.message}`);
  }
};

/**
 * 根据滑点容忍度计算最小金额
 * @param {import('ethers').BigNumber} desiredAmount - 期望的代币数量
 * @param {number} slippagePercent - 滑点容忍度（百分比）
 * @returns {import('ethers').BigNumber} 最小可接受的代币数量
 */
export const calculateMinAmount = (desiredAmount, slippagePercent) => {
  // 将百分比转换为基点（basis points）
  // 0.5% = 0.5 * 100 = 50 基点
  const slippageBps = Math.floor(slippagePercent * 100);

  // 计算最小金额
  // minAmount = desiredAmount * (10000 - slippageBps) / 10000
  return desiredAmount.mul(10000 - slippageBps).div(10000);
};

/**
 * 计算滑点保护的限价
 * @param {import('ethers').BigNumber} sqrtPriceX96After - Quoter 返回的交换后价格
 * @param {number} slippagePercent - 滑点容忍度（百分比）
 * @param {boolean} zeroForOne - 交换方向
 * @returns {import('ethers').BigNumber} 限价（sqrtPriceLimitX96 格式）
 */
export const calculateLimitPrice = (sqrtPriceX96After, slippagePercent, zeroForOne) => {
  // 将滑点转换为基点
  const slippageBps = Math.floor(slippagePercent * 100);

  // 根据交换方向计算限价
  if (zeroForOne) {
    // 卖出 token0 买入 token1
    // 价格下降对用户不利，所以限价是"不低于"
    // limitPrice = priceAfter * (1 - slippage%)
    return sqrtPriceX96After.mul(10000 - slippageBps).div(10000);
  } else {
    // 卖出 token1 买入 token0
    // 价格上升对用户不利，所以限价是"不高于"
    // limitPrice = priceAfter * (1 + slippage%)
    return sqrtPriceX96After.mul(10000 + slippageBps).div(10000);
  }
};

/**
 * 验证价格区间是否有效
 * @param {number} lowerPrice - 价格下限
 * @param {number} upperPrice - 价格上限
 * @returns {boolean} 是否有效
 */
export const validatePriceRange = (lowerPrice, upperPrice) => {
  if (!lowerPrice || !upperPrice) {
    return false;
  }

  const lower = parseFloat(lowerPrice);
  const upper = parseFloat(upperPrice);

  if (isNaN(lower) || isNaN(upper)) {
    return false;
  }

  if (lower <= 0 || upper <= 0) {
    return false;
  }

  if (lower >= upper) {
    return false;
  }

  return true;
};

/**
 * 验证滑点容忍度是否有效
 * @param {number} slippage - 滑点容忍度（百分比）
 * @returns {boolean} 是否有效
 */
export const validateSlippage = (slippage) => {
  const value = parseFloat(slippage);

  if (isNaN(value)) {
    return false;
  }

  // 滑点应在 0.1% - 50% 之间
  if (value < 0.1 || value > 50) {
    return false;
  }

  return true;
};

/**
 * 格式化价格显示
 * @param {number} price - 价格
 * @param {number} decimals - 小数位数
 * @returns {string} 格式化后的价格字符串
 */
export const formatPrice = (price, decimals = 2) => {
  if (!price || isNaN(price)) {
    return '0.00';
  }

  return parseFloat(price).toFixed(decimals);
};
