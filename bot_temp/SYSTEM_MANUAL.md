# ðŸ“˜ FXAlexG Trading Bot â€” Complete Institutional System Manual (v3.2)
> **Authoritative System Architecture, Strategy Engine, and Operational Documentation**  
> **Server:** `evilgnx` (`REDACTED_IP`) | **Workspace:** `/home/ubuntu/fxalexg_bot/`  
> **Last Updated:** August 27, 2026 | **Version:** 3.2 High-Growth Edition

---

## ðŸ“‘ Table of Contents
1. [Server & Infrastructure Overview](#1-server--infrastructure-overview)
2. [Bot Architecture & File Structure](#2-bot-architecture--file-structure)
3. [Strategy Engine (Institutional ICT Rules)](#3-strategy-engine-institutional-ict-rules)
4. [The 7 Strategic Upgrades (v3.1 & v3.2)](#4-the-7-strategic-upgrades-v31--v32)
5. [Risk Parity & $10+ Growth Sizing](#5-risk-parity--10-growth-sizing)
6. [Active Trade Lifecycle Management](#6-active-trade-lifecycle-management)
7. [Telegram Control & Notifications](#7-telegram-control--notifications)
8. [Server Management & Command Reference](#8-server-management--command-reference)
9. [Database & History Queries](#9-database--history-queries)

---

## 1. Server & Infrastructure Overview

### ðŸ–¥ï¸ Host & Environment
- **Provider:** Oracle Cloud Infrastructure (OCI) â€” Free Tier Always-On
- **OS:** Ubuntu 20.04.6 LTS (x86_64)
- **Public IP:** `REDACTED_IP` | **Hostname:** `evilgnx` | **Default User:** `ubuntu`
- **Python Environment:** Python 3.8.10 (`/usr/bin/python3`)
- **MT5 Runtime:** MetaTrader 5 (Exness) running inside a Wine Windows emulation environment (`/home/ubuntu/.wine_exness/`)

### ðŸ”‘ SSH Access & Dual-Port Redundancy
- **Primary SSH Key:** `ssh-key-2025-11-24.key` (Located locally in `~/.ssh/server_keys/`)
- **Dual-Port Access:** SSH daemon is configured to listen on **Port 22** and **Port 443** (bypasses restricted Wi-Fi / firewall blocks):
  ```powershell
  # Standard connection:
  ssh -i "$HOME\.ssh\server_keys\ssh-key-2025-11-24.key" ubuntu@REDACTED_IP

  # Firewall-bypass connection (Port 443):
  ssh -p 443 -i "$HOME\.ssh\server_keys\ssh-key-2025-11-24.key" ubuntu@REDACTED_IP
  ```

---

## 2. Bot Architecture & File Structure

```
/home/ubuntu/fxalexg_bot/
â”œâ”€â”€ bot.py                # Main orchestration loop, schedule manager, and trade lifecycle monitor
â”œâ”€â”€ strategy.py           # Core ICT strategy engine: ADX, OTE ranges, AOI zones, triggers, grading
â”œâ”€â”€ config.py             # Global parameters: accounts, risk %, R:R targets, symbols, filters
â”œâ”€â”€ risk_manager.py       # Live risk-parity lot sizer based on broker contract specs & tick valuation
â”œâ”€â”€ trade_logger.py       # SQLite interface for trades.db (trades, scans, and 24h loss cooldowns)
â”œâ”€â”€ data_provider.py      # Historical and live OHLCV data fetcher via MT5 bridge
â”œâ”€â”€ news_filter.py        # Economic calendar scraper & high-impact news filter
â”œâ”€â”€ notifier.py           # Telegram bot client for real-time alerts & remote command polling
â”œâ”€â”€ weekly_analyst.py     # Saturday top-down W1->D1->4H automated weekly outlook generator
â”œâ”€â”€ bridge_client.py      # HTTP client wrapper connecting to MT5 Flask bridge (Port 5001)
â”œâ”€â”€ backtester.py         # Multi-timeframe historical backtesting simulation engine
â”œâ”€â”€ trades.db             # SQLite database storing trade history, scans, and active tickets
â”œâ”€â”€ active_account.json   # Persistent record of currently active account profile (demo/real)
â””â”€â”€ chat_id.json          # Registered Telegram Chat ID for @anonye_trading_bot
```

### âš™ï¸ Systemd Services
1. **`fxalexg-bot.service`**: The main Python trading bot process.
2. **`mt5-bridge.service`**: The Wine MT5 bridge process exposing REST API on `http://localhost:5001`.

---

## 3. Strategy Engine (Institutional ICT Rules)

The bot trades like a **patient institutional swing/day trader**, inspired by **FXAlexG** and **ICT (Inner Circle Trader)** methodology.

### 4-Timeframe Top-Down Hierarchy
1. **Weekly (W1)**: Determines long-term bias (`close > EMA21` = Bullish, `close < EMA21` = Bearish).
2. **Daily (D1)**: Confirms trend vs **200 EMA** and extracts previous day/week extremes (`PDH`, `PDL`, `PWH`, `PWL`).
3. **4-Hour (4H)**: Maps the dynamic dealing range (Swing High/Low, Equilibrium 50%, and 61.8% OTE boundaries).
4. **15-Minute (15M)**: During Kill Zones, detects liquidity sweeps, Change of Character (CHoCH), and Fair Value Gap (FVG) mitigations.

### Scoring & Grading System (A+ Gate: Score â‰¥ 80)
Every setup is scored across 10 confluence criteria:
- **Key AOI Zone Hit**: +15 pts
- **True OTE Discount/Premium**: +15 pts
- **3-Timeframe Sync (W1+D1+4H)**: +18 pts
- **4H EMA21 Direction OK**: +10 pts
- **Daily EMA200 Trend OK**: +10 pts
- **Shift of Structure (HH / LL)**: +12 pts
- **4H Engulfing Candle Trigger**: +15 pts
- **4H Rejection Wick Trigger**: +12 pts
- **15M CHoCH Mitigation**: +15 pts
- **Psychological Round Number**: +5 pts
- **RSI Range Filter OK (32â€“68)**: +5 pts
- **Near PDH/PDL Key Level**: +6 pts

> **Execution Rule:** Only **A+ setups (Score â‰¥ 80)** with full **3/3 Timeframe Confluence** are executed.

---

## 4. The 7 Strategic Upgrades (v3.1 & v3.2)

| # | Upgrade | Problem Solved | Implementation Detail |
|---|---|---|---|
| 1 | **True OTE Dealing Range** | Buying at top / Selling at bottom | Price must be **â‰¤ 61.8% Discount** for Longs, **â‰¥ 61.8% Premium** for Shorts. |
| 2 | **14-Period ADX Regime Filter** | Getting chopped in sideways ranges | If 4H ADX < 20, the market is ranging â€” all trade entries are automatically skipped. |
| 3 | **Adaptive Crypto vs Forex SL** | Crypto SLs placed in intraday noise | **Crypto (BTC/ETH):** 12-candle (48h) lookback + 0.5Ã— ATR.<br>**Forex:** 6-candle (24h) lookback + 0.2Ã— ATR. |
| 4 | **24-Hour Post-Loss Cooldown** | Revenge trading / cluster losses | Pairs with a recent loss are locked for 24 hours (`is_in_cooldown`). |
| 5 | **Strict 3TF Alignment** | Counter-trend entries | Primary 4H entries strictly require W1 + D1 + 4H alignment. |
| 6 | **High-Impact News Guard** | News spike whipsaws | Scans are paused 30 minutes before high-impact economic releases (CPI, NFP, PCE). |
| 7 | **Extended 1:3.0 Targets** | Small dollar payouts | TP2 target expanded to 1:3.0 RR for $10+ payouts per winning trade. |

---

## 5. Risk Parity & $10+ Growth Sizing

### High-Growth Mode Parameters (`config.py` & `risk_manager.py`)
- **`RISK_PERCENT = 7.5%`**: Dynamically sizes lots based on balance.
- **`MIN_RISK_USD = $3.50`**: Enforces a minimum dollar risk floor so micro accounts ($50) generate **$10.00+ on winning trades**.
- **`MAX_RISK_PCT = 10.0%`**: Safety ceiling to prevent overleveraging.
- **`MAX_CONCURRENT = 2`**: Maximum 2 open positions simultaneously.

### Active Pairs:
- `EURUSDm`, `GBPUSDm`, `USDJPYm`, `BTCUSDm`, `ETHUSDm`, `XAUUSDm` (Gold)

### Sample Payout Breakdown on $50 Account:
- **Risk per trade:** ~$3.50
- **TP1 (50% partial @ 1:1.2):** Banks **+$2.10** into balance, moves SL to Breakeven.
- **TP2 (50% runner @ 1:3.0):** Banks **+$5.25 to +$8.40**.
- **Total Win:** **+$10.00 to +$12.50+** (+20% to +25% account jump on 1 trade).

---

## 6. Active Trade Lifecycle Management

The bot runs an automated trade management cycle **every 15 seconds**:

```
                       [ TRADE OPENED (A+ Setup) ]
                                    â”‚
                  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
                  â–¼                                   â–¼
        [ Price reaches TP1 (1:1.2) ]       [ 4H Structure Breaks ]
                  â”‚                                   â”‚
      â€¢ Closes 50% lot into cash            â€¢ check_ema_invalidation()
      â€¢ Moves SL to Breakeven (+buffer)     â€¢ Closes trade early (-$0.50)
                  â”‚
                  â–¼
        [ Trailing Stop Active ]
      â€¢ 15M EMA21 walks SL upward
      â€¢ Catches reversals in profit
                  â”‚
                  â–¼
        [ TP2 Target Hit (1:3.0) ]
        â€¢ Full $10.00+ Profit Secured!
```

- **36-Hour TTL:** If a trade remains stagnant for 36 hours without hitting TP1, it is closed automatically to free margin.

---

## 7. Telegram Control & Notifications

- **Bot Handle:** `@anonye_trading_bot`
- **Chat ID:** `6220850396` (saved in `chat_id.json`)

### Interactive Commands:
- `/status` â€” Shows system health, active profile, and live open positions.
- `/account` â€” Shows current balance, equity, leverage, and broker server.
- `/demo` â€” Instantly switches MT5 to the Demo (Trial) account.
- `/real` â€” Instantly switches MT5 to the Live Real account.
- `/help` â€” Displays command list.

### Automated Notifications:
- **ðŸš€ Trade Opened Cards**: Entry, SL, TP1, TP2, lot size, risk $, grade confluences.
- **ðŸŽ¯ TP1 Hit Alerts**: Partial profit banked and breakeven confirmation.
- **ðŸ Trade Closed Cards**: Total P&L and updated balance.
- **â¸ï¸ News Pause Alerts**: When scans are paused due to high-impact events.
- **ðŸ“… Saturday Weekly Outlook**: Full W1/D1/4H macro roadmap every Saturday at 08:00 UTC.

---

## 8. Server Management & Command Reference

### Quick Health Check (1-Second):
```bash
ssh -i ~/.ssh/server_keys/ssh-key-2025-11-24.key ubuntu@REDACTED_IP "systemctl is-active fxalexg-bot mt5-bridge"
```

### Managing Services:
```bash
# Restart trading bot:
sudo systemctl restart fxalexg-bot

# Restart MT5 Wine bridge:
sudo systemctl restart mt5-bridge

# View live bot logs:
journalctl -u fxalexg-bot -f --no-pager

# View last 50 lines of logs:
journalctl -u fxalexg-bot -n 50 --no-pager
```

---

## 9. Database & History Queries

To inspect trades or scans directly on the server:
```bash
# Query recent trades:
python3 -c "import sqlite3; conn=sqlite3.connect('/home/ubuntu/fxalexg_bot/trades.db'); c=conn.cursor(); c.execute('SELECT id, opened_at, symbol, direction, grade, lot, risk_usd, result_usd, status FROM trades ORDER BY id DESC LIMIT 15'); [print(r) for r in c.fetchall()]"

# Query recent scans:
python3 -c "import sqlite3; conn=sqlite3.connect('/home/ubuntu/fxalexg_bot/trades.db'); c=conn.cursor(); c.execute('SELECT id, scanned_at, symbol, grade, score, direction, action FROM scans ORDER BY id DESC LIMIT 15'); [print(r) for r in c.fetchall()]"
```

---
*This document serves as the complete operational handbook for the FXAlexG Institutional Trading System.*
