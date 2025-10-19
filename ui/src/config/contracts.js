/**
 * 合约配置文件
 * 
 * 包含所有已部署合约的地址和 ABI
 */

import ERC20ABI from '../abi/ERC20.json';
import UniswapV3PoolABI from '../abi/UniswapV3Pool.json';
import UniswapV3ManagerABI from '../abi/UniswapV3Manager.json';
import UniswapV3QuoterABI from '../abi/UniswapV3Quoter.json';

// 从部署脚本获取的合约地址
// 这些地址需要根据实际部署后的地址进行更新
export const CONTRACTS = {
  // ERC20 代币地址
  WETH: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  USDC: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
  
  // UniswapV3 合约地址
  Pool: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
  Manager: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
  Quoter: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
};

// ABI 配置
export const ABIS = {
  ERC20: ERC20ABI,
  Pool: UniswapV3PoolABI,
  Manager: UniswapV3ManagerABI,
  Quoter: UniswapV3QuoterABI,
};

// 网络配置
export const NETWORK_CONFIG = {
  chainId: '0x7a69', // 31337 in hex (Anvil Local)
  chainName: 'Anvil Local',
  rpcUrl: 'http://localhost:8545',
};

// 交易参数（从之前的计算中获得）
export const LIQUIDITY_PARAMS = {
  amount0: '0.998976618347425280', // WETH
  amount1: '5000', // USDC
  lowerTick: 84222,
  upperTick: 86129,
  liquidity: '1517882343751509868544',
};

