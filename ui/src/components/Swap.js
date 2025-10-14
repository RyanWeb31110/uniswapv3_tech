/**
 * 代币交换组件
 */

import { useState } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS } from '../config/contracts';
import './Swap.css';

function Swap({ onSuccess }) {
  const { account, isConnected, isCorrectNetwork } = useMetaMask();

  const TOKEN_IN = 'USDC';
  const TOKEN_OUT = 'WETH';
  const MIN_USDC_INPUT = '42';
  const EXPECTED_WETH_OUTPUT = '0.008396714242162444';

  const [amountIn, setAmountIn] = useState(MIN_USDC_INPUT);
  const [txStatus, setTxStatus] = useState('idle'); // idle, approving, swapping, success, error
  const [error, setError] = useState('');

  /**
   * 获取合约实例
   */
  const getContracts = () => {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();

    const weth = new ethers.Contract(CONTRACTS.WETH, ABIS.ERC20, signer);
    const usdc = new ethers.Contract(CONTRACTS.USDC, ABIS.ERC20, signer);
    const manager = new ethers.Contract(CONTRACTS.Manager, ABIS.Manager, signer);

    return { weth, usdc, manager, provider };
  };

  /**
   * 执行交换
   */
  const handleSwap = async () => {
    if (!isConnected || !isCorrectNetwork) {
      alert('请先连接到正确的网络');
      return;
    }

    if (!amountIn || parseFloat(amountIn) <= 0) {
      alert('请输入有效的数量');
      return;
    }

    try {
      setError('');
      setTxStatus('approving');

      const { usdc, manager } = getContracts();
      const tokenInContract = usdc;

      // 转换数量为 Wei
      const amountInWei = ethers.utils.parseEther(amountIn);

      const minAmountInWei = ethers.utils.parseEther(MIN_USDC_INPUT);

      if (amountInWei.lt(minAmountInWei)) {
        throw new Error(`当前演示池需要至少 ${MIN_USDC_INPUT} ${TOKEN_IN} 作为输入`);
      }

      // 编码回调数据
      const extra = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address'],
        [CONTRACTS.WETH, CONTRACTS.USDC, account]
      );

      console.log('交换参数:');
      console.log('  Token In:', TOKEN_IN);
      console.log('  Amount In:', amountIn);
      console.log('  Amount In Wei:', amountInWei.toString());

      // 检查余额
      const balance = await tokenInContract.balanceOf(account);
      console.log('  当前余额:', ethers.utils.formatEther(balance));

      if (balance.lt(amountInWei)) {
        throw new Error(`余额不足。当前余额: ${ethers.utils.formatEther(balance)} ${TOKEN_IN}`);
      }

      // 检查授权额度
      const allowance = await tokenInContract.allowance(account, CONTRACTS.Manager);
      console.log('  当前授权额度:', ethers.utils.formatEther(allowance));

      // 如果需要，请求授权
      if (allowance.lt(amountInWei)) {
        console.log(`请求 ${TOKEN_IN} 授权...`);
        const approveTx = await tokenInContract.approve(CONTRACTS.Manager, amountInWei);
        console.log('授权交易已发送:', approveTx.hash);
        await approveTx.wait();
        console.log('授权完成');
      }

      // 执行交换
      setTxStatus('swapping');
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

      setTxStatus('success');
      
      if (onSuccess) {
        onSuccess(receipt);
      }

      setTimeout(() => {
        setTxStatus('idle');
        setAmountIn('0.01');
      }, 3000);
    } catch (err) {
      console.error('交换失败:', err);
      setTxStatus('error');
      
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

  return (
    <div className="swap">
      <h2>代币交换</h2>
      
      <div className="swap-form">
        <div className="form-group">
          <label>输入代币:</label>
          <input
            type="text"
            value={`${TOKEN_IN}（固定）`}
            disabled
            className="disabled-input"
          />
        </div>

        <div className="form-group">
          <label>数量:</label>
          <input
            type="number"
            value={amountIn}
            onChange={(e) => setAmountIn(e.target.value)}
            step="0.01"
            min="0"
            disabled={txStatus !== 'idle'}
            placeholder={MIN_USDC_INPUT}
          />
        </div>

        <div className="swap-arrow">↓</div>

        <div className="form-group">
          <label>输出代币:</label>
          <input 
            type="text" 
            value={`${TOKEN_OUT}（约 ${EXPECTED_WETH_OUTPUT}）`}
            disabled
            className="disabled-input"
          />
        </div>
      </div>

      <div className="form-group">
        <p className="small">
          当前演示版本仅支持 {TOKEN_IN} → {TOKEN_OUT} 交换，最小输入 {MIN_USDC_INPUT} {TOKEN_IN}，
          预计获得约 {EXPECTED_WETH_OUTPUT} {TOKEN_OUT}。
        </p>
      </div>

      {txStatus === 'idle' && (
        <button 
          onClick={handleSwap}
          disabled={!isConnected || !isCorrectNetwork}
          className="btn btn-primary"
        >
          交换
        </button>
      )}

      {txStatus === 'approving' && (
        <div className="status-message">
          <div className="spinner"></div>
          <p>正在请求代币授权...</p>
          <p className="small">请在 MetaMask 中确认交易</p>
        </div>
      )}

      {txStatus === 'swapping' && (
        <div className="status-message">
          <div className="spinner"></div>
          <p>正在执行交换...</p>
          <p className="small">等待交易确认</p>
        </div>
      )}

      {txStatus === 'success' && (
        <div className="status-message success">
          <p>✅ 交换成功！</p>
        </div>
      )}

      {txStatus === 'error' && (
        <div className="status-message error">
          <p>❌ {error}</p>
          <button onClick={() => setTxStatus('idle')} className="btn btn-secondary btn-sm">
            重试
          </button>
        </div>
      )}

      {(!isConnected || !isCorrectNetwork) && (
        <p className="warning-text">
          ⚠️ 请先连接到正确的网络
        </p>
      )}
    </div>
  );
}

export default Swap;
