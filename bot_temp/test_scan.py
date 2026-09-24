import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import strategy, data_provider as dp, config, risk_manager
import bridge_client as bridge
from datetime import datetime, timezone

def ts():
    return datetime.now(timezone.utc).strftime("%H:%M UTC")

print("=== TEST SCAN ===")
acc = bridge.get_account()
balance = acc.get("balance", 500.0) if acc else 500.0
print("Balance: $" + str(round(balance, 2)))
print("")

for symbol in config.SYMBOLS:
    print("[" + ts() + "] " + symbol + "...")
    df_w  = dp.get_weekly(symbol)
    df_d  = dp.get_daily(symbol)
    df_4h = dp.get_4h(symbol)
    df_15m = dp.get_15m(symbol)
    if df_w is None or df_d is None or df_4h is None:
        print("  NO DATA")
        continue
    setup = strategy.analyze_pair(symbol, df_w, df_d, df_4h, df_15m=df_15m, in_kill_zone=True)
    if setup is None:
        print("  no setup")
    else:
        print("  " + setup["grade"] + " (" + str(setup["score"]) + "%) " + setup["direction"].upper() + " trigger=" + str(setup.get("trigger")))
        print("  entry=" + str(setup["entry"]) + " SL=" + str(setup["sl"]) + " TP=" + str(setup["tp"]) + " RR=" + str(setup["rr"]))
        lot, rusd, rpct, warn = risk_manager.calculate_lot_size(symbol, setup["sl_dist"], balance)
        warnstr = warn if warn else ""
        print("  lot=" + str(lot) + " risk=$" + str(round(rusd, 2)) + " (" + str(rpct) + "%) " + warnstr)
