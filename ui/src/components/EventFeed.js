/**
 * 事件订阅组件
 * 
 * 实时显示链上 Mint 和 Swap 事件
 */

import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { useMetaMask } from '../contexts/MetaMaskContext';
import { CONTRACTS, ABIS } from '../config/contracts';
import './EventFeed.css';

function EventFeed() {
  const { isConnected, isCorrectNetwork } = useMetaMask();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);

  /**
   * 加载历史事件
   */
  const loadHistoricalEvents = useCallback(async () => {
    if (!isConnected || !isCorrectNetwork) return;

    try {
      setLoading(true);

      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const pool = new ethers.Contract(CONTRACTS.Pool, ABIS.Pool, provider);

      // 查询最近的事件（最近 1000 个区块）
      const currentBlock = await provider.getBlockNumber();
      const fromBlock = Math.max(0, currentBlock - 1000);

      console.log(`查询事件: ${fromBlock} -> ${currentBlock}`);

      const [mints, swaps] = await Promise.all([
        pool.queryFilter('Mint', fromBlock, 'latest'),
        pool.queryFilter('Swap', fromBlock, 'latest'),
      ]);

      console.log(`找到 ${mints.length} 个 Mint 事件`);
      console.log(`找到 ${swaps.length} 个 Swap 事件`);

      // 合并并按区块号排序
      const combined = [...mints, ...swaps]
        .sort((a, b) => {
          if (b.blockNumber !== a.blockNumber) {
            return b.blockNumber - a.blockNumber;
          }
          return b.logIndex - a.logIndex;
        })
        .slice(0, 50); // 只显示最近 50 条

      setEvents(combined);
      setLoading(false);
    } catch (error) {
      console.error('加载历史事件失败:', error);
      setLoading(false);
    }
  }, [isConnected, isCorrectNetwork]);

  /**
   * 订阅新事件
   */
  useEffect(() => {
    if (!isConnected || !isCorrectNetwork) return;

    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const pool = new ethers.Contract(CONTRACTS.Pool, ABIS.Pool, provider);

    // 加载历史事件
    loadHistoricalEvents();

    // 订阅 Mint 事件
    const handleMint = (...args) => {
      const event = args[args.length - 1];
      console.log('检测到 Mint 事件:', event);
      setEvents(prevEvents => [event, ...prevEvents].slice(0, 50));
    };

    // 订阅 Swap 事件
    const handleSwap = (...args) => {
      const event = args[args.length - 1];
      console.log('检测到 Swap 事件:', event);
      setEvents(prevEvents => [event, ...prevEvents].slice(0, 50));
    };

    pool.on('Mint', handleMint);
    pool.on('Swap', handleSwap);

    console.log('事件订阅已启动');

    // 清理函数：取消订阅
    return () => {
      pool.off('Mint', handleMint);
      pool.off('Swap', handleSwap);
      console.log('事件订阅已取消');
    };
  }, [isConnected, isCorrectNetwork, loadHistoricalEvents]);

  return (
    <div className="event-feed">
      <div className="event-feed-header">
        <h2>实时事件</h2>
        <button 
          onClick={loadHistoricalEvents} 
          disabled={loading || !isConnected || !isCorrectNetwork}
          className="btn btn-secondary btn-sm"
        >
          {loading ? '加载中...' : '刷新'}
        </button>
      </div>

      {loading && (
        <div className="loading">
          <div className="spinner"></div>
          <p>加载事件...</p>
        </div>
      )}

      {!loading && events.length === 0 && (
        <div className="empty-state">
          <p>暂无事件</p>
          {(!isConnected || !isCorrectNetwork) && (
            <p className="small">请先连接到正确的网络</p>
          )}
        </div>
      )}

      <div className="event-list">
        {events.map((event) => (
          <EventItem key={`${event.transactionHash}-${event.logIndex}`} event={event} />
        ))}
      </div>
    </div>
  );
}

