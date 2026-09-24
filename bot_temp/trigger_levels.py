import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp, config

for symbol in config.SYMBOLS:
    df_w  = dp.get_weekly(symbol)
    df_d  = dp.get_daily(symbol)
    df_4h = dp.get_4h(symbol)
    if df_w is None or df_d is None or df_4h is None:
        continue

    df_4h2 = strategy.add_indicators(df_4h)
    df_d2  = strategy.add_indicators(df_d)
    df_w2  = strategy.add_indicators(df_w)

    price  = float(df_4h2.iloc[-1]["close"])
    ema21  = float(df_4h2.iloc[-1]["ema21"])
    eq_d   = strategy.get_equilibrium(df_d2, n=100)
    zone   = "DISCOUNT" if price < eq_d else "PREMIUM"
    bias_4h = strategy.get_4h_bias(df_4h2)

    # Get last 10 4H candles highs/lows to find swing levels
    highs = [float(df_4h2.iloc[i]["high"]) for i in range(-10, 0)]
    lows  = [float(df_4h2.iloc[i]["low"])  for i in range(-10, 0)]

    # For discount (need bullish): need price to break above recent swing high (HH)
    # For premium (need bearish): need price to break below recent swing low (LL)
    recent_swing_high = max(highs[-6:])  # last 6 candles = ~24H
    recent_swing_low  = min(lows[-6:])

    # How far is EMA21 from price
    ema_gap_pct = abs(price - ema21) / price * 100

    aois = strategy.find_aoi_zones(df_d2, symbol)
    in_aoi = strategy.price_in_aoi(price, aois)

    print(symbol + ":")
    print("  Price=" + str(round(price,4)) + "  Zone=" + zone + "  4H_bias=" + str(bias_4h))
    print("  EMA21=" + str(round(ema21,4)) + "  gap=" + str(round(ema_gap_pct,2)) + "%")
    if zone == "DISCOUNT":
        print("  Need: 4H HH above " + str(round(recent_swing_high,4)) + " + price reclaim EMA21")
        print("  EMA21 target: " + str(round(ema21,4)) + "  (+$" + str(round(abs(ema21-price),4)) + ")")
    else:
        print("  Need: 4H LL below " + str(round(recent_swing_low,4)) + " + price stay below EMA21")
        print("  EMA21 already " + ("above price — short-side OK" if price < ema21 else "below price — need drop"))
    print()
