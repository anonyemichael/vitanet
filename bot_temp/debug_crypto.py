import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp

for symbol in ["BTCUSDm", "ETHUSDm"]:
    print("=" * 50)
    print("DEBUG: " + symbol)
    df_w  = dp.get_weekly(symbol)
    df_d  = dp.get_daily(symbol)
    df_4h = dp.get_4h(symbol)
    if df_4h is None or df_d is None or df_w is None:
        print("  NO DATA"); continue

    df_w  = strategy.add_indicators(df_w)
    df_d  = strategy.add_indicators(df_d)
    df_4h = strategy.add_indicators(df_4h)

    price = float(df_4h.iloc[-1]["close"])
    ema21 = float(df_4h.iloc[-1]["ema21"])
    eq_d  = strategy.get_equilibrium(df_d, n=100)
    zone  = "DISCOUNT" if price < eq_d else "PREMIUM"

    bias_4h = strategy.get_4h_bias(df_4h)
    bias_d  = strategy.get_daily_trend(df_d)
    bias_w  = strategy.get_weekly_bias(df_w)

    print("  Price:   " + str(round(price, 2)))
    print("  EMA21:   " + str(round(ema21, 2)) + " -> " + ("ABOVE" if price > ema21 else "BELOW"))
    print("  D1 EQ:   " + str(round(eq_d, 2)) + "  -> " + zone)
    print("  Bias  W=" + str(bias_w) + "  D=" + str(bias_d) + "  4H=" + str(bias_4h))

    aois = strategy.find_aoi_zones(df_d, symbol)
    sorted_aois = sorted(aois, key=lambda a: abs(a["mid"] - price))
    print("  Daily AOIs nearest 4:")
    for a in sorted_aois[:4]:
        dist = abs(a["mid"] - price) / price * 100
        in_r = price >= a["low"] and price <= a["high"]
        print("    " + str(round(a["mid"],2)) + " [" + str(round(a["low"],2)) + "-" + str(round(a["high"],2)) + "] T=" + str(a["touches"]) + " dist=" + str(round(dist,2)) + "% IN=" + str(in_r))
    in_aoi = strategy.price_in_aoi(price, aois)
    print("  price_in_aoi: " + str(in_aoi))
