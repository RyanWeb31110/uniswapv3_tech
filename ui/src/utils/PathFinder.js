/**
 * 路径查找器：在代币图中查找最短交换路径
 *
 * 使用 A* 搜索算法在代币图中找到最短的交换路径
 */

import createGraph from 'ngraph.graph';
import path from 'ngraph.path';

class PathFinder {
  /**
   * 构造函数
   * @param {Array} pairs - 代币对数组
   * @param {Object} pairs[].token0 - 代币0（包含 address 和 symbol）
   * @param {Object} pairs[].token1 - 代币1（包含 address 和 symbol）
   * @param {Number} pairs[].tickSpacing - Tick 间距（费率档位）
   */
  constructor(pairs) {
    // 创建图数据结构
    this.graph = createGraph();

    // 构建代币图
    pairs.forEach((pair) => {
      // 添加代币节点（使用地址作为节点 ID）
      this.graph.addNode(pair.token0.address.toLowerCase());
      this.graph.addNode(pair.token1.address.toLowerCase());

      // 添加双向边（池子）
      // 交换可以双向进行，所以添加两条边
      this.graph.addLink(
        pair.token0.address.toLowerCase(),
        pair.token1.address.toLowerCase(),
        pair.tickSpacing
      );
      this.graph.addLink(
        pair.token1.address.toLowerCase(),
        pair.token0.address.toLowerCase(),
        pair.tickSpacing
      );
    });

    // 初始化 A* 搜索算法
    this.finder = path.aStar(this.graph);
  }

  /**
   * 查找两个代币之间的最短路径
   * @param {String} fromToken - 起始代币地址
   * @param {String} toToken - 目标代币地址
   * @returns {Array} 路径数组 [token, tickSpacing, token, tickSpacing, token, ...]
   *                  如果没有路径，返回空数组
   */
  findPath(fromToken, toToken) {
    try {
      // 统一转换为小写
      const from = fromToken.toLowerCase();
      const to = toToken.toLowerCase();

      // 使用 A* 查找节点路径
      const nodePath = this.finder.find(from, to);

      // 如果没有找到路径
      if (!nodePath || nodePath.length === 0) {
        return [];
      }

      // 转换为完整路径格式：[token, tickSpacing, token, tickSpacing, ...]
      const completePath = nodePath
        .reduce((acc, node, i, orig) => {
          // 如果不是第一个节点，添加边的信息（tickSpacing）
          if (acc.length > 0) {
            const link = this.graph.getLink(orig[i - 1].id, node.id);
            // link.data 存储的是 tickSpacing
            acc.push(link.data);
          }

          // 添加当前节点（代币地址）
          acc.push(node.id);

          return acc;
        }, [])
        .reverse(); // 反转数组得到从起点到终点的顺序

      return completePath;
    } catch (error) {
      console.error('路径查找失败:', error);
      return [];
    }
  }

  /**
   * 检查两个代币之间是否存在路径
   * @param {String} fromToken - 起始代币地址
   * @param {String} toToken - 目标代币地址
   * @returns {Boolean} 是否存在路径
   */
  hasPath(fromToken, toToken) {
    const pathResult = this.findPath(fromToken, toToken);
    return pathResult && pathResult.length > 0;
  }

  /**
   * 获取路径中的跳数（经过的池子数量）
   * @param {String} fromToken - 起始代币地址
   * @param {String} toToken - 目标代币地址
   * @returns {Number} 跳数，如果没有路径返回 -1
   */
  getPathLength(fromToken, toToken) {
    const pathResult = this.findPath(fromToken, toToken);
    if (!pathResult || pathResult.length === 0) {
      return -1;
    }
    // 路径格式是 [token, tickSpacing, token, ...]
    // 池子数量 = (路径长度 - 1) / 2
    return (pathResult.length - 1) / 2;
  }

  /**
   * 获取图中所有节点（代币）
   * @returns {Array} 代币地址数组
   */
  getAllNodes() {
    const nodes = [];
    this.graph.forEachNode((node) => {
      nodes.push(node.id);
    });
    return nodes;
  }

  /**
   * 获取与指定代币直接相连的代币
   * @param {String} tokenAddress - 代币地址
   * @returns {Array} 相邻代币地址数组
   */
  getNeighbors(tokenAddress) {
    const neighbors = [];
    const token = tokenAddress.toLowerCase();

    this.graph.forEachLinkedNode(token, (linkedNode) => {
      neighbors.push(linkedNode.id);
    });

    return neighbors;
  }
}

export default PathFinder;
