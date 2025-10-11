#!/usr/bin/env python3
"""
价格和 Tick 对应关系演示脚本

这个脚本演示了 UniswapV3 中价格（price）和 tick 之间的数学关系。
核心公式：price = 1.0001^tick
"""

import math

def price_to_tick(price):
    """从价格计算 tick（向下取整）"""
    return math.floor(math.log(price) / math.log(1.0001))

def tick_to_price(tick):
    """从 tick 计算价格"""
    return 1.0001 ** tick

def main():
    print("=" * 70)
    print("UniswapV3 价格和 Tick 对应关系演示")
    print("=" * 70)
    
    # ===== 示例 1: 从价格计算 tick =====
    print("\n【示例 1】从价格计算 tick")
    print("-" * 70)
    
    prices = [5000.0, 5003.913912782393, 5004.414]
    for price in prices:
        tick_float = math.log(price) / math.log(1.0001)
        tick = price_to_tick(price)
        print(f"价格: {price:>15.6f} USDC/ETH")
        print(f"  → tick (浮点): {tick_float:.6f}")
        print(f"  → tick (整数): {tick}")
        print()
    
    # ===== 示例 2: 从 tick 计算价格 =====
    print("\n【示例 2】从 tick 计算价格")
    print("-" * 70)
    
    ticks = [85176, 85177, 85178, 85184, 85185]
    prev_price = None
    for tick in ticks:
        price = tick_to_price(tick)
        if prev_price:
            change = (price - prev_price) / prev_price * 100
            print(f"Tick {tick:>6d} → 价格: {price:>15.6f} USDC/ETH (变化: +{change:.4f}%)")
        else:
            print(f"Tick {tick:>6d} → 价格: {price:>15.6f} USDC/ETH")
        prev_price = price
    
    # ===== 示例 3: 交换过程演示 =====
    print("\n【示例 3】交换过程中的价格和 tick 变化")
    print("-" * 70)
    
    print("\n初始状态:")
    current_tick = 85176
    current_price = tick_to_price(current_tick)
    print(f"  Tick: {current_tick}")
    print(f"  价格: {current_price:.6f} USDC/ETH")
    
    print("\n交换 42 USDC 购买 ETH 后:")
    
    # 使用文章中的计算结果
    eth = 10**18
    q96 = 2**96
    sqrtp_cur = 5602277097478614198912276234240
    liq = 1517882343751509868544
    amount_in = 42 * eth
    
    price_diff = (amount_in * q96) // liq
    price_next = sqrtp_cur + price_diff
    new_price = (price_next / q96) ** 2
    new_tick = price_to_tick(new_price)
    
    print(f"  新价格: {new_price:.10f} USDC/ETH")
    print(f"  新 tick (计算): {math.log(new_price) / math.log(1.0001):.6f}")
    print(f"  新 tick (取整): {new_tick}")
    print(f"  验证价格: {tick_to_price(new_tick):.10f} USDC/ETH")
    
    price_change = (new_price - current_price) / current_price * 100
    print(f"\n  价格变化: {current_price:.6f} → {new_price:.6f} (+{price_change:.4f}%)")
    print(f"  Tick 变化: {current_tick} → {new_tick} (+{new_tick - current_tick})")
    
    # ===== 示例 4: 为什么是 1.0001？ =====
    print("\n【示例 4】为什么选择 1.0001？")
    print("-" * 70)
    
    print("\n每个 tick 的价格变化:")
    base_price = 5000.0
    base_tick = price_to_tick(base_price)
    
    for i in range(5):
        tick = base_tick + i
        price = tick_to_price(tick)
        if i > 0:
            prev_price = tick_to_price(tick - 1)
            change_pct = (price - prev_price) / prev_price * 100
            change_abs = price - prev_price
            print(f"  Tick {tick}: {price:.6f} USDC/ETH (+{change_abs:.6f}, +{change_pct:.4f}%)")
        else:
            print(f"  Tick {tick}: {price:.6f} USDC/ETH (基准)")
    
    print(f"\n结论: 每个 tick 之间价格变化约 0.01% = (1.0001 - 1) * 100%")
    
    # ===== 示例 5: 价格范围覆盖 =====
    print("\n【示例 5】Tick 可以覆盖的价格范围")
    print("-" * 70)
    
    print("\nTick 的有效范围: [-887272, 887272]")
    
    min_tick = -887272
    max_tick = 887272
    min_price = tick_to_price(min_tick)
    max_price = tick_to_price(max_tick)
    
    print(f"\n  最小 tick {min_tick:>7d} → 价格: {min_price:.20e}")
    print(f"  最大 tick {max_tick:>7d} → 价格: {max_price:.20e}")
    print(f"\n  价格范围跨度: {max_price / min_price:.2e} 倍")
    print(f"  可以表示从极小到极大的价格！")
    
    # ===== 示例 6: Tick Spacing =====
    print("\n【示例 6】Tick Spacing 的概念")
    print("-" * 70)
    
    print("\n不同费率的池子有不同的 tick spacing:")
    print("  • 0.05% 费率 → tick spacing = 10")
    print("  • 0.30% 费率 → tick spacing = 60")
    print("  • 1.00% 费率 → tick spacing = 200")
    
    print("\n0.30% 费率池子的有效 tick 示例:")
    base_tick = 85140  # 必须是 60 的倍数
    for i in range(5):
        tick = base_tick + i * 60
        price = tick_to_price(tick)
        print(f"  Tick {tick:>6d} → 价格: {price:>10.4f} USDC/ETH")
    
    print("\n注意:")
    print("  • 流动性只能添加在 spacing 的整数倍 tick 上")
    print("  • 但交换可以在任意 tick 进行")
    print("  • 文章中的 tick 85184 不是 60 的倍数，所以不能在此添加流动性")
    print("  • 但交换可以把价格推到 tick 85184")
    
    print("\n" + "=" * 70)
    print("演示完成！")
    print("=" * 70)

if __name__ == "__main__":
    main()

