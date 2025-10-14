/**
 * 合约配置文件
 * 
 * 包含所有已部署合约的地址和 ABI
 */

import ERC20ABI from '../abi/ERC20.json';
import UniswapV3PoolABI from '../abi/UniswapV3Pool.json';
import UniswapV3ManagerABI from '../abi/UniswapV3Manager.json';

// 从部署脚本获取的合约地址
// 这些地址需要根据实际部署后的地址进行更新
export const CONTRACTS = {
  // ERC20 代币地址
  WETH: '0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690',
  USDC: '0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB',
  
  // UniswapV3 合约地址
  Pool: '0x9E545E3C0baAB3E08CdfD552C960A1050f373042',
  Manager: '0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9',
};

// ABI 配置
export const ABIS = {
  ERC20: ERC20ABI,
  Pool: UniswapV3PoolABI,
  Manager: UniswapV3ManagerABI,
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

