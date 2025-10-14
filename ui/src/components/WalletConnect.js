/**
 * 钱包连接组件
 * 
 * 显示连接状态和账户信息
 */

import { useMetaMask } from '../contexts/MetaMaskContext';
import './WalletConnect.css';

function WalletConnect() {
  const { account, chainId, status, connect, disconnect, isConnected, isCorrectNetwork } = useMetaMask();

  /**
   * 格式化地址显示
   */
  const formatAddress = (addr) => {
    if (!addr) return '';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  /**
   * 获取链 ID 的十进制表示
   */
  const getChainIdDecimal = () => {
    if (!chainId) return '';
    return parseInt(chainId, 16);
  };

  /**
   * 获取网络名称
   */
  const getNetworkName = () => {
    const chainIdDec = getChainIdDecimal();
    const networks = {
      31337: 'Anvil Local',
      1: 'Ethereum Mainnet',
      5: 'Goerli Testnet',
      11155111: 'Sepolia Testnet',
    };
    return networks[chainIdDec] || `Chain ${chainIdDec}`;
  };

  /**
   * 渲染状态指示器
   */
  const renderStatusIndicator = () => {
    if (status === 'not_installed') {
      return <span className="status-indicator not-installed">● 未安装 MetaMask</span>;
    } else if (status === 'connecting') {
      return <span className="status-indicator connecting">● 连接中...</span>;
    } else if (status === 'connected') {
      if (isCorrectNetwork) {
        return <span className="status-indicator connected">● 已连接</span>;
      } else {
        return <span className="status-indicator wrong-network">● 网络错误</span>;
      }
    } else if (status === 'error') {
      return <span className="status-indicator error">● 连接失败</span>;
    } else {
      return <span className="status-indicator not-connected">● 未连接</span>;
    }
  };

  return (
    <div className="wallet-connect">
      <h2>钱包连接</h2>
      
      {status === 'not_installed' && (
        <div className="wallet-status">
          <p>未检测到 MetaMask</p>
          <a 
            href="https://metamask.io/download/" 
            target="_blank" 
            rel="noopener noreferrer"
            className="btn btn-primary"
          >
            安装 MetaMask
          </a>
        </div>
      )}

      {status === 'not_connected' && (
        <div className="wallet-status">
          <p>请连接您的钱包</p>
          <button onClick={connect} className="btn btn-primary">
            连接 MetaMask
          </button>
        </div>
      )}

      {status === 'connecting' && (
        <div className="wallet-status">
          <p>正在连接...</p>
        </div>
      )}

      {isConnected && (
        <div className="wallet-info">
          <div className="info-row">
            <span className="label">状态:</span>
            {renderStatusIndicator()}
          </div>
          
          <div className="info-row">
            <span className="label">账户:</span>
            <span className="value" title={account}>
              {formatAddress(account)}
            </span>
          </div>

          <div className="info-row">
            <span className="label">网络:</span>
            <span className={`value ${isCorrectNetwork ? '' : 'error'}`}>
              {getNetworkName()}
            </span>
          </div>

          {!isCorrectNetwork && (
            <div className="warning-message">
              <p>⚠️ 请切换到 Anvil Local 网络 (Chain ID: 31337)</p>
              <p className="small">RPC URL: http://localhost:8545</p>
            </div>
          )}

          <button onClick={disconnect} className="btn btn-secondary btn-sm">
            断开连接
          </button>
        </div>
      )}
    </div>
  );
}

export default WalletConnect;

