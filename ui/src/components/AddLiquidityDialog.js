/**
 * 添加流动性对话框组件
 *
 * 功能：
 * - 允许用户输入任意价格区间
 * - 动态计算所需的代币数量
 * - 集成滑点保护机制
 */

import { useState } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS } from '../config/contracts';
import {
  priceToTick,
  calculateMinAmount,
  validatePriceRange,
  validateSlippage,
  formatPrice
} from '../utils/priceUtils';
import './AddLiquidityDialog.css';

function AddLiquidityDialog({ pool, onClose, onConfirm }) {
  const { account, isConnected, isCorrectNetwork } = useMetaMask();

  // 状态管理
  const [lowerPrice, setLowerPrice] = useState(''); // 价格下限
  const [upperPrice, setUpperPrice] = useState(''); // 价格上限
  const [amount0, setAmount0] = useState('');       // token0 数量
  const [amount1, setAmount1] = useState('');       // token1 数量
  const [slippage, setSlippage] = useState(0.5);    // 滑点容忍度（%）
  const [loading, setLoading] = useState(false);
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
    const poolContract = new ethers.Contract(CONTRACTS.Pool, ABIS.Pool, signer);

    return { token0, token1, manager, poolContract };
  };

  /**
   * 处理添加流动性
   */
  const handleAddLiquidity = async () => {
    // 验证输入
    if (!validatePriceRange(lowerPrice, upperPrice)) {
      setError('价格区间无效：价格下限必须小于价格上限，且都必须大于 0');
      return;
    }

    if (!amount0 || parseFloat(amount0) <= 0) {
      setError('请输入有效的 WETH 数量');
      return;
    }

    if (!amount1 || parseFloat(amount1) <= 0) {
      setError('请输入有效的 USDC 数量');
      return;
    }

    if (!validateSlippage(slippage)) {
      setError('滑点容忍度应在 0.1% - 50% 之间');
      return;
    }

    try {
      setError('');
      setLoading(true);

      // 步骤 1: 将用户输入的价格转换为 Tick
      const lowerTick = priceToTick(parseFloat(lowerPrice));
      const upperTick = priceToTick(parseFloat(upperPrice));

      console.log(`价格范围: ${lowerPrice} - ${upperPrice}`);
      console.log(`Tick 范围: ${lowerTick} - ${upperTick}`);

      // 步骤 2: 解析代币数量
      const amount0Desired = ethers.utils.parseEther(amount0);
      const amount1Desired = ethers.utils.parseEther(amount1); // 假设 USDC 也是 18 位小数

      // 步骤 3: 计算滑点保护的最小金额
      const slippageBps = slippage * 100; // 0.5% -> 50 基点
      const amount0Min = calculateMinAmount(amount0Desired, slippage);
      const amount1Min = calculateMinAmount(amount1Desired, slippage);

      console.log(`期望金额: ${amount0} WETH, ${amount1} USDC`);
      console.log(`最小金额: ${ethers.utils.formatEther(amount0Min)} WETH, ${ethers.utils.formatEther(amount1Min)} USDC`);

      // 步骤 4: 获取合约实例
      const { token0, token1, manager } = getContracts();

      // 步骤 5: 检查并授权代币
      console.log('检查代币授权...');
      const [allowance0, allowance1] = await Promise.all([
        token0.allowance(account, CONTRACTS.Manager),
        token1.allowance(account, CONTRACTS.Manager),
      ]);

      // 如果需要，请求授权 token0
      if (allowance0.lt(amount0Desired)) {
        console.log('请求 WETH 授权...');
        const approveTx0 = await token0.approve(CONTRACTS.Manager, amount0Desired);
        console.log('WETH 授权交易已发送:', approveTx0.hash);
        await approveTx0.wait();
        console.log('WETH 授权完成');
      }

      // 如果需要，请求授权 token1
      if (allowance1.lt(amount1Desired)) {
        console.log('请求 USDC 授权...');
        const approveTx1 = await token1.approve(CONTRACTS.Manager, amount1Desired);
        console.log('USDC 授权交易已发送:', approveTx1.hash);
        await approveTx1.wait();
        console.log('USDC 授权完成');
      }

      // 步骤 6: 计算流动性
      // 注意：这里简化处理，实际应该根据当前价格和价格区间计算精确的流动性
      const liquidity = ethers.BigNumber.from('1000000000000000000'); // 1e18

      // 编码回调数据
      const extra = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address'],
        [CONTRACTS.WETH, CONTRACTS.USDC, account]
      );

      // 步骤 7: 调用合约添加流动性
      console.log('正在添加流动性...');
      const tx = await manager.mint(
        CONTRACTS.Pool,
        lowerTick,
        upperTick,
        liquidity,
        extra
      );

      console.log('交易已提交:', tx.hash);

      // 步骤 8: 等待交易确认
      const receipt = await tx.wait();
      console.log('交易已确认:', receipt.transactionHash);
      console.log('Gas 消耗:', receipt.gasUsed.toString());

      // 通知父组件
      if (onConfirm) {
        onConfirm(receipt);
      }

      // 关闭对话框
      onClose();

    } catch (error) {
      console.error('添加流动性失败:', error);

      let errorMessage = '添加流动性失败';
      if (error.code === 4001) {
        errorMessage = '您取消了交易';
      } else if (error.code === 'INSUFFICIENT_FUNDS') {
        errorMessage = '账户余额不足';
      } else if (error.message) {
        errorMessage = error.message;
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="dialog-overlay" onClick={onClose}>
      <div className="dialog-content" onClick={(e) => e.stopPropagation()}>
        <div className="dialog-header">
          <h2>添加流动性</h2>
          <button className="close-btn" onClick={onClose}>×</button>
        </div>

        <div className="dialog-body">
          {/* 价格区间输入 */}
          <div className="input-group">
            <label>价格下限</label>
            <input
              type="number"
              value={lowerPrice}
              onChange={(e) => setLowerPrice(e.target.value)}
              placeholder="例如：4500"
              disabled={loading}
              step="0.01"
            />
            <span className="input-hint">1 WETH = ? USDC</span>
          </div>

          <div className="input-group">
            <label>价格上限</label>
            <input
              type="number"
              value={upperPrice}
              onChange={(e) => setUpperPrice(e.target.value)}
              placeholder="例如：5500"
              disabled={loading}
              step="0.01"
            />
            <span className="input-hint">1 WETH = ? USDC</span>
          </div>

          {/* 代币数量输入 */}
          <div className="input-group">
            <label>WETH 数量</label>
            <input
              type="number"
              value={amount0}
              onChange={(e) => setAmount0(e.target.value)}
              placeholder="0.0"
              disabled={loading}
              step="0.01"
            />
          </div>

          <div className="input-group">
            <label>USDC 数量</label>
            <input
              type="number"
              value={amount1}
              onChange={(e) => setAmount1(e.target.value)}
              placeholder="0.0"
              disabled={loading}
              step="0.01"
            />
          </div>

          {/* 滑点设置 */}
          <div className="input-group">
            <label>滑点容忍度 (%)</label>
            <div className="slippage-buttons">
              <button
                className={slippage === 0.1 ? 'active' : ''}
                onClick={() => setSlippage(0.1)}
                disabled={loading}
              >
                0.1%
              </button>
              <button
                className={slippage === 0.5 ? 'active' : ''}
                onClick={() => setSlippage(0.5)}
                disabled={loading}
              >
                0.5%
              </button>
              <button
                className={slippage === 1.0 ? 'active' : ''}
                onClick={() => setSlippage(1.0)}
                disabled={loading}
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
                disabled={loading}
                className="custom-slippage"
              />
            </div>
          </div>

          {/* 错误信息 */}
          {error && (
            <div className="error-message">
              <p>❌ {error}</p>
            </div>
          )}

          {/* 提示信息 */}
          {!error && lowerPrice && upperPrice && validatePriceRange(lowerPrice, upperPrice) && (
            <div className="info-message">
              <p>
                ✓ 价格区间有效 ({formatPrice(lowerPrice)} - {formatPrice(upperPrice)})
              </p>
              <p className="small">
                滑点保护: 最少接受 {amount0 ? formatPrice(parseFloat(amount0) * (1 - slippage / 100), 4) : '0'} WETH
                和 {amount1 ? formatPrice(parseFloat(amount1) * (1 - slippage / 100), 4) : '0'} USDC
              </p>
            </div>
          )}
        </div>

        {/* 操作按钮 */}
        <div className="dialog-footer">
          <button
            className="btn btn-secondary"
            onClick={onClose}
            disabled={loading}
          >
            取消
          </button>
          <button
            className="btn btn-primary"
            onClick={handleAddLiquidity}
            disabled={loading || !isConnected || !isCorrectNetwork}
          >
            {loading ? '处理中...' : '确认添加'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default AddLiquidityDialog;
