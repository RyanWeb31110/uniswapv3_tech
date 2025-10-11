#!/usr/bin/env python3
"""
Uniswap V3 数学计算工具
计算为 ETH/USDC 池子提供流动性所需的精确参数

使用方法:
    python scripts/unimath.py

参考文档: docs/1FirstSwap/05-流动性计算.md
"""

import math
import sys


# ============================================================
# 常量定义
# ============================================================

Q96 = 2**96  # Q64.96 定点数格式的基数
ETH = 10**18  # 1 ETH = 10^18 wei


# ============================================================
# 价格和 Tick 转换工具
# ============================================================

def price_to_tick(price):
    """
    将价格转换为 Tick 索引
    
    参数:
        price: 价格（USDC/ETH）
    
    返回:
        Tick 索引（整数）
    """
    return math.floor(math.log(price, 1.0001))


def tick_to_price(tick):
    """
    将 Tick 索引转换为价格
    
    参数:
        tick: Tick 索引
    
    返回:
        价格
    """
    return 1.0001 ** tick


def price_to_sqrtp(price):
    """
    将价格转换为平方根价格（浮点数）
    
    参数:
        price: 价格
    
    返回:
        平方根价格
    """
    return math.sqrt(price)


def price_to_sqrtp_q96(price):
    """
    将价格转换为 Q64.96 格式的平方根价格
    
    参数:
        price: 价格
    
    返回:
        Q64.96 格式的平方根价格（整数）
    """
    return int(math.sqrt(price) * Q96)


def sqrtp_q96_to_price(sqrtp_q96):
    """
    将 Q64.96 格式的平方根价格转换回价格
    
    参数:
        sqrtp_q96: Q64.96 格式的平方根价格
    
    返回:
        价格
    """
    return (sqrtp_q96 / Q96) ** 2


# ============================================================
# 流动性计算
# ============================================================

def liquidity_from_x(amount, pa, pb):
    """
    从 x 代币（ETH）数量计算流动性
    
    公式: L = Δx × (√P_b × √P_c) / (√P_b - √P_c)
    
    参数:
        amount: x 代币数量（wei）
        pa: 当前平方根价格（Q64.96）
        pb: 上限平方根价格（Q64.96）
    
    返回:
        流动性值 L
    """
    if pa > pb:
        pa, pb = pb, pa
    return (amount * (pa * pb) / Q96) / (pb - pa)


def liquidity_from_y(amount, pa, pb):
    """
    从 y 代币（USDC）数量计算流动性
    
    公式: L = Δy / (√P_c - √P_a)
    
    参数:
        amount: y 代币数量（wei）
        pa: 下限平方根价格（Q64.96）
        pb: 当前平方根价格（Q64.96）
    
    返回:
        流动性值 L
    """
    if pa > pb:
        pa, pb = pb, pa
    return amount * Q96 / (pb - pa)


# ============================================================
# 代币数量计算
# ============================================================

def calc_amount_x(liquidity, pa, pb):
    """
    从流动性计算 x 代币（ETH）数量
    
    公式: Δx = L × (√P_b - √P_c) / (√P_b × √P_c)
    
    参数:
        liquidity: 流动性值
        pa: 当前平方根价格（Q64.96）
        pb: 上限平方根价格（Q64.96）
    
    返回:
        x 代币数量（wei）
    """
    if pa > pb:
        pa, pb = pb, pa
    return int(liquidity * Q96 * (pb - pa) / pa / pb)


def calc_amount_y(liquidity, pa, pb):
    """
    从流动性计算 y 代币（USDC）数量
    
    公式: Δy = L × (√P_c - √P_a)
    
    参数:
        liquidity: 流动性值
        pa: 下限平方根价格（Q64.96）
        pb: 当前平方根价格（Q64.96）
    
    返回:
        y 代币数量（wei）
    """
    if pa > pb:
        pa, pb = pb, pa
    return int(liquidity * (pb - pa) / Q96)


