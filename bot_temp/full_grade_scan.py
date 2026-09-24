import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp, config

for symbol in config.SYMBOLS:
    print("=" * 55)
    print("PAIR: " + symbol)
    df_w  = dp.get_weekly(symbol)
    df_d  = dp.get_daily(symbol)
    df_4h = dp.get_4h(symbol)
    df_15m = dp.get_15m(symbol)
    if df_w is None or df_d is None or df_4h is None:
        print("  NO DATA"); continue

    df_w2  = strategy.add_indicators(df_w)
    df_d2  = strategy.add_indicators(df_d)
    df_4h2 = strategy.add_indicators(df_4h)

    price   = float(df_4h2.iloc[-1]["close"])
    ema21   = float(df_4h2.iloc[-1]["ema21"])
    eq_d    = strategy.get_equilibrium(df_d2, n=100)
    zone    = "DISCOUNT" if price < eq_d else "PREMIUM"

    bias_4h = strategy.get_4h_bias(df_4h2)
    bias_d  = strategy.get_daily_trend(df_d2)
    bias_w  = strategy.get_weekly_bias(df_w2)

    aois    = strategy.find_aoi_zones(df_d2, symbol)
    in_aoi  = strategy.price_in_aoi(price, aois)
    klevels = strategy.get_key_levels(df_d2, df_w2)

    # Determine possible directions
    directions = []
    if zone == "DISCOUNT": directions.append("bullish")
    if zone == "PREMIUM":  directions.append("bearish")

    print("  Price=" + str(round(price,5)) + "  Zone=" + zone)
    print("  Bias W=" + str(bias_w) + " D=" + str(bias_d) + " 4H=" + str(bias_4h))
    print("  EMA21=" + str(round(ema21,4)) + "  Price " + ("ABOVE" if price>ema21 else "BELOW"))
    print("  In daily AOI: " + ("YES mid=" + str(round(in_aoi["mid"],4)) if in_aoi else "NO (nearest " + str(round(sorted(aois,key=lambda a:abs(a["mid"]-price))[0]["mid"],4) if aois else "n/a") + ")"))

    for direction in directions:
        print("  --- " + direction.upper() + " scenario ---")
        crit1 = bias_4h == direction
        crit2 = in_aoi is not None
        if direction == "bullish":
            crit3 = price > ema21
        else:
            crit3 = price < ema21
        print("    C1 4H bias match:  " + str(crit1))
        print("    C2 At daily AOI:   " + str(crit2))
        print("    C3 EMA21 side:     " + str(crit3))
        missing = []
        if not crit1: missing.append("4H bias")
        if not crit2: missing.append("AOI")
        if not crit3: missing.append("EMA21")
        if missing:
            print("    MISSING: " + ", ".join(missing))
        else:
            print("    *** ALL CRITICALS MET — needs trigger ***")
