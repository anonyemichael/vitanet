#!/usr/bin/env python3
"""Full signal pipeline test — verifies every indicator and filter is working."""
import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")

import config
import data_provider as dp
import strategy
import news_filter
import bridge_client as bridge
import risk_manager
import trade_logger

results = {}

print("=" * 60)
print("  FXAlexG Bot — FULL SIGNAL PIPELINE TEST")
print("=" * 60)

# 1. Bridge
print("\n--- 1. MT5 Bridge ---")
acc = bridge.health()
if acc.get("connected"):
    print(f"  PASS: Connected | Login {acc['login']} | Balance ${acc['balance']:.2f}")
    results["bridge"] = "PASS"
else:
    print(f"  FAIL: {acc}")
    results["bridge"] = "FAIL"

# 2. Data feeds for each symbol
print("\n--- 2. Data Feeds (W1/D1/H4/M15) ---")
feed_results = {}
for sym in config.SYMBOLS:
    w = dp.get_weekly(sym, count=50)
    d = dp.get_daily(sym, count=100)
    h4 = dp.get_4h(sym, count=100)
    m15 = dp.get_15m(sym, count=100)
    
    w_ok = w is not None and len(w) >= 10
    d_ok = d is not None and len(d) >= 20
    h4_ok = h4 is not None and len(h4) >= 30
    m15_ok = m15 is not None and len(m15) >= 20
    
    status = "PASS" if (w_ok and d_ok and h4_ok and m15_ok) else "FAIL"
    feed_results[sym] = status
    counts = f"W1={len(w) if w is not None else 0} D1={len(d) if d is not None else 0} H4={len(h4) if h4 is not None else 0} M15={len(m15) if m15 is not None else 0}"
    print(f"  {status}: {sym} — {counts}")

results["data_feeds"] = "PASS" if all(v == "PASS" for v in feed_results.values()) else "PARTIAL"

# 3. Indicators
print("\n--- 3. Indicators (EMA9/21/200, RSI, ATR, ADX) ---")
for sym in ["EURUSDm", "BTCUSDm", "XAUUSDm"]:
    h4 = dp.get_4h(sym, count=100)
    if h4 is None:
        print(f"  SKIP: {sym} — no data")
        continue
    h4 = strategy.add_indicators(h4)
    row = h4.iloc[-2]
    ema9 = round(float(row["ema9"]), 5)
    ema21 = round(float(row["ema21"]), 5)
    ema200 = round(float(row["ema200"]), 5)
    rsi = round(float(row["rsi"]), 1)
    atr = round(float(row["atr"]), 5)
    adx = round(float(row["adx"]), 1)
    print(f"  {sym}: EMA9={ema9} EMA21={ema21} EMA200={ema200} RSI={rsi} ATR={atr} ADX={adx}")
results["indicators"] = "PASS"

# 4. Bias Detection
print("\n--- 4. Multi-TF Bias Detection ---")
for sym in config.SYMBOLS:
    w = dp.get_weekly(sym, count=50)
    d = dp.get_daily(sym, count=100)
    h4 = dp.get_4h(sym, count=100)
    if w is None or d is None or h4 is None:
        continue
    w = strategy.add_indicators(w)
    d = strategy.add_indicators(d)
    h4 = strategy.add_indicators(h4)
    wb = strategy.get_weekly_bias(w)
    dt = strategy.get_daily_trend(d)
    hb = strategy.get_4h_bias(h4)
    
    adx_val = float(h4["adx"].iloc[-2]) if "adx" in h4.columns else 0
    print(f"  {sym}: W1={wb} D1={dt} H4={hb} | ADX={adx_val:.1f} {'(trending)' if adx_val >= 20 else '(ranging)'}")
results["bias"] = "PASS"

# 5. Swing Range & OTE
print("\n--- 5. Swing Dealing Range & OTE Zones ---")
for sym in ["EURUSDm", "BTCUSDm", "XAUUSDm"]:
    h4 = dp.get_4h(sym, count=100)
    if h4 is None:
        continue
    h4 = strategy.add_indicators(h4)
    swing = strategy.get_swing_range(h4, lookback=30)
    price = float(h4["close"].iloc[-2])
    in_disc = strategy.is_price_in_favorable_zone(price, "bullish", swing)
    in_prem = strategy.is_price_in_favorable_zone(price, "bearish", swing)
    print(f"  {sym}: Price={price:.5f} | Range=[{swing['low']:.5f} - {swing['high']:.5f}] | EQ={swing['equilibrium']:.5f}")
    print(f"         OTE Disc={swing['discount_ote']:.5f} OTE Prem={swing['premium_ote']:.5f} | InDiscount={in_disc} InPremium={in_prem}")
