#!/usr/bin/env python3

import math
from decimal import Decimal, getcontext

# 设置高精度
getcontext().prec = 50

def tick_to_price(tick):
    """将 tick 转换为价格"""
    return Decimal(1.0001) ** tick

def calculate_amounts_for_liquidity(sqrt_price_x96, tick_lower, tick_upper, liquidity):
    """计算给定流动性需要的代币数量"""
    
    # 当前价格
    current_price = (Decimal(sqrt_price_x96) / Decimal(2**96)) ** 2
    
    # 边界价格
    price_lower = tick_to_price(tick_lower)
    price_upper = tick_to_price(tick_upper)
    
    print(f"价格信息:")
    print(f"  当前价格: {current_price:.6f}")
    print(f"  下边界价格: {price_lower:.6f}")
    print(f"  上边界价格: {price_upper:.6f}")
    
    # 计算需要的代币数量
    if current_price <= price_lower:
        # 当前价格低于范围，只需要 token0 (WETH)
        amount0 = liquidity
        amount1 = 0
    elif current_price >= price_upper:
        # 当前价格高于范围，只需要 token1 (USDC)
        amount0 = 0
        amount1 = liquidity * Decimal(price_upper).sqrt()
    else:
        # 当前价格在范围内，需要两种代币
        sqrt_price = Decimal(sqrt_price_x96) / Decimal(2**96)
        sqrt_price_lower = price_lower.sqrt()
        sqrt_price_upper = price_upper.sqrt()
        
        amount0 = liquidity * (sqrt_price_upper - sqrt_price) / (sqrt_price * sqrt_price_upper)
        amount1 = liquidity * (sqrt_price - sqrt_price_lower)
    
    return amount0, amount1

def main():
    # 参数
    sqrt_price_x96 = 5602277097478614198912276234240
    tick_lower = 84222
    tick_upper = 86129
    liquidity = 1527882343751509868544
    
    print(f"计算流动性 {liquidity} 需要的代币数量:")
    
    amount0, amount1 = calculate_amounts_for_liquidity(
        sqrt_price_x96, tick_lower, tick_upper, liquidity
    )
    
    print(f"\n需要的代币数量:")
    print(f"  WETH (amount0): {amount0:.18f}")
    print(f"  USDC (amount1): {amount1:.18f}")
    
    # 检查是否超过用户余额
    user_weth = Decimal("1.0")
    user_usdc = Decimal("5042.0")
    
    print(f"\n用户余额:")
    print(f"  WETH: {user_weth}")
    print(f"  USDC: {user_usdc}")
    
    print(f"\n检查:")
    if amount0 > user_weth:
        print(f"❌ WETH 不足: 需要 {amount0:.6f}, 只有 {user_weth}")
    else:
        print(f"✅ WETH 充足")
        
    if amount1 > user_usdc:
        print(f"❌ USDC 不足: 需要 {amount1:.6f}, 只有 {user_usdc}")
    else:
        print(f"✅ USDC 充足")
    
    # 建议合适的流动性数量
    print(f"\n建议:")
    if amount0 > user_weth or amount1 > user_usdc:
        # 计算最大可能的流动性
        max_liquidity_by_weth = user_weth / (amount0 / Decimal(liquidity)) if amount0 > 0 else Decimal('inf')
        max_liquidity_by_usdc = user_usdc / (amount1 / Decimal(liquidity)) if amount1 > 0 else Decimal('inf')
        
        max_liquidity = min(max_liquidity_by_weth, max_liquidity_by_usdc)
        
        print(f"  建议使用流动性: {int(max_liquidity)}")
        print(f"  这将需要:")
        
        new_amount0, new_amount1 = calculate_amounts_for_liquidity(
            sqrt_price_x96, tick_lower, tick_upper, int(max_liquidity)
        )
        print(f"    WETH: {new_amount0:.6f}")
        print(f"    USDC: {new_amount1:.6f}")

if __name__ == "__main__":
    main()
