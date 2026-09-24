import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp, config

for symbol in config.SYMBOLS:
    df_w  = dp.get_weekly(symbol)
    df_d  = dp.get_daily(symbol)
    df_4h = dp.get_4h(symbol)
    if df_4h is None or df_d is None: continue

    df_4h2 = strategy.add_indicators(df_4h)
    df_d2  = strategy.add_indicators(df_d)

    price = float(df_4h2.iloc[-2]["close"])
    eq_d  = strategy.get_equilibrium(df_d2, n=100)
    zone  = "DISCOUNT" if price < eq_d else "PREMIUM"

    direction = "bullish" if zone == "DISCOUNT" else "bearish"

    aois = strategy.find_aoi_zones(df_d2, symbol)
    in_aoi = strategy.price_in_aoi(price, aois)

    eng = strategy.check_engulfing(df_4h2, direction)

    # Show last 3 4H candles
    c1 = df_4h2.iloc[-3]
    c2 = df_4h2.iloc[-2]
    c3 = df_4h2.iloc[-1]

    print(symbol + " [" + direction.upper() + " | " + zone + "]")
    print("  AOI: " + ("YES mid=" + str(round(in_aoi["mid"],4)) if in_aoi else "NO"))
    print("  Engulfing: " + str(eng))
    print("  4H candles (open/close):")
    print("    -2: o=" + str(round(float(c1["open"]),4)) + " c=" + str(round(float(c1["close"]),4)) + " " + ("BULL" if float(c1["close"])>float(c1["open"]) else "BEAR"))
    print("    -1: o=" + str(round(float(c2["open"]),4)) + " c=" + str(round(float(c2["close"]),4)) + " " + ("BULL" if float(c2["close"])>float(c2["open"]) else "BEAR") + " <- scored candle")
    print("    0:  o=" + str(round(float(c3["open"]),4)) + " c=" + str(round(float(c3["close"]),4)) + " " + ("BULL" if float(c3["close"])>float(c3["open"]) else "BEAR") + " <- live")
    print()
