# FXAlexG Trading Bot â€” Complete System & Dual-AI Documentation
**Version:** v3.3 (Dual-AI Supercharged Institutional Mode)  
**Server:** evilgnx (Oracle Cloud Ubuntu)  
**Last Verified:** 2026-09-10 13:28 UTC â€” ALL 10/10 SYSTEMS + DUAL-AI ENGINES OPERATIONAL

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Dual-AI Institutional Engine](#2-dual-ai-institutional-engine)
3. [Trading Strategy & ICT SMC Rules](#3-trading-strategy--ict-smc-rules)
4. [Signal Pipeline & Indicators](#4-signal-pipeline--indicators)
5. [Entry Logic & AI Pre-Trade Gatekeeper](#5-entry-logic--ai-pre-trade-gatekeeper)
6. [Risk Management & Lot Sizing](#6-risk-management--lot-sizing)
7. [Trade Management & Post-Trade AI Learning](#7-trade-management--post-trade-ai-learning)
8. [News Filter & Economic Events](#8-news-filter--economic-events)
9. [Telegram Bot & Interactive AI Commands](#9-telegram-bot--interactive-ai-commands)
10. [Configuration Reference](#10-configuration-reference)
11. [Verification & Health Proofs](#11-verification--health-proofs)
12. [File Reference](#12-file-reference)

---

## 1. Architecture Overview

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                       Telegram Bot                          â”‚
â”‚                   @anonye_trading_bot                       â”‚
â”‚    User Commands: /ai /news /account /status /report /help  â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                               â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                    bot.py (Python3)                         â”‚
â”‚                  systemd: fxalexg-bot                       â”‚
â”‚   Main Loop: Scan â†’ Filter â†’ AI Validate â†’ Execute â†’ Manage â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
               â”‚                              â”‚
     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”          â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â–¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
     â”‚ Strategy & Market â”‚          â”‚  ai_engine.py          â”‚
     â”‚ Data Pipeline     â”‚          â”‚  Dual-AI Intelligence  â”‚
     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜          â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
               â”‚                              â”‚
        â”Œâ”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
        â–¼      â–¼      â–¼              â–¼                  â–¼
      strat  data   risk          Google             OpenRouter
      egy.py prov   mgr.py        Gemini 2.5 Flash   DeepSeek-V3
             ider.py              (Primary)          (Fallback)
        â”‚      â”‚      â”‚              â–²                  â–²
        â””â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”˜              â””â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
               â–¼                              â”‚
     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                     â”‚
     â”‚ bridge_client.py â”‚                     â”‚
     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”˜                     â”‚
               â–¼ HTTP localhost:5001          â”‚
     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                     â”‚
     â”‚ mt5_bridge.py    â”‚ (Wine + Python3.9)  â”‚
     â”‚ systemd:         â”‚                     â”‚
     â”‚ mt5-bridge       â”‚                     â”‚
     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”˜                     â”‚
               â–¼                              â”‚
     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                     â”‚
     â”‚ terminal64.exe   â”‚ (Exness MT5)        â”‚
     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                     â”‚
               â”‚                              â”‚
               â–¼                              â–¼
     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
     â”‚ trades.db (SQLite) + trade_logger.py             â”‚
     â”‚ Logs all setups, trades, and AI post-mortems     â”‚
     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

---

## 2. Dual-AI Institutional Engine

The bot features a **Dual-AI Provider Architecture** designed for high speed, zero downtime, and deep price action reasoning:

### Providers
1. **Primary AI Engine: Google Gemini 2.5 Flash**
   - **API Key Format:** `REDACTED_GEMINI_KEY`
   - **Model:** `gemini-2.5-flash`
   - **Latency:** ~400ms â€“ 800ms
   - **Role:** Real-time setup verification, trap detection, on-demand SMC pair analysis, and session macro pulse.
2. **Secondary / Fallback Engine: OpenRouter (DeepSeek)**
   - **API Key:** `REDACTED_OPENROUTER_KEY`
   - **Model:** `deepseek/deepseek-chat`
   - **Role:** Instant automatic fallback if Gemini ever encounters rate limits or network issues.

### AI Core Capabilities
- **Pre-Trade Gatekeeper:** Before any order is submitted to MT5, the candidate setup is passed to the AI with full multi-timeframe indicators (ATR, RSI, ADX, AOI, FVG, dealing range, news).
  - Verdicts: `APPROVED`, `CAUTION`, `REJECTED`.
  - Trap Detection: Flags liquidity sweeps against retail entries, low-volatility consolidation chop, and exhaustion points.
  - Required Confidence: Minimum 70% for A+ setups; minimum 85% with `APPROVED` verdict to upgrade high-scoring B+ setups (80+ pts).
- **Interactive Telegram Assistant (`/ai`):** Allows the trader to request real-time institutional analysis on any pair (e.g. `/ai EURUSD`, `/ai GOLD`, `/ai BTC`), macro session pulses, engine status, or ask open-ended trading questions.
- **Post-Trade Review & Learning:** When an open position closes (take profit or stop loss), the AI analyzes the trade outcome against the initial technical thesis and logs lessons into the database.

---

## 3. Trading Strategy & ICT SMC Rules

### Philosophy
Inner Circle Trader (ICT) & FXAlexG Smart Money Concepts. Built to deliver high-growth ($10+ profit targets) on micro balances ($50+) while strictly guarding capital.

### Core Rules
1. **Multi-Timeframe Trend Synchronization**
   - Weekly (W1) structure bias
   - Daily (D1) trend relative to EMA200 & EMA21
   - 4-Hour (4H) trend & EMA21 slope
   - Allows entries when D1 and 4H agree (2TF Sync) even if W1 is neutral or undergoing retracement.
2. **Dealing Range & Optimal Trade Entry (OTE)**
   - Calculates 4H swing high and swing low over a 30-candle window.
   - Longs are ONLY allowed below equilibrium in the discount zone (61.8% â€“ 79% Fibonacci discount).
   - Shorts are ONLY allowed above equilibrium in the premium zone (61.8% â€“ 79% Fibonacci premium).
3. **Market Regime Filter (ADX)**
   - 4H ADX must be $\ge 20$ to ensure trending conditions. Consolidations and choppy flat markets are skipped.
4. **Liquidity & Key Levels**
   - Areas of Interest (AOI): Multi-touch support/resistance and order blocks.
   - Previous Day High/Low (PDH/PDL) and Previous Week High/Low (PWH/PWL).
   - Psychological round numbers (.000, .500).
   - 15M Fair Value Gaps (FVG) and Liquidity Sweeps.
5. **Session Kill Zones**
   - **Asian:** 00:00 â€“ 04:00 UTC (15-min scan)
   - **London:** 07:00 â€“ 10:00 UTC (15-min scan)
   - **New York:** 12:00 â€“ 15:00 UTC (15-min scan)
   - **Off-hours:** 00, 04, 08, 12, 16, 20 UTC (4H candle closes)

---

## 4. Signal Pipeline & Indicators

For each symbol in `config.SYMBOLS` (13 Forex, Crypto, and Gold pairs):
1. **Loss Cooldown Check:** If symbol experienced a loss in the past 24 hours, it is skipped.
2. **Economic News Check:** If high-impact news is due within 30 minutes, scanning is paused on that pair.
3. **Spread Verification:** Live spread must be within $3\times$ baseline.
   - *Gold fix applied:* `NORMAL_SPREAD_POINTS["XAUUSDm"] = 300` (allowing up to 900 points / $0.90, matching Exness 3-decimal pricing).
4. **Data Retrieval:** Live OHLCV bars for W1 (50 bars), D1 (100 bars), 4H (100 bars), and 15M (100 bars).
5. **Technical Indicators Calculated:**
   - EMA 9, EMA 21, EMA 200
   - RSI (14) â€” bounded between 32 and 68 for entries
   - ATR (14) â€” dynamic volatility measurement
   - ADX (14) â€” regime filter ($\ge 20$)
6. **Structure & Dealing Range Analysis:**
   - Swing High / Low / Equilibrium
   - Discount/Premium positioning
   - Shift of Structure (SOS) detection
7. **Entry Triggers:**
   - **Primary (Kill Zone):** 15M Sweep & CHoCH mitigation into FVG or AOI.
   - **Secondary (4H):** 4H Rejection Wick or 4H Bullish/Bearish Engulfing candle.

---

## 5. Entry Logic & AI Pre-Trade Gatekeeper

### Scoring & Grading
- Maximum score: 111 points across confluences:
  - Key AOI: +15
  - Swing Discount/Premium: +15
  - 3TF Sync: +18 (or 2TF Sync: +12)
  - 4H EMA21 ok: +10
  - D1 EMA200 ok: +10
  - Shift of Structure: +12
  - Trigger (15M CHoCH / Engulfing): +15
  - Psychological Level: +5
  - RSI Filter ok: +5
  - PDH/PDL Key Level: +6
- **Grade Gates:**
  - $\ge 95$: **A+** (Mechanically approved)
  - $\ge 80$: **B+** (Eligible for AI Upgrade)

### AI Gatekeeper Workflow
```
Candidate Setup Detected
       â”‚
       â–¼
[Is Score >= 80?] â”€â”€Noâ”€â”€> Skip
       â”‚ Yes
       â–¼
[Dual-AI Pre-Trade Evaluation]
   â€¢ Sends multi-TF snapshot + RSI + ADX + Spread + News
   â€¢ Gemini evaluates trap risk, liquidity pools, SMC confluence
       â”‚
   â”Œâ”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
   â–¼                            â–¼
[A+ Setup]                   [B+ Setup]
Verdict == "APPROVED"        Verdict == "APPROVED"
Confidence >= 70%            Confidence >= 85%
Trap == False                Trap == False
   â”‚                            â”‚
   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                 â–¼
          [EXECUTE ORDER]
   â€¢ Dynamic lot sized to target $10+ profit
   â€¢ Place order on MT5 via Bridge
   â€¢ Send Telegram alert with AI narrative & badge
```

---

## 6. Risk Management & Lot Sizing

- **Risk Model:** Risk-Parity Lot Sizing targeting **$3.50 â€“ $5.00** risk per trade to produce **$10.00+** profit on winning trades.
- **Risk Percentage:** 7.5% of account balance (or min $1.50 for micro accounts).
- **Safety Caps:**
  - Hard Risk Cap: Maximum 10.0% or $15.00 per trade.
  - Min Balance Pause: $5.00 USD.
  - Max Concurrent Trades: 2.
  - Max Daily Trades: 4 (Max 2 per Kill Zone session).
- **Adaptive SL Buffers:**
  - Forex: 0.2 ATR buffer beyond structural swing high/low.
  - Crypto & Gold: 0.5 ATR buffer for higher volatility.

---

## 7. Trade Management & Post-Trade AI Learning

1. **Take Profit 1 (TP1):** 1:1.0 RR.
   - At TP1, 50% of the position is automatically closed to bank cash.
   - Stop Loss is immediately moved to Breakeven (BE).
2. **Take Profit 2 (TP2):** 1:3.0 RR.
   - Target for the remaining 50% position to yield $10+ gains.
3. **Dynamic Trailing Stop:**
   - After TP1 is reached, SL trails behind the 15M EMA21 with a 5-pip buffer.
4. **Time-To-Live (TTL):**
   - If TP1 is not achieved within 36 hours, trade is closed to free capital.
5. **AI Post-Trade Review:**
   - Once position closes, `ai_engine.review_trade_outcome()` conducts an automated post-mortem, which is sent to Telegram and saved in `trades.db`.

---

## 8. News Filter & Economic Events

- Automated scraping of ForexFactory economic calendar via high-reliability CDN (`nfs.faireconomy.media`).
- Daily automated news briefing broadcast to Telegram at **06:00 UTC**.
- Prevents entries within 30 minutes of high-impact events for base and quote currencies.

---

## 9. Telegram Bot & Interactive AI Commands

All interactions are handled through `@anonye_trading_bot`:

| Command | Action |
|---------|--------|
| `/ai` | Opens the AI Intelligence menu and overview |
| `/ai <pair>` | Deep SMC breakdown (e.g. `/ai EURUSD`, `/ai GOLD`, `/ai BTC`, `/ai ETH`) |
| `/ai pulse` | Macro session breakdown across all 13 pairs |
| `/ai status` | Dual-AI engine latency & health check |
| `/ai <question>`| Freeform AI trading advisor (e.g. `/ai should I hold EURUSD?`) |
| `/account` | Current MT5 login, server, balance, equity, and leverage |
| `/status` | System health check and live open positions |
| `/report` | Real-time P&L performance report for today and this week |
| `/news` | Today's upcoming high-impact economic news |
| `/real` | Instant switch to Exness Live Real account (`Exness-MT5Real3`) |
| `/demo` | Instant switch to Exness Trial Demo account (`Exness-MT5Trial9`) |
| `/help` | Complete commands list |

---

## 10. Configuration Reference (`config.py`)

```python
# --- AI Intelligence Engine ---
AI_ENABLED               = True
GEMINI_API_KEY           = "REDACTED_GEMINI_KEY"
OPENROUTER_API_KEY       = "REDACTED_OPENROUTER_KEY"
AI_CONFIRMATION_REQUIRED = True   # AI evaluates all candidate setups before opening orders
AI_MIN_CONFIDENCE        = 70     # Minimum AI confidence (0-100) to approve trade
AI_UPGRADE_B_PLUS        = True   # AI can upgrade high-scoring B+ (80+) setups if confidence >= 85
AI_POST_TRADE_REVIEW     = True   # AI reviews won/lost trades for learning
AI_SESSION_PULSE         = True   # Macro pulse broadcast after scan

# --- Account Profiles ---
ACCOUNTS = {
    "demo": {"login": 00000000, "server": "Exness-MT5Trial9", "label": "Demo (Trial)"},
    "real": {"login": 00000000, "server": "Exness-MT5Real3", "label": "Real (Live)"},
}

# --- Pairs Tracked (13) ---
SYMBOLS = [
    "EURUSDm", "GBPUSDm", "USDJPYm", "AUDUSDm", "USDCADm",
    "EURJPYm", "GBPJPYm", "BTCUSDm", "ETHUSDm", "XAUUSDm",
    "SOLUSDm", "XRPUSDm", "LTCUSDm"
]

# --- Risk & Targets ---
RISK_PERCENT = 7.5
MIN_RISK_USD = 1.50
MAX_RISK_USD = 15.0
TP1_RR       = 1.0  (50% partial + Move SL to Breakeven)
TP2_RR       = 3.0  ($10+ target)
```

---

## 11. Verification & Health Proofs

Verified live on server `evilgnx`:
- **MT5 Bridge Connection:** HTTP 200, Connected, Balance: $50.00 USD.
- **Gold Spread Filter:** Passed (Spread: 260 points vs 300 baseline $\times 3$ max).
- **Google Gemini 2.5 Flash:** Operational, HTTP 200, Latency < 800ms.
- **OpenRouter DeepSeek:** Operational, HTTP 200.
- **Systemd Service:** `fxalexg-bot.service` active and running.
- **Telegram Connectivity:** Verified, notifications live to chat `6220850396`.

---

## 12. File Reference

All files reside in `/home/ubuntu/fxalexg_bot/` on `evilgnx`:
- `bot.py` â€” Orchestrator, scanning loop, position manager, and Telegram router.
- `ai_engine.py` â€” Dual-AI Engine (Gemini 2.5 Flash + OpenRouter DeepSeek).
- `config.py` â€” System configurations, AI parameters, risk limits, and spread baselines.
- `strategy.py` â€” Multi-timeframe ICT/SMC indicator calculations, dealing ranges, and triggers.
- `data_provider.py` â€” MT5 OHLCV bar fetcher across W1, D1, 4H, and 15M.
- `risk_manager.py` â€” Risk-parity lot sizing engine.
- `bridge_client.py` â€” REST client connecting `bot.py` to `mt5_bridge.py`.
- `mt5_bridge.py` â€” Wine Python 3.9 HTTP bridge wrapping MetaTrader5 API.
- `news_filter.py` â€” ForexFactory economic calendar reader.
- `notifier.py` â€” Telegram bot alerting engine.
- `trade_logger.py` â€” SQLite database recorder (`trades.db`).
- `FULL_SYSTEM_DOCS.md` â€” This master documentation.