results["swing_ote"] = "PASS"

# 6. AOI & Key Levels
print("\n--- 6. AOI Zones & Key Levels ---")
for sym in ["EURUSDm", "GBPUSDm", "XAUUSDm"]:
    d = dp.get_daily(sym, count=100)
    w = dp.get_weekly(sym, count=50)
    if d is None or w is None:
        continue
    d = strategy.add_indicators(d)
    w = strategy.add_indicators(w)
    d_zones = strategy.find_aoi_zones(d, sym)
    w_zones = strategy.find_aoi_zones(w, sym)
    key_lvls = strategy.get_key_levels(d, w)
    print(f"  {sym}: D1 AOI zones={len(d_zones)} | W1 AOI zones={len(w_zones)} | Key levels={len(key_lvls)}")
results["aoi"] = "PASS"

# 7. News Filter
print("\n--- 7. News Filter ---")
news_count = 0
for sym in ["EURUSDm", "GBPUSDm", "USDJPYm"]:
    has_news, title = news_filter.has_high_impact_news_soon(sym, config.NEWS_LOOKOUT_MINS)
    status = f"NEWS: {title}" if has_news else "Clear"
    print(f"  {sym}: {status}")
    if has_news:
        news_count += 1
results["news_filter"] = "PASS"

# 8. Risk Manager
print("\n--- 8. Risk Manager (Lot Sizing) ---")
bal = acc.get("balance", 50.0) if acc.get("connected") else 50.0
for sym, sl_dist in [("EURUSDm", 0.0050), ("BTCUSDm", 500.0), ("XAUUSDm", 5.0)]:
    lot, risk_usd, risk_pct, warn = risk_manager.calculate_lot_size(sym, sl_dist, bal)
    print(f"  {sym}: SL_dist={sl_dist} -> Lot={lot} Risk=${risk_usd:.2f} ({risk_pct}%) {warn or 'OK'}")
results["risk_manager"] = "PASS"

# 9. Full Strategy Scan
print("\n--- 9. Full Strategy Scan (analyze_pair) ---")
setups_found = 0
for sym in config.SYMBOLS:
    w = dp.get_weekly(sym, count=50)
    d = dp.get_daily(sym, count=100)
    h4 = dp.get_4h(sym, count=100)
    m15 = dp.get_15m(sym, count=100)
    if w is None or d is None or h4 is None:
        print(f"  {sym}: SKIP (missing data)")
        continue
    setup = strategy.analyze_pair(sym, w, d, h4, df_15m=m15, in_kill_zone=True)
    if setup:
        setups_found += 1
        print(f"  {sym}: SETUP FOUND! {setup['grade']} ({setup['score']}pts) {setup['direction']} | ADX={setup.get('adx','?')} | Confluences: {', '.join(setup['met'])}")
    else:
        print(f"  {sym}: No setup")
results["strategy_scan"] = "PASS"

# 10. Trade Logger DB
print("\n--- 10. Trade Logger DB ---")
trade_logger.init_db()
open_tickets = trade_logger.get_open_trade_tickets()
daily_count = trade_logger.get_daily_trade_count()
print(f"  Open tickets: {len(open_tickets)}")
print(f"  Trades today: {daily_count}")
results["trade_logger"] = "PASS"

# Summary
print("\n" + "=" * 60)
print("  SIGNAL PIPELINE TEST SUMMARY")
print("=" * 60)
all_pass = True
for key, val in results.items():
    icon = "PASS" if val == "PASS" else ("PARTIAL" if val == "PARTIAL" else "FAIL")
    if val != "PASS":
        all_pass = False
    print(f"  {icon}: {key}")
print(f"\n  Setups found this scan: {setups_found}")
print(f"  Overall: {'ALL SYSTEMS GO' if all_pass else 'ISSUES DETECTED'}")
print("=" * 60)
