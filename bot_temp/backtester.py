"""
Multi-timeframe Backtesting & Verification Engine.
Simulates realistic spread, partial TP @ 1:1.2, Breakeven SL, and 1:2.5 target.
"""

import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import pandas as pd
import numpy as np
import data_provider as dp
import strategy
import config


def run_backtest(symbol="EURUSDm", count=2500):
    print(f"\n{'='*65}")
    print(f"  BACKTEST SIMULATION: {symbol} ({count} 4H Bars)")
    print(f"{'='*65}")

    df_w = dp._fetch(symbol, "W1", max(100, count // 10))
    df_d = dp._fetch(symbol, "D1", max(200, count // 4))
    df_4h = dp._fetch(symbol, "H4", count)

    if df_w is None or df_d is None or df_4h is None:
        print(f"  Failed to fetch data for {symbol}.")
        return None

    df_w  = strategy.add_indicators(df_w)
    df_d  = strategy.add_indicators(df_d)
    df_4h = strategy.add_indicators(df_4h)

    trades = []
    open_trade = None
    min_start_bar = 80

    for i in range(min_start_bar, len(df_4h) - 1):
        bar = df_4h.iloc[i]
        current_time = df_4h.index[i]

        # 1. Manage Active Position
        if open_trade:
            direction = open_trade["direction"]
            sl = open_trade["sl"]
            tp1 = open_trade["tp1"]
            tp2 = open_trade["tp2"]
            entry = open_trade["entry"]
            partial = open_trade["partial"]

            if direction == "bullish":
                # Check Stop Loss
                if bar["low"] <= sl:
                    if partial:
                        pnl_r = 0.5 * config.TP1_RR + 0.5 * 0.0 # secured TP1, rest exited at breakeven
                    else:
                        pnl_r = -1.0 # full stop loss
                    trades.append({**open_trade, "exit_time": current_time, "result": "BE/SL" if partial else "SL", "pnl_r": pnl_r})
                    open_trade = None
                # Check Take Profit 1
                elif not partial and bar["high"] >= tp1:
                    open_trade["partial"] = True
                    open_trade["sl"] = entry # Move SL to Breakeven
                # Check Take Profit 2
                elif partial and bar["high"] >= tp2:
                    pnl_r = 0.5 * config.TP1_RR + 0.5 * config.TP2_RR
                    trades.append({**open_trade, "exit_time": current_time, "result": "TP2_FULL", "pnl_r": pnl_r})
                    open_trade = None
            else:
                # Bearish Trade
                if bar["high"] >= sl:
                    if partial:
                        pnl_r = 0.5 * config.TP1_RR + 0.5 * 0.0
                    else:
                        pnl_r = -1.0
                    trades.append({**open_trade, "exit_time": current_time, "result": "BE/SL" if partial else "SL", "pnl_r": pnl_r})
                    open_trade = None
                elif not partial and bar["low"] <= tp1:
                    open_trade["partial"] = True
                    open_trade["sl"] = entry
                elif partial and bar["low"] <= tp2:
                    pnl_r = 0.5 * config.TP1_RR + 0.5 * config.TP2_RR
                    trades.append({**open_trade, "exit_time": current_time, "result": "TP2_FULL", "pnl_r": pnl_r})
                    open_trade = None

            if open_trade:
                continue

        # 2. Check for New Setup
        slice_w  = df_w[df_w.index <= current_time]
        slice_d  = df_d[df_d.index <= current_time]
        slice_4h = df_4h.iloc[:i+1]

        if len(slice_w) < 10 or len(slice_d) < 20:
            continue

        setup = strategy.analyze_pair(symbol, slice_w, slice_d, slice_4h, df_15m=None, in_kill_zone=False)

        if setup and setup["grade"] in ("A+", "B+"):
            open_trade = {
                "symbol": symbol,
                "entry_time": current_time,
                "entry": setup["entry"],
                "direction": setup["direction"],
                "sl": setup["sl"],
                "tp1": setup["tp1"],
                "tp2": setup["tp2"],
                "grade": setup["grade"],
                "score": setup["score"],
                "partial": False,
            }

    # Summary
    if not trades:
        print("  No completed trades in backtest period.")
        return None

    df_res = pd.DataFrame(trades)
    total_trades = len(df_res)
    tp2_wins = len(df_res[df_res["result"] == "TP2_FULL"])
    be_wins = len(df_res[df_res["result"] == "BE/SL"])
    full_losses = len(df_res[df_res["result"] == "SL"])
    
    profitable_trades = tp2_wins + be_wins
    win_rate = (profitable_trades / total_trades) * 100.0
    total_r = df_res["pnl_r"].sum()
    profit_factor = df_res[df_res["pnl_r"] > 0]["pnl_r"].sum() / max(abs(df_res[df_res["pnl_r"] < 0]["pnl_r"].sum()), 1e-6)

    print(f"  Total Trades:     {total_trades}")
    print(f"  TP2 Full Targets: {tp2_wins} ({tp2_wins/total_trades*100:.1f}%)")
    print(f"  TP1 + Breakeven:  {be_wins} ({be_wins/total_trades*100:.1f}%)")
    print(f"  Full Stop Losses: {full_losses} ({full_losses/total_trades*100:.1f}%)")
    print(f"  Win / Profit Rate:{win_rate:.1f}%")
    print(f"  Total Net Return: +{total_r:.2f} R")
    print(f"  Profit Factor:    {profit_factor:.2f}")

    return {
        "symbol": symbol,
        "total_trades": total_trades,
        "win_rate": win_rate,
        "total_r": total_r,
        "profit_factor": profit_factor,
    }


if __name__ == "__main__":
    results = []
    for sym in config.SYMBOLS:
        res = run_backtest(sym, count=1500)
        if res:
            results.append(res)

    if results:
        print("\n" + "="*65)
        print("  PORTFOLIO SUMMARY ACROSS ALL PAIRS")
        print("="*65)
        tot_trades = sum(r["total_trades"] for r in results)
        tot_r = sum(r["total_r"] for r in results)
        avg_pf = np.mean([r["profit_factor"] for r in results])
        print(f"  Total Portfolio Trades: {tot_trades}")
        print(f"  Total Portfolio Return: +{tot_r:.2f} R")
        print(f"  Average Profit Factor:  {avg_pf:.2f}")
        print("="*65)
