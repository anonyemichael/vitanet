import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp, risk_manager, bridge_client as bridge, config

acc = bridge.get_account()
balance = acc.get("balance", 0) if acc else 0
print("Account balance: $" + str(round(balance, 2)))
print("Fixed lot: " + str(config.FIXED_LOT) + " | RR: 1:" + str(int(config.MIN_RR)))
print()

# Closest setups: GBPJPY short, EURUSD long, GBPUSD long
setups_to_check = [
    ("GBPJPYm", "bearish"),
    ("EURUSDm", "bullish"),
    ("GBPUSDm", "bullish"),
    ("USDJPYm", "bearish"),
    ("XAUUSDm", "bullish"),
]

for symbol, direction in setups_to_check:
    df_4h = dp.get_4h(symbol)
    df_d  = dp.get_daily(symbol)
    if df_4h is None: continue
    df_4h2 = strategy.add_indicators(df_4h)

    price = float(df_4h2.iloc[-1]["close"])
    # SL = 0.2% beyond swing wick
    if direction == "bullish":
        swing_low = min(float(df_4h2.iloc[i]["low"]) for i in range(-6,0))
        sl = round(swing_low * (1 - 0.002), 5)
        sl_dist = price - sl
        tp = round(price + sl_dist * config.MIN_RR, 5)
    else:
        swing_high = max(float(df_4h2.iloc[i]["high"]) for i in range(-6,0))
        sl = round(swing_high * (1 + 0.002), 5)
        sl_dist = sl - price
        tp = round(price - sl_dist * config.MIN_RR, 5)

    lot, risk_usd, risk_pct, warn = risk_manager.calculate_lot_size(symbol, sl_dist, balance)
    profit_usd = round(risk_usd * config.MIN_RR, 2)

    rr_actual = round(sl_dist * config.MIN_RR / sl_dist, 1)

    print(symbol + " " + direction.upper() + ":")
    print("  Entry:  " + str(round(price, 5)))
    print("  SL:     " + str(sl) + "  (dist=" + str(round(sl_dist, 5)) + ")")
    print("  TP:     " + str(tp) + "  (1:" + str(int(config.MIN_RR)) + "R)")
    print("  Lot:    " + str(lot))
    print("  Risk:   $" + str(round(risk_usd, 2)) + " (" + str(risk_pct) + "% of balance)")
    print("  PROFIT: $" + str(profit_usd) + " if TP hit")
    if warn: print("  WARN: " + str(warn))
    print()
