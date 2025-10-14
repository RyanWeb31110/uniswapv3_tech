/**
 * 添加流动性组件
 */

import { useState } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS, LIQUIDITY_PARAMS } from '../config/contracts';
import './AddLiquidity.css';

function AddLiquidity({ onSuccess }) {
  const { account, isConnected, isCorrectNetwork } = useMetaMask();
  const [txStatus, setTxStatus] = useState('idle'); // idle, approving, minting, success, error
  const [error, setError] = useState('');

  /**
   * 获取合约实例
   */
  const getContracts = () => {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();

    const token0 = new ethers.Contract(CONTRACTS.WETH, ABIS.ERC20, signer);
    const token1 = new ethers.Contract(CONTRACTS.USDC, ABIS.ERC20, signer);
    const manager = new ethers.Contract(CONTRACTS.Manager, ABIS.Manager, signer);

    return { token0, token1, manager, provider };
  };

  /**
   * 添加流动性
   */
  const handleAddLiquidity = async () => {
    if (!isConnected || !isCorrectNetwork) {
      alert('请先连接到正确的网络');
      return;
    }

    try {
      setError('');
      setTxStatus('approving');

      const { token0, token1, manager } = getContracts();

      // 准备参数
      const amount0 = ethers.utils.parseEther(LIQUIDITY_PARAMS.amount0);
      const amount1 = ethers.utils.parseEther(LIQUIDITY_PARAMS.amount1);
      const { lowerTick, upperTick, liquidity } = LIQUIDITY_PARAMS;
      
      // 编码回调数据
      const extra = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address'],
        [CONTRACTS.WETH, CONTRACTS.USDC, account]
      );

      console.log('添加流动性参数:');
      console.log('  Amount0:', ethers.utils.formatEther(amount0), 'WETH');
      console.log('  Amount1:', ethers.utils.formatEther(amount1), 'USDC');
      console.log('  Lower Tick:', lowerTick);
      console.log('  Upper Tick:', upperTick);
      console.log('  Liquidity:', liquidity);

      // 检查授权额度
      const [allowance0, allowance1] = await Promise.all([
        token0.allowance(account, CONTRACTS.Manager),
        token1.allowance(account, CONTRACTS.Manager),
      ]);

      console.log('当前授权额度:');
      console.log('  WETH:', ethers.utils.formatEther(allowance0));
      console.log('  USDC:', ethers.utils.formatEther(allowance1));

      // 如果需要，请求授权 token0
      if (allowance0.lt(amount0)) {
        console.log('请求 WETH 授权...');
        const approveTx0 = await token0.approve(CONTRACTS.Manager, amount0);
        console.log('WETH 授权交易已发送:', approveTx0.hash);
        await approveTx0.wait();
        console.log('WETH 授权完成');
      }

      // 如果需要，请求授权 token1
      if (allowance1.lt(amount1)) {
        console.log('请求 USDC 授权...');
        const approveTx1 = await token1.approve(CONTRACTS.Manager, amount1);
        console.log('USDC 授权交易已发送:', approveTx1.hash);
        await approveTx1.wait();
        console.log('USDC 授权完成');
      }

      // 调用 Manager 合约添加流动性
      setTxStatus('minting');
      console.log('正在添加流动性...');
      
      const mintTx = await manager.mint(
        CONTRACTS.Pool,
        lowerTick,
        upperTick,
        ethers.BigNumber.from(liquidity),
        extra
      );

      console.log('Mint 交易已发送:', mintTx.hash);
      const receipt = await mintTx.wait();
      console.log('流动性添加完成！');
      console.log('Gas 消耗:', receipt.gasUsed.toString());

      setTxStatus('success');
      
      if (onSuccess) {
        onSuccess(receipt);
      }

      setTimeout(() => setTxStatus('idle'), 3000);
    } catch (err) {
      console.error('添加流动性失败:', err);
      setTxStatus('error');
      
      let errorMessage = '添加流动性失败';
      if (err.code === 4001) {
        errorMessage = '您取消了交易';
      } else if (err.code === 'INSUFFICIENT_FUNDS') {
        errorMessage = '账户余额不足';
      } else if (err.message) {
        errorMessage = err.message;
      }
      
      setError(errorMessage);
    }
  };

  return (
    <div className="add-liquidity">
      <h2>添加流动性</h2>
      
      <div className="liquidity-params">
        <div className="param-row">
          <span className="label">WETH 数量:</span>
          <span className="value">{LIQUIDITY_PARAMS.amount0}</span>
        </div>
        <div className="param-row">
          <span className="label">USDC 数量:</span>
          <span className="value">{LIQUIDITY_PARAMS.amount1}</span>
        </div>
        <div className="param-row">
          <span className="label">价格范围:</span>
          <span className="value">
            Tick {LIQUIDITY_PARAMS.lowerTick} ~ {LIQUIDITY_PARAMS.upperTick}
          </span>
        </div>
        <div className="param-row">
          <span className="label">流动性:</span>
          <span className="value small">{LIQUIDITY_PARAMS.liquidity}</span>
        </div>
      </div>

      {txStatus === 'idle' && (
        <button 
          onClick={handleAddLiquidity}
          disabled={!isConnected || !isCorrectNetwork}
          className="btn btn-primary"
        >
          添加流动性
        </button>
      )}

      {txStatus === 'approving' && (
        <div className="status-message">
          <div className="spinner"></div>
          <p>正在请求代币授权...</p>
          <p className="small">请在 MetaMask 中确认交易</p>
        </div>
      )}

      {txStatus === 'minting' && (
        <div className="status-message">
          <div className="spinner"></div>
          <p>正在添加流动性...</p>
          <p className="small">等待交易确认</p>
        </div>
      )}

      {txStatus === 'success' && (
        <div className="status-message success">
          <p>✅ 流动性添加成功！</p>
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

export default AddLiquidity;

