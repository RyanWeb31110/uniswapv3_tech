/**
 * UniswapV3 用户界面主应用程序
 * 
 * 功能：
 * - 连接 MetaMask 钱包
 * - 添加流动性
 * - 代币交换
 * - 实时事件监听
 */

import { MetaMaskProvider } from './contexts/MetaMaskContext';
import WalletConnect from './components/WalletConnect';
import AddLiquidity from './components/AddLiquidity';
import Swap from './components/Swap';
import EventFeed from './components/EventFeed';
import './App.css';

function App() {
  /**
   * 交易成功回调
   */
  const handleTransactionSuccess = (receipt) => {
    console.log('交易成功:', receipt);
    // 事件订阅会自动更新列表，无需手动刷新
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
                <AddLiquidity onSuccess={handleTransactionSuccess} />
                <Swap onSuccess={handleTransactionSuccess} />
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
      </div>
    </MetaMaskProvider>
  );
}

export default App;
