/**
 * 增强版代币交换组件
 * 实现双向交换、实时报价、方向切换等功能
 */

import React, { useState, useCallback, useEffect } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS } from '../config/contracts';
import './EnhancedSwap.css';

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

function EnhancedSwap({ onSuccess }) {
  const { account, isConnected, isCorrectNetwork } = useMetaMask();

  // 代币对配置
  const TOKEN_PAIR = [
    { symbol: 'WETH', address: CONTRACTS.WETH, decimals: 18 },
    { symbol: 'USDC', address: CONTRACTS.USDC, decimals: 18 }
  ];

  // 状态管理
  const [zeroForOne, setZeroForOne] = useState(true); // true: WETH -> USDC, false: USDC -> WETH
  const [amount0, setAmount0] = useState("0"); // WETH 金额
  const [amount1, setAmount1] = useState("0"); // USDC 金额
  const [loading, setLoading] = useState(false);
  const [enabled, setEnabled] = useState(false);
  const [error, setError] = useState('');
  const [blockNumber, setBlockNumber] = useState(0);

  /**
   * 获取合约实例
   */
  const getContracts = useCallback(() => {
    // 创建 provider，禁用缓存确保获取最新状态
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    
    // 启用轮询以获取最新区块信息
    provider.polling = true;
    provider.pollingInterval = 1000; // 1秒轮询一次
    
    const signer = provider.getSigner();

    const weth = new ethers.Contract(CONTRACTS.WETH, ABIS.ERC20, signer);
    const usdc = new ethers.Contract(CONTRACTS.USDC, ABIS.ERC20, signer);
    const manager = new ethers.Contract(CONTRACTS.Manager, ABIS.Manager, signer);
    const quoter = new ethers.Contract(CONTRACTS.Quoter, ABIS.Quoter, provider);

    return { weth, usdc, manager, quoter, provider };
  }, []);

  // 更新启用状态
  useEffect(() => {
    setEnabled(isConnected && isCorrectNetwork && CONTRACTS.Quoter !== '0x0000000000000000000000000000000000000000');
  }, [isConnected, isCorrectNetwork]);

  // 区块同步检查
  useEffect(() => {
    if (!enabled) return;

    const checkBlockSync = async () => {
      try {
        const { provider } = getContracts();
        const currentBlock = await provider.getBlockNumber();
        setBlockNumber(currentBlock);
        console.log('当前区块高度:', currentBlock);
      } catch (error) {
        console.error('获取区块高度失败:', error);
      }
    };

    // 立即检查一次
    checkBlockSync();

    // 每5秒检查一次区块同步状态
    const interval = setInterval(checkBlockSync, 5000);

    return () => clearInterval(interval);
  }, [enabled, getContracts]);

  /**
   * 更新输出金额的核心逻辑
   */
  const updateAmountOutCore = useCallback(async (amount, retryCount = 0) => {
    if (amount === 0 || amount === "0" || !enabled) {
      return;
    }

    setLoading(true);
    setError('');

    try {
      const { quoter } = getContracts();
      
      const result = await quoter.callStatic.quote({
        pool: CONTRACTS.Pool,
        amountIn: ethers.utils.parseEther(amount),
        zeroForOne: zeroForOne
      });

      const { amountOut } = result;
      if (zeroForOne) {
        setAmount1(ethers.utils.formatEther(amountOut));
      } else {
        setAmount0(ethers.utils.formatEther(amountOut));
      }
    } catch (error) {
      console.error("报价获取失败:", error);
      
      // 如果是区块同步错误，尝试重试
      if (error.message.includes('BlockOutOfRangeError') && retryCount < 3) {
        console.log(`区块同步错误，${1000 * (retryCount + 1)}ms 后重试...`);
        setTimeout(() => {
          updateAmountOutCore(amount, retryCount + 1);
        }, 1000 * (retryCount + 1));
        return;
      }
      
      if (zeroForOne) {
        setAmount1("0");
      } else {
        setAmount0("0");
      }
      setError("获取报价失败，请检查输入金额或刷新页面");
    } finally {
      setLoading(false);
    }
  }, [zeroForOne, enabled, getContracts]);

  /**
   * 更新输出金额（带防抖优化）
   */
  const updateAmountOut = useCallback(
    debounce(updateAmountOutCore, 300),
    [updateAmountOutCore]
  );

  /**
   * 创建金额设置函数
   */
  const setAmount_ = useCallback((setAmountFn) => {
    return (amount) => {
      amount = amount || 0;
      setAmountFn(amount);
      updateAmountOut(amount);
    };
  }, [updateAmountOut]);

  /**
   * 处理方向切换
   */
  const handleDirectionChange = useCallback(() => {
    setZeroForOne(!zeroForOne);
    
    // 交换金额
    const tempAmount0 = amount0;
    const tempAmount1 = amount1;
    setAmount0(tempAmount1);
    setAmount1(tempAmount0);
    
    // 重新计算报价
    const currentInputAmount = !zeroForOne ? amount0 : amount1;
    if (currentInputAmount && currentInputAmount !== "0") {
      updateAmountOut(currentInputAmount);
    }
  }, [zeroForOne, amount0, amount1, updateAmountOut]);

  /**
   * 执行交换
   */
  const handleSwap = async () => {
    if (!enabled) {
      alert('请先连接到正确的网络并确保 Quoter 合约已部署');
      return;
    }

    const inputAmount = zeroForOne ? amount0 : amount1;
    if (!inputAmount || parseFloat(inputAmount) <= 0) {
      alert('请输入有效的交换金额');
      return;
    }

    try {
      setError('');
      setLoading(true);

      const { weth, usdc, manager } = getContracts();
      const tokenInContract = zeroForOne ? weth : usdc;
      const tokenInSymbol = zeroForOne ? 'WETH' : 'USDC';

      // 转换数量为 Wei
      const amountInWei = ethers.utils.parseEther(inputAmount);

      console.log('交换参数:');
      console.log('  方向:', zeroForOne ? 'WETH -> USDC' : 'USDC -> WETH');
      console.log('  输入金额:', inputAmount, tokenInSymbol);
      console.log('  输入金额 Wei:', amountInWei.toString());

      // 检查余额
      const balance = await tokenInContract.balanceOf(account);
      console.log('  当前余额:', ethers.utils.formatEther(balance));

      if (balance.lt(amountInWei)) {
        throw new Error(`余额不足。当前余额: ${ethers.utils.formatEther(balance)} ${tokenInSymbol}`);
      }

      // 检查授权额度
      const allowance = await tokenInContract.allowance(account, CONTRACTS.Manager);
      console.log('  当前授权额度:', ethers.utils.formatEther(allowance));

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

      // 解析事件
      if (receipt.events) {
        const swapEvent = receipt.events.find(e => e.event === 'Swap');
        if (swapEvent) {
          console.log('交换详情:');
          console.log('  Amount0:', swapEvent.args.amount0.toString());
          console.log('  Amount1:', swapEvent.args.amount1.toString());
          console.log('  SqrtPriceX96:', swapEvent.args.sqrtPriceX96.toString());
        }
      }

      if (onSuccess) {
        onSuccess(receipt);
      }

      // 重置状态
      setAmount0("0");
      setAmount1("0");
      setLoading(false);

    } catch (err) {
      console.error('交换失败:', err);
      setLoading(false);
      
      let errorMessage = '交换失败';
      if (err.code === 4001) {
        errorMessage = '您取消了交易';
      } else if (err.message.includes('insufficient')) {
        errorMessage = '余额不足或流动性不足';
      } else if (err.message) {
        errorMessage = err.message;
      }
      
      setError(errorMessage);
    }
  };

  /**
   * 输入验证
   */
  // const validateAmount = (amount) => {
  //   if (!amount || amount === "") {
  //     return { valid: false, message: "请输入交换金额" };
  //   }
  //   
  //   const numAmount = parseFloat(amount);
  //   if (isNaN(numAmount)) {
  //     return { valid: false, message: "请输入有效的数字" };
  //   }
  //   
  //   if (numAmount <= 0) {
  //     return { valid: false, message: "交换金额必须大于 0" };
  //   }
  //   
  //   return { valid: true, message: "" };
  // };

  return (
    <div className="enhanced-swap">
      <h2>增强版代币交换</h2>
      
      <div className="swap-form">
        {/* 输入代币 */}
        <div className="swap-input">
          <label>输入代币:</label>
          <div className="input-group">
            <input
              type="number"
              value={zeroForOne ? amount0 : amount1}
              onChange={(e) => setAmount_(zeroForOne ? setAmount0 : setAmount1)(e.target.value)}
              step="0.01"
              min="0"
              disabled={!enabled || loading}
              placeholder="0.0"
            />
            <span className="token-symbol">
              {zeroForOne ? TOKEN_PAIR[0].symbol : TOKEN_PAIR[1].symbol}
            </span>
          </div>
        </div>

        {/* 方向切换按钮 */}
        <div className="swap-direction">
          <button 
            className="change-direction"
            onClick={handleDirectionChange}
            disabled={!enabled || loading}
            title="切换交换方向"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path 
                d="M7 17L17 7M17 7H7M17 7V17" 
                stroke="currentColor" 
                strokeWidth="2" 
                strokeLinecap="round" 
                strokeLinejoin="round"
              />
            </svg>
          </button>
        </div>

        {/* 输出代币 */}
        <div className="swap-input">
          <label>输出代币:</label>
          <div className="input-group">
            <input
              type="text"
              value={zeroForOne ? amount1 : amount0}
              disabled
              className="disabled-input"
              placeholder="0.0"
            />
            <span className="token-symbol">
              {zeroForOne ? TOKEN_PAIR[1].symbol : TOKEN_PAIR[0].symbol}
            </span>
          </div>
        </div>
      </div>

      {/* 状态信息 */}
      <div className="swap-info">
        <p className="small">
          当前交换方向: {zeroForOne ? 'WETH → USDC' : 'USDC → WETH'}
        </p>
        <p className="small">
          区块高度: {blockNumber} | 网络: Anvil Local
        </p>
        {loading && (
          <p className="loading-text">
            ⏳ 正在计算报价...
          </p>
        )}
        {error && (
          <p className="error-text">
            ❌ {error}
          </p>
        )}
      </div>

      {/* 交换按钮 */}
      <button 
        className="swap-button"
        onClick={handleSwap}
        disabled={!enabled || loading}
      >
        {loading ? "处理中..." : "交换"}
      </button>

      {/* 连接状态提示 */}
      {!isConnected && (
        <p className="warning-text">
          ⚠️ 请先连接钱包
        </p>
      )}
      {isConnected && !isCorrectNetwork && (
        <p className="warning-text">
          ⚠️ 请切换到正确的网络
        </p>
      )}
      {isConnected && isCorrectNetwork && !enabled && (
        <p className="warning-text">
          ⚠️ Quoter 合约未部署，请先部署合约
        </p>
      )}
    </div>
  );
}

export default EnhancedSwap;
