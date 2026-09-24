import sqlite3
import pandas as pd
from datetime import datetime

DB_PATH = "trades.db"

def run_analytics():
    print("="*50)
    print("  FXAlexG Bot — Trade Analytics")
    print("="*50)

    try:
        conn = sqlite3.connect(DB_PATH)
        df = pd.read_sql_query("SELECT * FROM trades WHERE status='closed'", conn)
        conn.close()
    except Exception as e:
        print(f"Error reading database: {e}")
        return

    if df.empty:
        print("No closed trades found yet.")
        return

    df['opened_at'] = pd.to_datetime(df['opened_at'])
    df['closed_at'] = pd.to_datetime(df['closed_at'])
    df['win'] = df['pnl'] > 0
    df['duration_hrs'] = (df['closed_at'] - df['opened_at']).dt.total_seconds() / 3600.0

    total_trades = len(df)
    win_rate = df['win'].mean() * 100
    total_pnl = df['pnl'].sum()

    print(f"Total Closed Trades: {total_trades}")
    print(f"Overall Win Rate:    {win_rate:.1f}%")
    print(f"Total P&L:           ${total_pnl:.2f}\n")

    print("--- Performance by Symbol ---")
    sym_stats = df.groupby('symbol').agg(
        trades=('ticket', 'count'),
        win_rate=('win', lambda x: x.mean() * 100),
        pnl=('pnl', 'sum'),
        avg_dur=('duration_hrs', 'mean')
    ).round(2).sort_values('pnl', ascending=False)
    
    for sym, row in sym_stats.iterrows():
        print(f"{sym:<10} | Trades: {row['trades']:<3} | Win Rate: {row['win_rate']:>5.1f}% | P&L: ${row['pnl']:>6.2f} | Avg Dur: {row['avg_dur']:>4.1f}h")

    print("\n--- Performance by Direction ---")
    dir_stats = df.groupby('direction').agg(
        trades=('ticket', 'count'),
        win_rate=('win', lambda x: x.mean() * 100),
        pnl=('pnl', 'sum')
    ).round(2)
    for d, row in dir_stats.iterrows():
        print(f"{d:<10} | Trades: {row['trades']:<3} | Win Rate: {row['win_rate']:>5.1f}% | P&L: ${row['pnl']:>6.2f}")

    print("\n--- Longest Winning / Losing Streaks ---")
    # Simple streak calc
    streaks = df.sort_values('closed_at')['win'].tolist()
    curr_streak = max_win = max_loss = 0
    curr_type = None

    for win in streaks:
        if curr_type is None:
            curr_type = win
            curr_streak = 1
        elif curr_type == win:
            curr_streak += 1
        else:
            if curr_type: max_win = max(max_win, curr_streak)
            else: max_loss = max(max_loss, curr_streak)
            curr_type = win
            curr_streak = 1
            
    if curr_type: max_win = max(max_win, curr_streak)
    else: max_loss = max(max_loss, curr_streak)
            
    print(f"Max Consecutive Wins:   {max_win}")
    print(f"Max Consecutive Losses: {max_loss}")
    print("="*50)

if __name__ == "__main__":
    run_analytics()