# ============================================================
# 格式化输出工具
# ============================================================

def format_wei(amount, decimals=18):
    """
    将 wei 格式化为人类可读的格式
    
    参数:
        amount: wei 数量
        decimals: 小数位数
    
    返回:
        格式化的字符串
    """
    return amount / (10 ** decimals)


def print_separator(title=""):
    """打印分隔线"""
    if title:
        print(f"\n{'=' * 60}")
        print(f"{title}")
        print('=' * 60)
    else:
        print('=' * 60)


# ============================================================
# 主计算流程
# ============================================================

def calculate_liquidity(
    price_current,
    price_lower,
    price_upper,
    amount_eth,
    amount_usdc,
    verbose=True
):
    """
    计算流动性和精确代币数量的完整流程
    
    参数:
        price_current: 当前价格（USDC/ETH）
        price_lower: 下限价格
        price_upper: 上限价格
        amount_eth: ETH 数量
        amount_usdc: USDC 数量
        verbose: 是否打印详细信息
    
    返回:
        字典，包含所有计算结果
    """
    results = {}
    
    # 步骤 1: 计算 Tick
    if verbose:
        print_separator("步骤 1: 计算价格区间的 Tick 值")
    
    tick_current = price_to_tick(price_current)
    tick_lower = price_to_tick(price_lower)
    tick_upper = price_to_tick(price_upper)
    
    if verbose:
        print(f"当前价格 {price_current} USDC/ETH -> Tick {tick_current}")
        print(f"下限价格 {price_lower} USDC/ETH -> Tick {tick_lower}")
        print(f"上限价格 {price_upper} USDC/ETH -> Tick {tick_upper}")
    
    results['tick_current'] = tick_current
    results['tick_lower'] = tick_lower
    results['tick_upper'] = tick_upper
    
    # 步骤 2: 转换为 Q64.96 格式
    if verbose:
        print_separator("步骤 2: 转换为 Q64.96 格式")
    
    sqrtp_low = price_to_sqrtp_q96(price_lower)
    sqrtp_cur = price_to_sqrtp_q96(price_current)
    sqrtp_upp = price_to_sqrtp_q96(price_upper)
    
    if verbose:
        print(f"下限 sqrtP: {sqrtp_low}")
        print(f"当前 sqrtP: {sqrtp_cur}")
        print(f"上限 sqrtP: {sqrtp_upp}")
    
    results['sqrtp_low'] = sqrtp_low
    results['sqrtp_cur'] = sqrtp_cur
    results['sqrtp_upp'] = sqrtp_upp
    
    # 步骤 3: 计算流动性
    if verbose:
        print_separator("步骤 3: 计算流动性 L")
    
    amount_eth_wei = int(amount_eth * ETH)
    amount_usdc_wei = int(amount_usdc * ETH)
    
    liq_x = liquidity_from_x(amount_eth_wei, sqrtp_cur, sqrtp_upp)
    liq_y = liquidity_from_y(amount_usdc_wei, sqrtp_low, sqrtp_cur)
    liquidity = int(min(liq_x, liq_y))
    
    if verbose:
        print(f"基于 ETH:  L = {int(liq_x)}")
        print(f"基于 USDC: L = {int(liq_y)}")
        print(f"选择较小值: L = {liquidity}")
    
    results['liquidity_from_eth'] = int(liq_x)
    results['liquidity_from_usdc'] = int(liq_y)
    results['liquidity'] = liquidity
    
    # 步骤 4: 计算精确代币数量
    if verbose:
        print_separator("步骤 4: 计算精确代币数量")
    
    amount_eth_final = calc_amount_x(liquidity, sqrtp_cur, sqrtp_upp)
    amount_usdc_final = calc_amount_y(liquidity, sqrtp_low, sqrtp_cur)
    
    if verbose:
        print(f"精确 ETH:  {amount_eth_final} wei")
        print(f"         = {format_wei(amount_eth_final):.18f} ETH")
        print(f"精确 USDC: {amount_usdc_final} wei")
        print(f"         = {format_wei(amount_usdc_final):.2f} USDC")
    
    results['amount_eth_final_wei'] = amount_eth_final
    results['amount_usdc_final_wei'] = amount_usdc_final
    results['amount_eth_final'] = format_wei(amount_eth_final)
    results['amount_usdc_final'] = format_wei(amount_usdc_final)
    
    # 计算差异
    if verbose:
        print_separator("代币数量对比")
        eth_diff = amount_eth - results['amount_eth_final']
        usdc_diff = amount_usdc - results['amount_usdc_final']
        print(f"ETH  预期: {amount_eth:.18f} | 精确: {results['amount_eth_final']:.18f} | 差异: {eth_diff:.18f}")
        print(f"USDC 预期: {amount_usdc:.2f} | 精确: {results['amount_usdc_final']:.2f} | 差异: {usdc_diff:.2f}")
    
    if verbose:
        print_separator("计算完成！")
    
    return results


