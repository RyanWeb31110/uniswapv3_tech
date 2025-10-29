/**
 * 带滑点保护的交换组件
 *
 * 功能：
 * - 用户可调节的滑点容忍度设置
 * - 根据滑点计算限价
 * - 防止交易在不利价格下执行
 * - 使用 Quoter 合约估算输出金额
 */

import { useState, useCallback, useEffect } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS } from '../config/contracts';
import { calculateLimitPrice, formatPrice } from '../utils/priceUtils';
import './SwapWithSlippage.css';

// 防抖函数
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

function SwapWithSlippage({ onSuccess }) {
  const { account, isConnected, isCorrectNetwork } = useMetaMask();

  // 状态管理
  const [amountIn, setAmountIn] = useState('');
  const [amountOut, setAmountOut] = useState('');
  const [slippage, setSlippage] = useState(0.5); // 默认 0.5%
  const [limitPrice, setLimitPrice] = useState(null);
  const [quoteData, setQuoteData] = useState(null);
  const [zeroForOne, setZeroForOne] = useState(true); // true: WETH -> USDC
  const [loading, setLoading] = useState(false);
  const [quoting, setQuoting] = useState(false);
  const [error, setError] = useState('');

  /**
   * 获取合约实例
   */
  const getContracts = useCallback(() => {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    provider.polling = true;
    provider.pollingInterval = 1000;
    const signer = provider.getSigner();

    const weth = new ethers.Contract(CONTRACTS.WETH, ABIS.ERC20, signer);
    const usdc = new ethers.Contract(CONTRACTS.USDC, ABIS.ERC20, signer);
    const manager = new ethers.Contract(CONTRACTS.Manager, ABIS.Manager, signer);
    const quoter = new ethers.Contract(CONTRACTS.Quoter, ABIS.Quoter, provider);

    return { weth, usdc, manager, quoter };
  }, []);

  /**
   * 当输入金额变化时，自动调用 Quoter 估算输出
   */
  const fetchQuoteCore = useCallback(async (amount, retryCount = 0) => {
    if (!amount || parseFloat(amount) <= 0) {
      setAmountOut('');
      setLimitPrice(null);
      setQuoteData(null);
      return;
    }

    setQuoting(true);
    setError('');

    try {
      const { quoter } = getContracts();

      // 调用 Quoter 估算
      const result = await quoter.callStatic.quote({
        pool: CONTRACTS.Pool,
        amountIn: ethers.utils.parseEther(amount),
        zeroForOne: zeroForOne
      });

      // 保存完整的报价数据
      setQuoteData(result);

      // 格式化输出金额
      const amountOutFormatted = ethers.utils.formatEther(result.amountOut);
      setAmountOut(amountOutFormatted);

      // 计算限价
      const limit = calculateLimitPrice(
        result.sqrtPriceX96After,
        slippage,
        zeroForOne
      );
      setLimitPrice(limit);

      console.log('报价结果:');
      console.log('  输入金额:', amount);
      console.log('  预估输出:', amountOutFormatted);
      console.log('  交换后价格:', result.sqrtPriceX96After.toString());
      console.log('  限价:', limit.toString());

    } catch (error) {
      console.error('报价失败:', error);

      // 如果是区块同步错误，尝试重试
      if (error.message.includes('BlockOutOfRangeError') && retryCount < 3) {
        console.log(`区块同步错误，${1000 * (retryCount + 1)}ms 后重试...`);
        setTimeout(() => {
          fetchQuoteCore(amount, retryCount + 1);
        }, 1000 * (retryCount + 1));
        return;
      }

      setAmountOut('');
      setError('获取报价失败，请检查输入或稍后重试');
    } finally {
      setQuoting(false);
    }
  }, [zeroForOne, slippage, getContracts]);

  /**
   * 带防抖的报价函数
   */
  const fetchQuote = useCallback(
    debounce(fetchQuoteCore, 500),
    [fetchQuoteCore]
  );

  /**
   * 监听输入金额和滑点变化
   */
  useEffect(() => {
    if (amountIn && parseFloat(amountIn) > 0) {
      fetchQuote(amountIn);
    }
  }, [amountIn, slippage, zeroForOne, fetchQuote]);

  /**
   * 切换交换方向
   */
  const handleToggleDirection = () => {
    setZeroForOne(!zeroForOne);
    setAmountIn('');
    setAmountOut('');
    setLimitPrice(null);
    setQuoteData(null);
  };

  /**
   * 执行交换
   */
  const handleSwap = async () => {
    if (!quoteData || !limitPrice) {
      alert('请先输入金额获取报价');
      return;
    }

    if (!isConnected || !isCorrectNetwork) {
      alert('请先连接到正确的网络');
      return;
    }

    try {
      setError('');
      setLoading(true);

      console.log('执行交换...');
      console.log('输入金额:', amountIn, zeroForOne ? 'WETH' : 'USDC');
      console.log('预估输出:', amountOut, zeroForOne ? 'USDC' : 'WETH');
      console.log('滑点容忍度:', slippage, '%');
      console.log('限价:', limitPrice.toString());

      const { weth, usdc, manager } = getContracts();
      const tokenInContract = zeroForOne ? weth : usdc;
      const tokenInSymbol = zeroForOne ? 'WETH' : 'USDC';

      // 转换数量为 Wei
      const amountInWei = ethers.utils.parseEther(amountIn);

      // 检查余额
      const balance = await tokenInContract.balanceOf(account);
      console.log('当前余额:', ethers.utils.formatEther(balance), tokenInSymbol);

      if (balance.lt(amountInWei)) {
        throw new Error(`余额不足。当前余额: ${ethers.utils.formatEther(balance)} ${tokenInSymbol}`);
      }

      // 检查授权额度
      const allowance = await tokenInContract.allowance(account, CONTRACTS.Manager);
      console.log('当前授权额度:', ethers.utils.formatEther(allowance), tokenInSymbol);

      // 如果需要，请求授权
      if (allowance.lt(amountInWei)) {
        console.log(`请求 ${tokenInSymbol} 授权...`);
        const approveTx = await tokenInContract.approve(CONTRACTS.Manager, amountInWei);
        console.log('授权交易已发送:', approveTx.hash);
        await approveTx.wait();
        console.log('授权完成');
      }

      // 编码回调数据
      const extra = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address'],
        [CONTRACTS.WETH, CONTRACTS.USDC, account]
      );

      // 执行交换
      console.log('正在执行交换...');
      const swapTx = await manager.swap(CONTRACTS.Pool, extra);
      console.log('Swap 交易已发送:', swapTx.hash);

      const receipt = await swapTx.wait();
      console.log('交换成功！');
      console.log('Gas 消耗:', receipt.gasUsed.toString());

      if (onSuccess) {
        onSuccess(receipt);
      }

      // 重置状态
      setAmountIn('');
      setAmountOut('');
      setLimitPrice(null);
      setQuoteData(null);

    } catch (err) {
      console.error('交换失败:', err);

      let errorMessage = '交换失败';
      if (err.code === 4001) {
        errorMessage = '您取消了交易';
      } else if (err.message.includes('insufficient')) {
        errorMessage = '余额不足或流动性不足';
      } else if (err.message) {
        errorMessage = err.message;
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="swap-with-slippage">
      <h2>交换代币（带滑点保护）</h2>

      <div className="swap-container">
        {/* 输入金额 */}
        <div className="input-group">
          <label>卖出</label>
          <div className="amount-input">
            <input
              type="number"
              value={amountIn}
              onChange={(e) => setAmountIn(e.target.value)}
              placeholder="0.0"
              disabled={loading || quoting}
              step="0.01"
              min="0"
            />
            <span className="token-symbol">
              {zeroForOne ? 'WETH' : 'USDC'}
            </span>
          </div>
        </div>

        {/* 方向切换按钮 */}
        <div className="swap-direction">
          <button
            className="toggle-btn"
            onClick={handleToggleDirection}
            disabled={loading || quoting}
            title="切换交换方向"
          >
            ⇅
          </button>
        </div>

        {/* 输出金额（由 Quoter 计算） */}
        <div className="input-group">
          <label>买入（预估）</label>
          <div className="amount-input">
            <input
              type="text"
              value={amountOut}
              readOnly
              placeholder="0.0"
              className="output-amount"
            />
            <span className="token-symbol">
              {zeroForOne ? 'USDC' : 'WETH'}
            </span>
          </div>
        </div>

        {/* 滑点设置 */}
        <div className="settings-group">
          <label>滑点容忍度</label>
          <div className="slippage-buttons">
            <button
              className={slippage === 0.1 ? 'active' : ''}
              onClick={() => setSlippage(0.1)}
              disabled={loading || quoting}
            >
              0.1%
            </button>
            <button
              className={slippage === 0.5 ? 'active' : ''}
              onClick={() => setSlippage(0.5)}
              disabled={loading || quoting}
            >
              0.5%
            </button>
            <button
              className={slippage === 1.0 ? 'active' : ''}
              onClick={() => setSlippage(1.0)}
              disabled={loading || quoting}
            >
              1.0%
            </button>
            <input
              type="number"
              value={slippage}
              onChange={(e) => setSlippage(parseFloat(e.target.value) || 0.5)}
              placeholder="自定义"
              step="0.1"
              min="0.1"
              max="50"
              disabled={loading || quoting}
              className="custom-slippage"
            />
          </div>
        </div>

        {/* 价格信息 */}
        {quoteData && amountOut && (
          <div className="price-info">
            <div className="info-row">
              <span>预估输出:</span>
              <span>{formatPrice(amountOut, 4)} {zeroForOne ? 'USDC' : 'WETH'}</span>
            </div>
            <div className="info-row">
              <span>滑点保护:</span>
              <span>
                最低接受 {formatPrice(parseFloat(amountOut) * (1 - slippage / 100), 4)}{' '}
                {zeroForOne ? 'USDC' : 'WETH'}
              </span>
            </div>
            <div className="info-row small">
              <span>价格影响:</span>
              <span>~{slippage}%</span>
            </div>
          </div>
        )}

        {/* 状态提示 */}
        {quoting && (
          <div className="status-message">
            <p>⏳ 正在获取报价...</p>
          </div>
        )}

        {error && (
          <div className="error-message">
            <p>❌ {error}</p>
          </div>
        )}

        {/* 交换按钮 */}
        <button
          className="swap-button"
          onClick={handleSwap}
          disabled={loading || quoting || !isConnected || !isCorrectNetwork || !quoteData}
        >
          {loading ? '交换中...' : '交换'}
        </button>

        {/* 连接状态提示 */}
        {(!isConnected || !isCorrectNetwork) && (
          <p className="warning-text">
            ⚠️ 请先连接到正确的网络
          </p>
        )}
      </div>
    </div>
  );
}

export default SwapWithSlippage;
