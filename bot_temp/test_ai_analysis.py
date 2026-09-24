import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")

import data_provider as dp
import strategy
import bridge_client as bridge
import ai_engine

symbol = "EURUSDm"
df_w = dp.get_weekly(symbol, count=30)
df_d = dp.get_daily(symbol, count=50)
df_4h = dp.get_4h(symbol, count=50)

df_w = strategy.add_indicators(df_w)
df_d = strategy.add_indicators(df_d)
df_4h = strategy.add_indicators(df_4h)

price = float(df_4h["close"].iloc[-1])
w_bias = strategy.get_weekly_bias(df_w)
d_trend = strategy.get_daily_trend(df_d)
h4_bias = strategy.get_4h_bias(df_4h)
row_4h = df_4h.iloc[-1]
rsi = round(float(row_4h["rsi"]), 1)
adx = round(float(row_4h["adx"]), 1) if "adx" in row_4h else "N/A"
h4_ema21 = round(float(row_4h["ema21"]), 5)

swing = strategy.get_swing_range(df_4h, lookback=30)
zones = strategy.find_aoi_zones(df_d, symbol)
nearest = min(zones, key=lambda z: abs(z["mid"] - price)) if zones else None
zone_pos = "Discount (Bullish territory)" if price < swing["equilibrium"] else "Premium (Bearish territory)"
spread = bridge.get_symbol_info(symbol).get("spread", "N/A") if bridge.is_online() else "N/A"

tf_data = {
    "price": price,
    "w_bias": w_bias,
    "d_trend": d_trend,
    "d_ema200_side": "Above EMA200" if price > float(df_d["ema200"].iloc[-1]) else "Below EMA200",
    "h4_bias": h4_bias,
    "h4_ema21": h4_ema21,
    "adx": adx,
    "rsi": rsi,
    "swing_low": round(swing["low"], 5),
    "swing_high": round(swing["high"], 5),
    "equilibrium": round(swing["equilibrium"], 5),
    "zone_position": zone_pos,
    "nearest_aoi": round(nearest["mid"], 5) if nearest else "None",
    "spread": spread
}

print("Running AI Deep Analysis on EURUSDm...")
report = ai_engine.analyze_market_pair(symbol, tf_data)
print("\n" + "="*50)
print(report)
print("="*50)
