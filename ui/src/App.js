/**
 * UniswapV3 用户界面主应用程序
 *
 * 功能：
 * - 连接 MetaMask 钱包
 * - 添加流动性（支持自定义价格区间和滑点保护）
 * - 代币交换（支持滑点容忍度设置）
 * - 实时事件监听
 */

import { useState } from 'react';
import { MetaMaskProvider } from './contexts/MetaMaskContext';
import WalletConnect from './components/WalletConnect';
import AddLiquidity from './components/AddLiquidity';
import AddLiquidityDialog from './components/AddLiquidityDialog';
import Swap from './components/Swap';
import EnhancedSwap from './components/EnhancedSwap';
import SwapWithSlippage from './components/SwapWithSlippage';
import EventFeed from './components/EventFeed';
import './App.css';

function App() {
  const [showAddLiquidityDialog, setShowAddLiquidityDialog] = useState(false);

  /**
   * 交易成功回调
   */
  const handleTransactionSuccess = (receipt) => {
    console.log('交易成功:', receipt);
    // 事件订阅会自动更新列表，无需手动刷新
  };

  /**
   * 添加流动性对话框确认回调
   */
  const handleAddLiquidityConfirm = (receipt) => {
    console.log('流动性已添加:', receipt);
    handleTransactionSuccess(receipt);
  };

  return (
    <MetaMaskProvider>
      <div className="App">
        <header className="App-header">
          <div className="container">
            <h1>🦄 UniswapV3 Demo</h1>
            <p className="subtitle">去中心化交易所演示应用</p>
          </div>
        </header>

        <main className="App-main">
          <div className="container">
            <div className="grid">
              {/* 左侧：钱包和交易操作 */}
              <div className="left-column">
                <WalletConnect />

                {/* 原有的添加流动性组件（使用硬编码参数） */}
                <AddLiquidity onSuccess={handleTransactionSuccess} />

                {/* 新增：打开添加流动性对话框的按钮 */}
                <div className="add-liquidity-custom">
                  <button
                    className="btn btn-primary"
                    onClick={() => setShowAddLiquidityDialog(true)}
                    style={{
                      width: '100%',
                      padding: '16px',
                      marginBottom: '24px',
                      backgroundColor: '#10b981',
                      color: 'white',
                      border: 'none',
                      borderRadius: '12px',
                      fontSize: '16px',
                      fontWeight: '600',
                      cursor: 'pointer'
                    }}
                  >
                    ➕ 添加流动性（自定义价格区间）
                  </button>
                </div>

                {/* 原有的交换组件 */}
                <Swap onSuccess={handleTransactionSuccess} />
                <EnhancedSwap onSuccess={handleTransactionSuccess} />

                {/* 新增：带滑点保护的交换组件 */}
                <SwapWithSlippage onSuccess={handleTransactionSuccess} />
              </div>

              {/* 右侧：事件列表 */}
              <div className="right-column">
                <EventFeed />
              </div>
            </div>
          </div>
        </main>

        <footer className="App-footer">
          <div className="container">
            <p>
              基于 UniswapV3 的去中心化交易所演示 | {' '}
              <a
                href="https://github.com/RyanWeb31110/uniswapv3_tech"
                target="_blank"
                rel="noopener noreferrer"
              >
                GitHub
              </a>
            </p>
            <p className="small">
              ⚠️ 仅用于学习和测试，请勿用于生产环境
            </p>
          </div>
        </footer>

        {/* 添加流动性对话框 */}
        {showAddLiquidityDialog && (
          <AddLiquidityDialog
            onClose={() => setShowAddLiquidityDialog(false)}
            onConfirm={handleAddLiquidityConfirm}
          />
        )}
      </div>
    </MetaMaskProvider>
  );
}

export default App;
