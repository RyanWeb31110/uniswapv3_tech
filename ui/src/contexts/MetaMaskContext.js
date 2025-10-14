/**
 * MetaMask 上下文
 * 
 * 管理 MetaMask 连接状态和账户信息
 */

import { createContext, useContext, useState, useEffect } from 'react';
import { NETWORK_CONFIG } from '../config/contracts';

const MetaMaskContext = createContext();

export function useMetaMask() {
  const context = useContext(MetaMaskContext);
  if (!context) {
    throw new Error('useMetaMask must be used within MetaMaskProvider');
  }
  return context;
}

export function MetaMaskProvider({ children }) {
  const [account, setAccount] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [status, setStatus] = useState('not_connected'); // not_installed, not_connected, connecting, connected, error

  /**
   * 连接到 MetaMask
   */
  const connect = async () => {
    // 检查 MetaMask 是否已安装
    if (typeof window.ethereum === 'undefined') {
      setStatus('not_installed');
      window.alert('请先安装 MetaMask！');
      return;
    }

    try {
      setStatus('connecting');

      // 并行请求账户和链 ID
      const [accounts, currentChainId] = await Promise.all([
        window.ethereum.request({ method: 'eth_requestAccounts' }),
        window.ethereum.request({ method: 'eth_chainId' }),
      ]);

      setAccount(accounts[0]);
      setChainId(currentChainId);
      setStatus('connected');

      console.log('已连接账户:', accounts[0]);
      console.log('当前链 ID:', currentChainId);

      // 检查是否连接到正确的网络
      if (currentChainId !== NETWORK_CONFIG.chainId) {
        const shouldSwitch = window.confirm(
          `当前网络不正确。是否自动切换到 ${NETWORK_CONFIG.chainName} 网络？\n\n` +
          `当前网络: Chain ID ${parseInt(currentChainId, 16)}\n` +
          `目标网络: Chain ID ${parseInt(NETWORK_CONFIG.chainId, 16)}\n\n` +
          `点击"确定"自动切换，点击"取消"手动切换`
        );
        
        if (shouldSwitch) {
          await switchToAnvilNetwork();
        } else {
          window.alert(`请手动切换到 ${NETWORK_CONFIG.chainName} 网络 (Chain ID: ${parseInt(NETWORK_CONFIG.chainId, 16)})\nRPC URL: ${NETWORK_CONFIG.rpcUrl}`);
        }
      }
    } catch (error) {
      console.error('连接 MetaMask 失败:', error);
      setStatus('error');
      
      if (error.code === 4001) {
        window.alert('您拒绝了连接请求');
      } else {
        window.alert('连接失败: ' + error.message);
      }
    }
  };

  /**
   * 自动切换到 Anvil 网络
   */
  const switchToAnvilNetwork = async () => {
    try {
      // 尝试切换到网络
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: NETWORK_CONFIG.chainId }],
      });
      
      console.log('网络切换成功');
      // 重新获取链 ID
      const newChainId = await window.ethereum.request({ method: 'eth_chainId' });
      setChainId(newChainId);
      
    } catch (error) {
      if (error.code === 4902) {
        // 网络不存在，尝试添加
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: NETWORK_CONFIG.chainId,
              chainName: NETWORK_CONFIG.chainName,
              rpcUrls: [NETWORK_CONFIG.rpcUrl],
              nativeCurrency: {
                name: 'Ether',
                symbol: 'ETH',
                decimals: 18
              }
            }]
          });
          
          console.log('网络添加并切换成功');
          setChainId(NETWORK_CONFIG.chainId);
          
        } catch (addError) {
          console.error('添加网络失败:', addError);
          window.alert(`添加网络失败: ${addError.message}`);
        }
      } else {
        console.error('切换网络失败:', error);
        window.alert(`切换网络失败: ${error.message}`);
      }
    }
  };

  /**
   * 断开连接
   */
  const disconnect = () => {
    setAccount(null);
    setChainId(null);
    setStatus('not_connected');
  };

  /**
   * 监听账户变化
   */
  useEffect(() => {
    if (typeof window.ethereum === 'undefined') {
      return;
    }

    const handleAccountsChanged = (accounts) => {
      console.log('账户已变化:', accounts);
      if (accounts.length === 0) {
        // 用户断开了连接
        disconnect();
      } else {
        // 用户切换了账户
        setAccount(accounts[0]);
      }
    };

    const handleChainChanged = (newChainId) => {
      console.log('网络已变化:', newChainId);
      // 建议重新加载页面以确保状态同步
      window.location.reload();
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);

    // 清理函数
    return () => {
      if (window.ethereum.removeListener) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      }
    };
  }, []);

  /**
   * 自动连接（如果之前已授权）
   */
  useEffect(() => {
    if (typeof window.ethereum === 'undefined') {
      setStatus('not_installed');
      return;
    }

    // 检查是否已经连接
    window.ethereum.request({ method: 'eth_accounts' })
      .then((accounts) => {
        if (accounts.length > 0) {
          // 已经授权过，自动连接
          connect();
        } else {
          setStatus('not_connected');
        }
      })
      .catch((error) => {
        console.error('检查账户失败:', error);
        setStatus('not_connected');
      });
  }, []);

  const value = {
    account,
    chainId,
    status,
    connect,
    disconnect,
    isConnected: status === 'connected',
    isCorrectNetwork: chainId === NETWORK_CONFIG.chainId,
  };

  return (
    <MetaMaskContext.Provider value={value}>
      {children}
    </MetaMaskContext.Provider>
  );
}