/**
 * 单个事件项组件
 */
function EventItem({ event }) {
  const [expanded, setExpanded] = useState(false);

  /**
   * 格式化地址
   */
  const formatAddress = (addr) => {
    if (!addr || typeof addr !== 'string') return 'N/A';
    if (addr.length < 10) return addr; // 太短的地址直接返回
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  /**
   * 格式化交易哈希
   */
  const formatTxHash = (hash) => {
    if (!hash || typeof hash !== 'string') return 'N/A';
    if (hash.length < 14) return hash; // 太短的哈希直接返回
    return `${hash.slice(0, 10)}...`;
  };

  /**
   * 安全地格式化数值
   */
  const safeFormatValue = (value, formatter = null) => {
    if (value === undefined || value === null) {
      return 'N/A';
    }
    try {
      if (formatter) {
        return formatter(value);
      }
      return value.toString();
    } catch (error) {
      console.warn('格式化数值失败:', value, error);
      return 'N/A';
    }
  };

  /**
   * 渲染事件详情
   */
  const renderEventDetails = () => {
    if (event.event === 'Mint') {
      return (
        <>
          <div className="detail-row">
            <span className="label">发送者:</span>
            <span className="value" title={event.args?.sender || ''}>
              {formatAddress(event.args?.sender)}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">所有者:</span>
            <span className="value" title={event.args?.owner || ''}>
              {formatAddress(event.args?.owner)}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">Tick 范围:</span>
            <span className="value">
              {safeFormatValue(event.args?.tickLower)} ~ {safeFormatValue(event.args?.tickUpper)}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">流动性:</span>
            <span className="value small">{safeFormatValue(event.args?.amount)}</span>
          </div>
          <div className="detail-row">
            <span className="label">WETH:</span>
            <span className="value">
              {safeFormatValue(event.args?.amount0, (val) => ethers.utils.formatEther(val))}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">USDC:</span>
            <span className="value">
              {safeFormatValue(event.args?.amount1, (val) => ethers.utils.formatEther(val))}
            </span>
          </div>
        </>
      );
    } else if (event.event === 'Swap') {
      const amount0 = event.args?.amount0;
      const amount1 = event.args?.amount1;
      
      return (
        <>
          <div className="detail-row">
            <span className="label">发送者:</span>
            <span className="value" title={event.args?.sender || ''}>
              {formatAddress(event.args?.sender)}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">接收者:</span>
            <span className="value" title={event.args?.recipient || ''}>
              {formatAddress(event.args?.recipient)}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">Amount0:</span>
            <span className="value">
              {safeFormatValue(amount0, (val) => ethers.utils.formatEther(val))}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">Amount1:</span>
            <span className="value">
              {safeFormatValue(amount1, (val) => ethers.utils.formatEther(val))}
            </span>
          </div>
          <div className="detail-row">
            <span className="label">流动性:</span>
            <span className="value small">{safeFormatValue(event.args?.liquidity)}</span>
          </div>
          <div className="detail-row">
            <span className="label">当前 Tick:</span>
            <span className="value">{safeFormatValue(event.args?.tick)}</span>
          </div>
        </>
      );
    }
    return null;
  };

  return (
    <div className={`event-item ${event.event.toLowerCase()}`}>
      <div className="event-header" onClick={() => setExpanded(!expanded)}>
        <div className="event-type">
          <span className={`badge ${event.event.toLowerCase()}`}>
            {event.event}
          </span>
          <span className="block-number">区块 #{event.blockNumber}</span>
        </div>
        <div className="event-meta">
          <span className="tx-hash" title={event.transactionHash}>
            {formatTxHash(event.transactionHash)}
          </span>
          <span className="expand-icon">{expanded ? '▼' : '▶'}</span>
        </div>
      </div>

      {expanded && (
        <div className="event-details">
          {renderEventDetails()}
        </div>
      )}
    </div>
  );
}

export default EventFeed;

