#!/usr/bin/env python3
"""
UniswapV3 数学计算工具测试
验证核心计算功能的正确性
"""

import sys
from unimath import (
    price_to_tick,
    tick_to_price,
    price_to_sqrtp_q96,
    liquidity_from_x,
    liquidity_from_y,
    calc_amount_x,
    calc_amount_y,
    calculate_liquidity,
    Q96,
    ETH
)


def test_price_to_tick():
    """测试价格到 Tick 的转换"""
    print("测试: price_to_tick")
    
    # 测试用例
    tests = [
        (5000, 85176),
        (4545, 84222),
        (5500, 86129),
        (1, 0),
    ]
    
    for price, expected_tick in tests:
        tick = price_to_tick(price)
        assert tick == expected_tick, f"价格 {price} -> Tick {tick}，期望 {expected_tick}"
        print(f"  ✅ 价格 {price} -> Tick {tick}")
    
    print("  通过！\n")


def test_tick_to_price():
    """测试 Tick 到价格的转换"""
    print("测试: tick_to_price")
    
    # 测试基本转换
    tick = 85176
    price = tick_to_price(tick)
    
    # 验证往返转换
    tick_back = price_to_tick(price)
    assert tick_back == tick, f"往返转换失败: {tick} -> {price} -> {tick_back}"
    
    print(f"  ✅ Tick {tick} -> 价格 {price:.2f} -> Tick {tick_back}")
    print("  通过！\n")


def test_price_to_sqrtp_q96():
    """测试价格到 Q64.96 平方根价格的转换"""
    print("测试: price_to_sqrtp_q96")
    
    price = 5000
    sqrtp_q96 = price_to_sqrtp_q96(price)
    
    # 验证结果是正整数
    assert isinstance(sqrtp_q96, int), "结果应该是整数"
    assert sqrtp_q96 > 0, "结果应该是正数"
    
    # 验证大致正确（sqrt(5000) ≈ 70.71）
    expected_approx = int(70.71 * Q96)
    diff = abs(sqrtp_q96 - expected_approx)
    assert diff < Q96, f"Q64.96 转换结果偏差过大"
    
    print(f"  ✅ 价格 {price} -> sqrtP(Q96) {sqrtp_q96}")
    print("  通过！\n")


def test_liquidity_calculation():
    """测试流动性计算的完整流程"""
    print("测试: 流动性计算完整流程")
    
    # 使用标准示例
    price_current = 5000
    price_lower = 4545
    price_upper = 5500
    amount_eth = 1
    amount_usdc = 5000
    
    results = calculate_liquidity(
        price_current=price_current,
        price_lower=price_lower,
        price_upper=price_upper,
        amount_eth=amount_eth,
        amount_usdc=amount_usdc,
        verbose=False
    )
    
    # 验证关键结果
    assert results['tick_current'] == 85176, "当前 Tick 不正确"
    assert results['tick_lower'] == 84222, "下限 Tick 不正确"
    assert results['tick_upper'] == 86129, "上限 Tick 不正确"
    
    # 验证流动性计算
    assert results['liquidity'] > 0, "流动性应该大于 0"
    assert results['liquidity'] == min(
        results['liquidity_from_eth'],
        results['liquidity_from_usdc']
    ), "应该选择较小的流动性"
    
    # 验证精确数量
    assert results['amount_eth_final'] > 0, "精确 ETH 数量应该大于 0"
    assert results['amount_usdc_final'] > 0, "精确 USDC 数量应该大于 0"
    
    # ETH 应该略小于输入（因为选择了较小的 L）
    assert results['amount_eth_final'] <= amount_eth, "精确 ETH 不应超过输入"
    
    # USDC 应该等于输入（它决定了较小的 L）
    assert abs(results['amount_usdc_final'] - amount_usdc) < 0.01, "精确 USDC 应该接近输入"
    
    print(f"  ✅ Tick 计算: {results['tick_lower']} -> {results['tick_current']} -> {results['tick_upper']}")
    print(f"  ✅ 流动性 L: {results['liquidity']}")
    print(f"  ✅ 精确 ETH: {results['amount_eth_final']:.18f}")
    print(f"  ✅ 精确 USDC: {results['amount_usdc_final']:.2f}")
    print("  通过！\n")


def test_amount_calculation_roundtrip():
    """测试代币数量的往返计算"""
    print("测试: 代币数量往返计算")
    
    # 设置初始参数
    sqrtp_low = price_to_sqrtp_q96(4545)
    sqrtp_cur = price_to_sqrtp_q96(5000)
    sqrtp_upp = price_to_sqrtp_q96(5500)
    
    # 从数量计算流动性
    amount_eth_wei = 1 * ETH
    amount_usdc_wei = 5000 * ETH
    
    liq_x = liquidity_from_x(amount_eth_wei, sqrtp_cur, sqrtp_upp)
    liq_y = liquidity_from_y(amount_usdc_wei, sqrtp_low, sqrtp_cur)
    liquidity = int(min(liq_x, liq_y))
    
    # 从流动性计算回数量
    amount_eth_back = calc_amount_x(liquidity, sqrtp_cur, sqrtp_upp)
    amount_usdc_back = calc_amount_y(liquidity, sqrtp_low, sqrtp_cur)
    
    # 验证 USDC 应该完全匹配（因为它决定了流动性）
    assert amount_usdc_back == amount_usdc_wei, "USDC 往返计算应该完全匹配"
    
    # 验证 ETH 应该接近但略小于原值
    eth_diff = amount_eth_wei - amount_eth_back
    assert 0 <= eth_diff < amount_eth_wei * 0.01, "ETH 往返计算偏差过大"
    
    print(f"  ✅ ETH:  {amount_eth_wei} -> L -> {amount_eth_back} (差异: {eth_diff})")
    print(f"  ✅ USDC: {amount_usdc_wei} -> L -> {amount_usdc_back} (差异: 0)")
    print("  通过！\n")


def test_edge_cases():
    """测试边界情况"""
    print("测试: 边界情况")
    
    # 测试极小价格差
    try:
        results = calculate_liquidity(
            price_current=5000,
            price_lower=4999,
            price_upper=5001,
            amount_eth=1,
            amount_usdc=5000,
            verbose=False
        )
        print(f"  ✅ 窄价格区间: L = {results['liquidity']}")
    except Exception as e:
        print(f"  ❌ 窄价格区间测试失败: {e}")
        return False
    
    # 测试大价格差
    try:
        results = calculate_liquidity(
            price_current=5000,
            price_lower=1000,
            price_upper=10000,
            amount_eth=1,
            amount_usdc=5000,
            verbose=False
        )
        print(f"  ✅ 宽价格区间: L = {results['liquidity']}")
    except Exception as e:
        print(f"  ❌ 宽价格区间测试失败: {e}")
        return False
    
    print("  通过！\n")


def run_all_tests():
    """运行所有测试"""
    print("=" * 60)
    print("UniswapV3 数学计算工具 - 测试套件")
    print("=" * 60)
    print()
    
    tests = [
        test_price_to_tick,
        test_tick_to_price,
        test_price_to_sqrtp_q96,
        test_liquidity_calculation,
        test_amount_calculation_roundtrip,
        test_edge_cases,
    ]
    
    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"  ❌ 测试失败: {e}\n")
            failed += 1
        except Exception as e:
            print(f"  ❌ 测试出错: {e}\n")
            failed += 1
    
    print("=" * 60)
    if failed == 0:
        print("✅ 所有测试通过！")
    else:
        print(f"❌ {failed} 个测试失败")
    print("=" * 60)
    
    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)

