import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp, risk_manager, config

# Simulate on $500 balance (intended demo size)
balance = 500.0
print("Projected P&L on $500 balance | Lot=" + str(config.FIXED_LOT) + " | RR 1:3")
print("-" * 55)

setups = [
    ("GBPJPYm", "bearish"),
    ("EURUSDm", "bullish"),
    ("GBPUSDm", "bullish"),
    ("USDJPYm", "bearish"),
    ("XAUUSDm", "bullish"),
]

for symbol, direction in setups:
    df_4h = dp.get_4h(symbol)
    if df_4h is None: continue
    df_4h2 = strategy.add_indicators(df_4h)
    price = float(df_4h2.iloc[-1]["close"])

    if direction == "bullish":
        swing_low = min(float(df_4h2.iloc[i]["low"]) for i in range(-6,0))
        sl = swing_low * (1 - 0.002)
        sl_dist = price - sl
        tp = price + sl_dist * config.MIN_RR
    else:
        swing_high = max(float(df_4h2.iloc[i]["high"]) for i in range(-6,0))
        sl = swing_high * (1 + 0.002)
        sl_dist = sl - price
        tp = price - sl_dist * config.MIN_RR

    lot, risk_usd, risk_pct, warn = risk_manager.calculate_lot_size(symbol, sl_dist, balance)
    profit = round(risk_usd * config.MIN_RR, 2)

    print(symbol + " " + direction.upper())
    print("  Lot=" + str(lot) + "  Risk=$" + str(round(risk_usd,2)) + " (" + str(risk_pct) + "%)  PROFIT=$" + str(profit))
    print("  SL=" + str(round(sl,4)) + "  TP=" + str(round(tp,4)))
    print()
