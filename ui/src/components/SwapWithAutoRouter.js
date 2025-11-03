/**
 * 带自动路由的代币交换组件
 *
 * 支持：
 * - 任意代币对之间的交换
 * - 自动查找最短交换路径
 * - 显示路径预览
 */

import { useState, useEffect, useMemo } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS } from '../config/contracts';
import { TOKEN_PAIRS, TOKENS, getTokenByAddress } from '../config/tokenPairs';
import PathFinder from '../utils/PathFinder';
import './Swap.css';

function SwapWithAutoRouter({ onSuccess }) {
  const { account, isConnected, isCorrectNetwork } = useMetaMask();

  // 初始化 PathFinder
  const pathFinder = useMemo(() => {
    return new PathFinder(TOKEN_PAIRS);
  }, []);

  // 状态管理
  const [inputToken, setInputToken] = useState(TOKENS.USDC);
  const [outputToken, setOutputToken] = useState(TOKENS.WETH);
  const [amountIn, setAmountIn] = useState('42');
  const [swapPath, setSwapPath] = useState([]);
  const [pathInfo, setPathInfo] = useState(null);
  const [txStatus, setTxStatus] = useState('idle'); // idle, approving, swapping, success, error
  const [error, setError] = useState('');

  /**
   * 当代币选择改变时，自动查找路径
   */
  useEffect(() => {
    if (!inputToken || !outputToken) {
      setSwapPath([]);
      setPathInfo(null);
      return;
    }

    // 相同代币不能交换
    if (inputToken.address.toLowerCase() === outputToken.address.toLowerCase()) {
      setSwapPath([]);
      setPathInfo(null);
      return;
    }

    // 查找路径
    const path = pathFinder.findPath(inputToken.address, outputToken.address);

    if (path && path.length > 0) {
      setSwapPath(path);

      // 解析路径信息
      const hops = (path.length - 1) / 2;
      const intermediateTokens = [];

      // 提取中间代币
      for (let i = 1; i < path.length - 1; i += 2) {
        const tokenAddr = path[i + 1];
        const token = getTokenByAddress(tokenAddr);
        if (token) {
          intermediateTokens.push(token.symbol);
        }
      }

      setPathInfo({
        hops,
        intermediateTokens,
        found: true,
      });
    } else {
      setSwapPath([]);
      setPathInfo({
        found: false,
        message: '未找到可用的交换路径',
      });
    }
  }, [inputToken, outputToken, pathFinder]);

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

    if (!swapPath || swapPath.length === 0) {
      alert('未找到可用的交换路径');
      return;
    }

    if (!amountIn || parseFloat(amountIn) <= 0) {
      alert('请输入有效的数量');
      return;
    }

    try {
      setError('');
      setTxStatus('approving');

      const { manager } = getContracts();

      // 转换数量为 Wei
      const amountInWei = ethers.utils.parseEther(amountIn);

      // 获取输入代币合约
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();
      const tokenInContract = new ethers.Contract(
        inputToken.address,
        ABIS.ERC20,
        signer
      );

      console.log('交换参数:');
      console.log('  Input Token:', inputToken.symbol);
      console.log('  Output Token:', outputToken.symbol);
      console.log('  Amount In:', amountIn);
      console.log('  Swap Path:', swapPath);
      console.log('  Path Info:', pathInfo);

      // 检查余额
      const balance = await tokenInContract.balanceOf(account);
      console.log('  当前余额:', ethers.utils.formatEther(balance));

      if (balance.lt(amountInWei)) {
        throw new Error(
          `余额不足。当前余额: ${ethers.utils.formatEther(balance)} ${inputToken.symbol}`
        );
      }

      // 检查授权额度
      const allowance = await tokenInContract.allowance(account, CONTRACTS.Manager);
      console.log('  当前授权额度:', ethers.utils.formatEther(allowance));

      // 如果需要，请求授权
      if (allowance.lt(amountInWei)) {
        console.log(`请求 ${inputToken.symbol} 授权...`);
        const approveTx = await tokenInContract.approve(
          CONTRACTS.Manager,
          amountInWei
        );
        console.log('授权交易已发送:', approveTx.hash);
        await approveTx.wait();
        console.log('授权完成');
      }

      // 执行交换
      setTxStatus('swapping');
      console.log('正在执行交换...');

      // 编码回调数据
      // 注意：这里使用简化版本，实际项目中可能需要根据路径编码更复杂的数据
      const extra = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address'],
        [inputToken.address, outputToken.address, account]
      );

      // 当前版本使用 Manager.swap，未来可以升级到 SwapRouter
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

  /**
   * 切换输入输出代币
   */
  const handleSwitchTokens = () => {
    const temp = inputToken;
    setInputToken(outputToken);
    setOutputToken(temp);
  };

  /**
   * 渲染路径预览
   */
  const renderPathPreview = () => {
    if (!pathInfo) return null;

    if (!pathInfo.found) {
      return (
        <div className="path-preview error">
          <p>❌ {pathInfo.message}</p>
        </div>
      );
    }

    return (
      <div className="path-preview">
        <h4>交换路径</h4>
        <div className="path-info">
          <p>
            <strong>跳数:</strong> {pathInfo.hops} 个池子
          </p>
          {pathInfo.intermediateTokens.length > 0 && (
            <p>
              <strong>路径:</strong>{' '}
              {inputToken.symbol} →{' '}
              {pathInfo.intermediateTokens.join(' → ')} →{' '}
              {outputToken.symbol}
            </p>
          )}
          {pathInfo.hops === 1 && (
            <p>
              <strong>路径:</strong> {inputToken.symbol} → {outputToken.symbol} (直接交换)
            </p>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="swap">
      <h2>代币交换（自动路由）</h2>

      <div className="swap-form">
        {/* 输入代币 */}
        <div className="form-group">
          <label>输入代币:</label>
          <select
            value={inputToken.symbol}
            onChange={e => {
              const token = TOKENS[e.target.value];
              if (token) setInputToken(token);
            }}
            disabled={txStatus !== 'idle'}
          >
            {Object.values(TOKENS).map(token => (
              <option key={token.symbol} value={token.symbol}>
                {token.symbol} - {token.name}
              </option>
            ))}
          </select>
        </div>

        {/* 输入数量 */}
        <div className="form-group">
          <label>数量:</label>
          <input
            type="number"
            value={amountIn}
            onChange={e => setAmountIn(e.target.value)}
            step="0.01"
            min="0"
            disabled={txStatus !== 'idle'}
            placeholder="输入数量"
          />
        </div>

        {/* 切换按钮 */}
        <div className="swap-arrow">
          <button
            onClick={handleSwitchTokens}
            disabled={txStatus !== 'idle'}
            className="btn-switch"
          >
            ↕
          </button>
        </div>

        {/* 输出代币 */}
        <div className="form-group">
          <label>输出代币:</label>
          <select
            value={outputToken.symbol}
            onChange={e => {
              const token = TOKENS[e.target.value];
              if (token) setOutputToken(token);
            }}
            disabled={txStatus !== 'idle'}
          >
            {Object.values(TOKENS).map(token => (
              <option key={token.symbol} value={token.symbol}>
                {token.symbol} - {token.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* 路径预览 */}
      {renderPathPreview()}

      {/* 交换按钮和状态 */}
      {txStatus === 'idle' && (
        <button
          onClick={handleSwap}
          disabled={
            !isConnected ||
            !isCorrectNetwork ||
            !pathInfo ||
            !pathInfo.found
          }
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
          <button
            onClick={() => setTxStatus('idle')}
            className="btn btn-secondary btn-sm"
          >
            重试
          </button>
        </div>
      )}

      {(!isConnected || !isCorrectNetwork) && (
        <p className="warning-text">⚠️ 请先连接到正确的网络</p>
      )}
    </div>
  );
}

export default SwapWithAutoRouter;