# ============================================================
# 示例和测试
# ============================================================

def example_eth_usdc_pool():
    """
    示例：计算 ETH/USDC 池子的流动性参数
    这是文章中使用的标准示例
    """
    print("=" * 60)
    print("UniswapV3 流动性计算示例")
    print("交易对: ETH/USDC")
    print("=" * 60)
    
    # 池子配置
    price_current = 5000  # 当前价格: 5000 USDC/ETH
    price_lower = 4545    # 下限价格: 4545 USDC/ETH
    price_upper = 5500    # 上限价格: 5500 USDC/ETH
    
    # 提供的代币数量
    amount_eth = 1        # 1 ETH
    amount_usdc = 5000    # 5000 USDC
    
    # 执行计算
    results = calculate_liquidity(
        price_current=price_current,
        price_lower=price_lower,
        price_upper=price_upper,
        amount_eth=amount_eth,
        amount_usdc=amount_usdc,
        verbose=True
    )
    
    return results


def interactive_mode():
    """交互式模式，允许用户自定义参数"""
    print("\n" + "=" * 60)
    print("UniswapV3 流动性计算器 - 交互模式")
    print("=" * 60)
    
    try:
        price_current = float(input("\n请输入当前价格 (USDC/ETH): "))
        price_lower = float(input("请输入下限价格 (USDC/ETH): "))
        price_upper = float(input("请输入上限价格 (USDC/ETH): "))
        amount_eth = float(input("请输入 ETH 数量: "))
        amount_usdc = float(input("请输入 USDC 数量: "))
        
        # 验证输入
        if price_lower >= price_current or price_current >= price_upper:
            print("\n❌ 错误: 价格必须满足 下限 < 当前 < 上限")
            return None
        
        if amount_eth <= 0 or amount_usdc <= 0:
            print("\n❌ 错误: 代币数量必须大于 0")
            return None
        
        # 执行计算
        results = calculate_liquidity(
            price_current=price_current,
            price_lower=price_lower,
            price_upper=price_upper,
            amount_eth=amount_eth,
            amount_usdc=amount_usdc,
            verbose=True
        )
        
        return results
        
    except ValueError as e:
        print(f"\n❌ 输入错误: {e}")
        return None
    except KeyboardInterrupt:
        print("\n\n已取消")
        return None


# ============================================================
# 命令行接口
# ============================================================

def main():
    """主函数"""
    if len(sys.argv) > 1 and sys.argv[1] == '--interactive':
        # 交互模式
        interactive_mode()
    else:
        # 默认运行示例
        example_eth_usdc_pool()
        
        # 提示交互模式
        print("\n💡 提示: 使用 'python scripts/unimath.py --interactive' 进入交互模式")


if __name__ == "__main__":
    main()

