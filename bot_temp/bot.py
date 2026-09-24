"""
FXAlexG Trading Bot — Institutional Edition v3.1
Main orchestration loop, multi-timeframe scanner, position manager,
and Telegram interaction interface.

v3.1 Upgrades:
  - Integrated 24h re-entry cooldown on symbols after recent losses
  - Active high-impact economic news filter enforcement
  - Strict A+ setup execution with ADX market regime filtering
  - Adaptive crypto/forex stop loss sizing
"""

import time
import json
import traceback
from datetime import datetime, timezone, timedelta
from pathlib import Path

import config
import bridge_client as bridge
import data_provider as dp
import strategy
import risk_manager
import trade_logger
import news_filter
import notifier
import ai_engine

# [v3.2] Setup deduplication tracker
_last_signaled = {}  # {symbol: (direction, swing_eq)}
import weekly_analyst

BOT_DIR = Path(__file__).parent
ACTIVE_ACCOUNT_FILE = BOT_DIR / "active_account.json"


def load_active_account():
    if ACTIVE_ACCOUNT_FILE.exists():
        try:
            data = json.loads(ACTIVE_ACCOUNT_FILE.read_text())
            return data.get("active_account", config.ACTIVE_ACCOUNT)
        except Exception:
            pass
    return config.ACTIVE_ACCOUNT


def save_active_account(acc_key):
    try:
        ACTIVE_ACCOUNT_FILE.write_text(json.dumps({"active_account": acc_key}))
    except Exception as e:
        print(f"[config] Failed to save active account: {e}")


def _ts():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def current_kill_zone():
    """
    Returns current active ICT Kill Zone session or None.
    London: 07:00 - 10:00 UTC
    New York: 12:00 - 15:00 UTC
    Asian: 00:00 - 04:00 UTC
    """
    now = datetime.now(timezone.utc)
    h = now.hour
    if 7 <= h < 10:
        return "london"
    elif 12 <= h < 15:
        return "new_york"
    elif 0 <= h < 4:
        return "asian"
    return None


def check_closed_positions():
    """Polls database for open trades and reconciles with MT5 positions."""
    open_tickets = trade_logger.get_open_trade_tickets()
    if not open_tickets:
        return
    live_positions = bridge.get_positions()
    live_tickets = {p["ticket"] for p in live_positions} if live_positions else set()
    for ticket in open_tickets:
        if ticket not in live_tickets:
            profit = bridge.get_position_result(ticket)
            if profit is not None:
                trade_logger.log_trade_closed(ticket, profit)
                pnl_str = str(round(profit, 2))
                sign = "+" if profit > 0 else ""
                trade_rec = trade_logger.get_trade_by_ticket(ticket) or {}
                ai_note = ""
                if getattr(config, "AI_POST_TRADE_REVIEW", False) and getattr(config, "AI_ENABLED", False):
                    try:
                        trade_rec["profit"] = profit
                        ai_rev = ai_engine.review_trade_outcome(trade_rec)
                        if ai_rev:
                            ai_note = f"\n\n🧠 <b>AI Trade Review:</b>\n<i>{ai_rev}</i>"
                    except Exception as e:
                        print(f"[{_ts()}] AI post-mortem error: {e}")
                notifier.send(f"🏁 Trade #{ticket} closed — P&L: <b>${sign}{pnl_str}</b>{ai_note}")
                print(f"[{_ts()}] Trade #{ticket} closed with P&L: ${sign}{pnl_str}")
            else:
                trade_logger.log_trade_closed(ticket, 0.0)
                print(f"[{_ts()}] Trade #{ticket} closed — logged.")


def manage_open_positions():
    """Manages TP1 partial profit, moves SL to breakeven, trails stop, and enforces TTL."""
    open_tickets = trade_logger.get_open_trade_tickets()
    if not open_tickets:
        return
    live_positions = bridge.get_positions()
    if not live_positions:
        return
    live_by_ticket = {p["ticket"]: p for p in live_positions}

    now = datetime.now(timezone.utc)

    for ticket in open_tickets:
        trade = trade_logger.get_trade_by_ticket(ticket)
        if not trade:
            continue

        pos = live_by_ticket.get(ticket)
        if not pos:
            continue

        entry     = trade["entry"]
        tp1       = trade.get("tp1")
        tp2       = trade.get("tp2")
        direction = trade["direction"]
        symbol    = trade["symbol"]
        opened_at_str = trade.get("opened_at")

        # 1. Trade TTL Check (Max lifespan)
        if opened_at_str and hasattr(config, "MAX_TRADE_LIFESPAN_HOURS"):
            try:
                opened_at = datetime.fromisoformat(opened_at_str).replace(tzinfo=timezone.utc)
                hours_open = (now - opened_at).total_seconds() / 3600.0
                if hours_open > config.MAX_TRADE_LIFESPAN_HOURS and not trade_logger.is_partial_closed(ticket):
                    print(f"[{_ts()}] TTL Exceeded ({hours_open:.1f}h) for {symbol} #{ticket}. Closing.")
                    res = bridge.close_position(ticket)
                    if res and "error" not in res:
                        notifier.send(f"🕒 Closed {symbol} #{ticket} — Lifespan exceeded ({config.MAX_TRADE_LIFESPAN_HOURS}h).")
                    continue
            except Exception as e:
                print(f"[{_ts()}] TTL error: {e}")

        if not tp1 or not entry:
            continue

        current_price = pos["current_price"]
        is_partially_closed = trade_logger.is_partial_closed(ticket)

        # 2. Check if price reached TP1 (1:1.2 RR)
        if not is_partially_closed:
            tp1_hit = (direction == "bullish" and current_price >= tp1) or \
                      (direction == "bearish" and current_price <= tp1)

            if tp1_hit:
                try:
                    full_volume = pos["volume"]
                    partial_volume = round(full_volume * config.PARTIAL_PCT, 2)
                    partial_volume = max(0.01, partial_volume)

                    print(f"[{_ts()}] TP1 HIT: {symbol} #{ticket} — closing {partial_volume} of {full_volume}")
                    close_result = bridge.partial_close(ticket, partial_volume)
                    if not close_result or "error" in close_result:
                        err = close_result.get("error", "unknown") if close_result else "no response"
                        notifier.send(f"⚠️ TP1 partial close failed for {symbol} #{ticket}: {err}")
                        continue

                    partial_profit = close_result.get("profit", 0)

                    # Spread-aware breakeven buffer
                    if "BTC" in symbol:   be_buffer = 15.0
                    elif "ETH" in symbol: be_buffer = 1.0
                    elif "XAU" in symbol: be_buffer = 1.0
                    elif "JPY" in symbol: be_buffer = 0.04
                    else: be_buffer = 0.0004

                    breakeven_sl = entry + be_buffer if direction == "bullish" else entry - be_buffer

                    modify_result = bridge.modify_sl(ticket, breakeven_sl, new_tp=tp2)
                    if modify_result and "error" not in modify_result:
                        print(f"[{_ts()}] SL moved to breakeven: {breakeven_sl}")
                    else:
                        print(f"[{_ts()}] Breakeven SL modify: {modify_result}")

                    trade_logger.log_partial_close(ticket, partial_profit)
                    pnl_str = str(round(partial_profit, 2))
                    msg = (
                        f"🎯 <b>TP1 HIT — {symbol} #{ticket}</b>\n\n"
                        f"Secured {partial_volume} lot @ 1:{config.TP1_RR} | P&L: <b>+${pnl_str}</b>\n"
                        f"Remaining {round(full_volume - partial_volume, 2)} lot -> SL moved to Breakeven (+buffer)"
                    )
                    notifier.send(msg)
                    print(f"[{_ts()}] {msg}")
                except Exception as e:
                    print(f"[{_ts()}] Partial TP error: {e}")

        # 3. Trailing Stop (15M EMA21) after TP1
        elif config.USE_TRAILING_STOP:
            try:
                df_15m = dp.get_15m(symbol)
                if df_15m is not None and len(df_15m) >= 25:
                    df_15m = strategy.add_indicators(df_15m)
                    ema21_15m = float(df_15m["ema21"].iloc[-2])
                    pip_size = risk_manager.get_pip_size(symbol)
                    buffer_val = config.TRAILING_STOP_BUFFER * pip_size

                    current_sl = pos.get("sl", 0.0)
                    if direction == "bullish":
                        trail_sl = round(ema21_15m - buffer_val, 5)
                        if trail_sl > current_sl and trail_sl > entry:
                            bridge.modify_sl(ticket, trail_sl, new_tp=tp2)
                    else:
                        trail_sl = round(ema21_15m + buffer_val, 5)
                        if (current_sl == 0 or trail_sl < current_sl) and trail_sl < entry:
                            bridge.modify_sl(ticket, trail_sl, new_tp=tp2)
            except Exception as e:
                print(f"[{_ts()}] Trailing stop error: {e}")


def check_ema_invalidation():
    """Checks if any open position has breached 4H EMA21 structure and closes it early."""
    open_tickets = trade_logger.get_open_trade_tickets()
    if not open_tickets:
        return
    live_positions = bridge.get_positions()
    if not live_positions:
        return
    live_by_ticket = {p["ticket"]: p for p in live_positions}

    for ticket in open_tickets:
        trade = trade_logger.get_trade_by_ticket(ticket)
        if not trade or trade_logger.is_partial_closed(ticket):
            continue
        pos = live_by_ticket.get(ticket)
        if not pos:
            continue

        symbol = trade["symbol"]
        direction = trade["direction"]
        df_4h = dp.get_4h(symbol, count=10)
        if df_4h is None or len(df_4h) < 3:
            continue
        df_4h = strategy.add_indicators(df_4h)
        last_close = float(df_4h["close"].iloc[-2])
        last_ema21 = float(df_4h["ema21"].iloc[-2])

        invalidated = (direction == "bullish" and last_close < last_ema21) or \
                      (direction == "bearish" and last_close > last_ema21)

        if invalidated:
            print(f"[{_ts()}] Structural EMA invalidation on {symbol} #{ticket}. Closing early.")
            res = bridge.close_position(ticket)
            if res and "error" not in res:
                notifier.send(f"⚠️ <b>Early Exit ({symbol} #{ticket})</b> — 4H Candle closed against EMA21 trend.")


def run_scan(kill_zone=None):
    acc = bridge.get_account()
    if not acc:
        print(f"[{_ts()}] MT5 bridge offline — scan skipped.")
        return

    balance = acc.get("balance", 0.0)
    if balance < config.MIN_BALANCE:
        print(f"[{_ts()}] Balance ${balance:.2f} < ${config.MIN_BALANCE:.2f} — trading paused.")
        return

    daily_count = trade_logger.get_daily_trade_count()
    if daily_count >= config.MAX_TRADES_DAY:
        print(f"[{_ts()}] Daily trade limit ({config.MAX_TRADES_DAY}) reached. Skipping scan.")
        return

    if kill_zone:
        kz_count = trade_logger.get_kill_zone_trade_count(kill_zone)
        if kz_count >= config.MAX_TRADES_KILL_ZONE:
            print(f"[{_ts()}] Kill zone trade limit ({config.MAX_TRADES_KILL_ZONE}) reached for {kill_zone}.")
            return

    live_positions = bridge.get_positions()
    if live_positions and len(live_positions) >= config.MAX_CONCURRENT:
        print(f"[{_ts()}] Max concurrent positions ({config.MAX_CONCURRENT}) open. Skipping entries.")
        return

    pairs_scanned = 0
    setups_found = 0

    for symbol in config.SYMBOLS:
        pairs_scanned += 1
        print(f"[{_ts()}] Scanning {symbol}...")
        try:
            # 1. [v3.1] Re-Entry Cooldown Filter
            in_cooldown, hours_rem = trade_logger.is_in_cooldown(symbol, config.COOLDOWN_HOURS)
            if in_cooldown:
                print(f"[{_ts()}] {symbol}: In post-loss cooldown ({hours_rem}h remaining). Skipping.")
                continue

            # 2. [v3.1] High-Impact Economic News Filter
            has_news, news_title = news_filter.has_high_impact_news_soon(symbol, config.NEWS_LOOKOUT_MINS)
            if has_news:
                print(f"[{_ts()}] {symbol}: High-impact news upcoming ('{news_title}'). Skipping.")
                notifier.send(f"⏸️ <b>Scan Paused on {symbol}</b> — High-impact news event upcoming: <i>{news_title}</i>.")
                continue

            # 2b. [v3.2] Spread Check — skip if spread is too wide
            if not bridge.spread_ok(symbol):
                print(f"[{_ts()}] {symbol}: Spread too wide. Skipping.")
                continue

            # 3. Market Data Retrieval
            df_w  = dp.get_weekly(symbol)
            df_d  = dp.get_daily(symbol)
            df_4h = dp.get_4h(symbol)
            df_15m = dp.get_15m(symbol)

            if df_w is None or df_d is None or df_4h is None:
                continue

            # 4. Multi-Timeframe Strategy Analysis
            setup = strategy.analyze_pair(
                symbol, df_w, df_d, df_4h, df_15m=df_15m,
                in_kill_zone=(kill_zone is not None),
            )

            if not setup:
                print(f"[{_ts()}] {symbol}: no valid setup.")
                trade_logger.log_scan(symbol, "F", 0, "-", "no_setup")
                continue

            grade = setup["grade"]
            score = setup["score"]
            trade_logger.log_scan(symbol, grade, score, setup["direction"], "setup_found")

            # Grade Gate: A+ or high-scoring B+ for AI confirmation
            is_a_plus = (grade == config.MIN_GRADE)
            is_b_plus_ai_candidate = (getattr(config, "AI_UPGRADE_B_PLUS", False) and grade == "B+" and score >= 80)

            if not (is_a_plus or is_b_plus_ai_candidate):
                print(f"[{_ts()}] {symbol}: Setup found ({grade}, {score} pts), below threshold.")
                continue

            # [v3.2] Dedup — skip if same setup already signaled
            setup_key = (setup["direction"], round(setup.get("swing_eq", 0), 3))
            if _last_signaled.get(symbol) == setup_key:
                print(f"[{_ts()}] {symbol}: Duplicate setup (same direction + swing range). Skipping.")
                continue
            _last_signaled[symbol] = setup_key

            # ── AI Institutional Gatekeeper & Trap Check ──
            if getattr(config, "AI_ENABLED", False):
                print(f"[{_ts()}] 🧠 Querying Dual-AI Engine for {symbol} validation...")
                sym_info = bridge.get_symbol_info(symbol) if hasattr(bridge, "get_symbol_info") else {}
                market_ctx = {
                    "rsi": setup.get("rsi", "N/A"),
                    "adx": setup.get("adx", "N/A"),
                    "spread": sym_info.get("spread", "Normal") if sym_info else "Normal",
                    "news": "Upcoming event monitored" if has_news else "Clean calendar",
                }
                ai_eval = ai_engine.evaluate_setup(setup, market_ctx)
                verdict = ai_eval.get("verdict", "CAUTION")
                conf = ai_eval.get("confidence", 0)
                provider = ai_eval.get("provider", "AI")
                trap = ai_eval.get("trap_detected", False)
                narrative = ai_eval.get("narrative", "")
                trap_warn = ai_eval.get("trap_warning", "None")

                print(f"[{_ts()}] AI Evaluation ({provider}): {verdict} ({conf}% conf) | Trap: {trap}")

                # B+ candidate upgrade gate: requires high conviction (>=85% conf & APPROVED)
                if not is_a_plus:
                    if verdict != "APPROVED" or conf < 85 or trap:
                        print(f"[{_ts()}] {symbol}: B+ setup not upgraded by AI ({verdict}, {conf}% conf). Skipping.")
                        continue
                    print(f"[{_ts()}] 🌟 AI Upgraded B+ setup to Tradeable! ({conf}% conf)")
                    grade = "A+ (AI Confirmed)"
                    setup["grade"] = grade

                # A+ candidate gate: check for traps & minimum confidence
                if trap or verdict == "REJECTED" or conf < getattr(config, "AI_MIN_CONFIDENCE", 70):
                    print(f"[{_ts()}] {symbol}: Filtered by AI Gatekeeper ({verdict}, {conf}% conf, trap={trap}). Skipping.")
                    notifier.send(
                        f"🛡️ <b>AI Gatekeeper Filtered {symbol}</b>\n\n"
                        f"Verdict: <b>{verdict} ({conf}% confidence)</b>\n"
                        f"Trap Warning: <i>{trap_warn}</i>\n"
                        f"Analysis: <i>{narrative}</i>\n"
                        f"<i>Capital protected from high-risk entry.</i>"
                    )
                    continue

                setup["ai_verdict"] = verdict
                setup["ai_conf"] = conf
                setup["ai_narrative"] = narrative
                setup["ai_provider"] = provider

            setups_found += 1

            # 5. Risk-Parity Lot Sizing
            lot, risk_usd, risk_pct, warn = risk_manager.calculate_lot_size(
                symbol, setup["sl_dist"], balance,
            )
            if not lot or lot <= 0:
                print(f"[{_ts()}] {symbol}: Lot calculation rejected — {warn}")
                continue

            # 6. Execute Order via MT5 Bridge
            side = "buy" if setup["direction"] == "bullish" else "sell"
            order_res = bridge.place_order(
                symbol=symbol,
                side=side,
                lot=lot,
                sl=setup["sl"],
                tp=setup["tp2"],
                comment=f"FXAlexG {grade}",
            )

            if order_res and "error" not in order_res:
                ticket = order_res.get("ticket")
                trade_logger.log_trade_opened(setup, lot, risk_usd, ticket)
                adx_info = f" | ADX: {setup.get('adx', 'N/A')}" if 'adx' in setup else ""
                ai_badge = ""
                if "ai_verdict" in setup:
                    ai_badge = (
                        f"\n🧠 <b>AI Verdict ({setup.get('ai_provider', 'AI')}):</b> "
                        f"{setup['ai_verdict']} ({setup.get('ai_conf')}% Conf)\n"
                        f"<i>\"{setup.get('ai_narrative', '')}\"</i>\n"
                    )
                msg = (
                    f"🚀 <b>TRADE OPENED — {symbol}</b>\n\n"
                    f"<b>{side.upper()} {lot} lot</b> @ {order_res.get('price', setup['entry'])}\n"
                    f"SL: <code>{setup['sl']}</code> | TP1: <code>{setup['tp1']}</code> (1:{config.TP1_RR})\n"
                    f"TP2: <code>{setup['tp2']}</code> (1:{config.TP2_RR})\n"
                    f"Risk: <b>${risk_usd:.2f}</b> ({risk_pct}% of balance)\n"
                    f"Grade: <b>{grade}</b> ({score} pts){adx_info}\n"
                    f"{ai_badge}"
                    f"Confluences: <i>{', '.join(setup['met'])}</i>\n"
                    f"Ticket: #{ticket}"
                )
                notifier.send(msg)
                print(f"[{_ts()}] Trade #{ticket} opened successfully.")
            else:
                err = order_res.get("error", "unknown") if order_res else "no response"
                notifier.send(f"❌ Order execution failed for {symbol}: {err}")
                print(f"[{_ts()}] Order execution failed: {err}")

        except Exception as e:
            print(f"[{_ts()}] Scan error on {symbol}: {e}")
            traceback.print_exc()

    # Send scan summary to Telegram after every scan cycle
    open_trades = len(bridge.get_positions() or [])
    week_count = trade_logger.get_daily_trade_count()
    notifier.send_scan_summary(pairs_scanned, setups_found, open_trades, week_count)


def handle_telegram_commands():
    commands = notifier.get_commands()
    for item in commands:
        text = item.get("text", "").strip()
        cmd = item.get("command", "").lower()
        lower_text = text.lower()

        # 1. 1-Tap Button Matching & Common Keywords (No slash required!)
        if "market pulse" in lower_text or lower_text in ("pulse", "market", "macro"):
            _handle_ai_command({"text": "/ai pulse"})
        elif "balance" in lower_text or "account" in lower_text or lower_text == "status" or cmd in ("/account", "/status"):
            _show_account_info()
        elif "gold" in lower_text or "xau" in lower_text:
            _handle_ai_command({"text": "/ai XAUUSDm"})
        elif "eur/usd" in lower_text or "eurusd" in lower_text or lower_text in ("eur", "euro"):
            _handle_ai_command({"text": "/ai EURUSDm"})
        elif "bitcoin" in lower_text or "btc" in lower_text:
            _handle_ai_command({"text": "/ai BTCUSDm"})
        elif "p&l report" in lower_text or "report" in lower_text or "profit" in lower_text or "pnl" in lower_text or cmd == "/report":
            _send_report()
        elif "today's news" in lower_text or lower_text == "news" or cmd == "/news":
            news_msg = news_filter.get_todays_news()
            notifier.send(news_msg)
        elif "switch account" in lower_text or cmd in ("/real", "/demo"):
            current = load_active_account()
            target = "real" if (cmd == "/real" or (current == "demo" and "switch" in lower_text)) else "demo"
            _switch_account(target)
        elif cmd in ("/help", "help", "menu"):
            notifier.send(
                "🤖 <b>FXAlexG Bot — Easy Tap Menu</b>\n\n"
                "No need to type or remember commands! Just tap the buttons at the bottom of your screen:\n\n"
                "• <b>📊 Market Pulse</b> — Live macro breakdown across all 13 pairs\n"
                "• <b>🏦 Balance & Status</b> — Check balance, equity & open trades\n"
                "• <b>🥇 Gold / 💶 EUR/USD / ₿ Bitcoin</b> — Instant AI analysis\n"
                "• <b>📈 P&L Report</b> — Today's and this week's profits\n"
                "• <b>📰 Today's News</b> — High-impact economic calendar\n"
                "• <b>🔄 Switch Account</b> — Toggle between Demo & Real\n\n"
                "💬 <i>You can also just type any question naturally (e.g. 'is gold bullish?' or 'how are my trades?').</i>"
            )
        elif cmd.startswith("/ai"):
            _handle_ai_command(item)
        else:
            # Freeform natural language query to AI Brain
            _handle_ai_command({"text": f"/ai {text}"})


def _handle_ai_command(item):
    text = item.get("text", "").strip()
    parts = text.split()
    arg = parts[1].upper() if len(parts) > 1 else ""

    if not arg or arg in ("HELP", "INFO"):
        notifier.send(
            "🧠 <b>FXAlexG Dual-AI Engine (Gemini + OpenRouter)</b>\n\n"
            "• <code>/ai [pair]</code> — Deep SMC institutional analysis (e.g. <code>/ai EURUSD</code>, <code>/ai BTC</code>, <code>/ai GOLD</code>)\n"
            "• <code>/ai pulse</code> — Macro session sentiment & trend flow\n"
            "• <code>/ai status</code> — Engine latency, active models & settings\n"
            "• <code>/ai [question]</code> — Interactive AI trading advisor\n\n"
            "<i>Dual Engine: Google Gemini 2.5 Flash + OpenRouter DeepSeek</i>"
        )
        return

    if arg == "STATUS":
        notifier.send("⏳ Testing Dual-AI Engine connectivity...")
        try:
            _, prov = ai_engine.query_ai("Ping", "Reply 'OK'")
            notifier.send(
                f"✅ <b>AI Engine Online</b>\n\n"
                f"• Primary Engine: <b>Google Gemini 2.5 Flash</b>\n"
                f"• Fallback Engine: <b>OpenRouter ({ai_engine.OPENROUTER_MODEL})</b>\n"
                f"• Active Responder: <b>{prov}</b>\n"
                f"• Gatekeeper: <b>Active (min {config.AI_MIN_CONFIDENCE}% conf)</b>\n"
                f"• B+ Upgrader: <b>{'Enabled' if config.AI_UPGRADE_B_PLUS else 'Disabled'}</b>"
            )
        except Exception as e:
            notifier.send(f"❌ AI Status Check Failed: {e}")
        return

    if arg in ("PULSE", "MACRO", "SESSION"):
        notifier.send("⏳ Scanning multi-pair macro context with Gemini...")
        try:
            summary_list = []
            for s in config.SYMBOLS[:8]:
                d = dp.get_daily(s, 20)
                if d is not None:
                    p = float(d["close"].iloc[-1])
                    summary_list.append(f"{s}: Price={p:.5f}")
            pulse = ai_engine.generate_session_pulse(summary_list)
            notifier.send(pulse)
        except Exception as e:
            notifier.send(f"❌ Session Pulse Error: {e}")
        return

    # Check if arg matches any tracked symbol
    matched_sym = None
    clean_arg = arg.replace("/", "").replace("M", "")
    for s in config.SYMBOLS:
        s_clean = s.replace("m", "").upper()
        if (clean_arg == s_clean or clean_arg in s_clean or s_clean in clean_arg or
            (clean_arg == "GOLD" and "XAU" in s) or
            (clean_arg == "BTC" and "BTC" in s) or
            (clean_arg == "ETH" and "ETH" in s) or
            (clean_arg == "SOL" and "SOL" in s)):
            matched_sym = s
            break

    if matched_sym:
        notifier.send(f"⏳ Running deep institutional SMC analysis on <b>{matched_sym}</b>...")
        try:
            df_w = dp.get_weekly(matched_sym, count=30)
            df_d = dp.get_daily(matched_sym, count=50)
            df_4h = dp.get_4h(matched_sym, count=50)

            if df_w is None or df_d is None or df_4h is None:
                notifier.send(f"❌ Data feed unavailable for {matched_sym}.")
                return

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
            zones = strategy.find_aoi_zones(df_d, matched_sym)
            nearest = min(zones, key=lambda z: abs(z["mid"] - price)) if zones else None
            zone_pos = "Discount" if price < swing["equilibrium"] else "Premium"
            info = bridge.get_symbol_info(matched_sym) if hasattr(bridge, "get_symbol_info") else {}
            spread = info.get("spread", "N/A") if info else "N/A"

            tf_data = {
                "price": price, "w_bias": w_bias, "d_trend": d_trend,
                "d_ema200_side": "Above EMA200" if price > float(df_d["ema200"].iloc[-1]) else "Below EMA200",
                "h4_bias": h4_bias, "h4_ema21": h4_ema21, "adx": adx, "rsi": rsi,
                "swing_low": round(swing["low"], 5), "swing_high": round(swing["high"], 5),
                "equilibrium": round(swing["equilibrium"], 5), "zone_position": zone_pos,
                "nearest_aoi": round(nearest["mid"], 5) if nearest else "None",
                "spread": spread
            }
            report = ai_engine.analyze_market_pair(matched_sym, tf_data)
            notifier.send(report)
        except Exception as e:
            notifier.send(f"❌ Error analyzing {matched_sym}: {e}")
        return

    # Freeform AI Trading Conversation
    query = text[3:].strip()
    notifier.send("⏳ Consulting AI Brain...")
    try:
        acc = bridge.get_account()
        status_info = {
            "account": config.ACCOUNTS.get(config.ACTIVE_ACCOUNT, {}).get("label", config.ACTIVE_ACCOUNT),
            "balance": acc.get("balance", 0.0) if acc else 0.0,
            "open_trades": len(bridge.get_positions() or []),
            "daily_trades": trade_logger.get_daily_trade_count()
        }
        ans = ai_engine.chat_ai(query, status_info)
        notifier.send(ans)
    except Exception as e:
        notifier.send(f"❌ AI Chat Error: {e}")


def _switch_account(target):
    profile = config.ACCOUNTS.get(target)
    if not profile:
        notifier.send(f"❌ Unknown account profile: {target}")
        return

    positions = bridge.get_positions()
    if positions:
        notifier.send(
            f"⚠️ <b>Cannot switch accounts</b> — {len(positions)} open position(s) active.\n"
            f"Close all trades first, then switch."
        )
        return

    notifier.send(f"🔄 Switching to <b>{profile['label']}</b>...")
    print(f"[{_ts()}] Switching account to {target} ({profile['server']})...")

    result = bridge.switch_account(
        login=profile["login"],
        password=profile["password"],
        server=profile["server"],
    )

    if result and "error" not in result:
        save_active_account(target)
        bal = result.get("balance", 0.0)
        srv = result.get("server", "?")
        lev = result.get("leverage", "?")
        msg = (
            f"✅ <b>Successfully Switched to {profile['label']}</b>\n\n"
            f"Login:    <code>{result.get('login', '?')}</code>\n"
            f"Server:   {srv}\n"
            f"Balance:  <b>${bal:.2f} {result.get('currency', 'USD')}</b>\n"
            f"Leverage: 1:{lev}"
        )
        notifier.send(msg)
        print(f"[{_ts()}] Switched to {target} — Balance: ${bal:.2f}")
    else:
        err = result.get("error", "unknown") if result else "no response"
        notifier.send(f"❌ <b>Account switch failed:</b> {err}")
        print(f"[{_ts()}] Account switch failed: {err}")



def _send_report():
    today = bridge.get_report("today")
    week = bridge.get_report("week")
    
    if "error" in today or "error" in week:
        notifier.send("?????? <b>Report Failed:</b> Could not fetch deals from bridge.")
        return
        
    msg = (
        f"???? <b>Performance Report</b>\n\n"
        f"<b>TODAY:</b>\n"
        f"Profit: ${today.get('profit', 0.0):.2f}\n"
        f"Trades: {today.get('total_trades', 0)} ({today.get('wins', 0)}W - {today.get('losses', 0)}L)\n"
        f"Win Rate: {today.get('winrate', 0.0)}%\n\n"
        f"<b>THIS WEEK:</b>\n"
        f"Profit: ${week.get('profit', 0.0):.2f}\n"
        f"Trades: {week.get('total_trades', 0)} ({week.get('wins', 0)}W - {week.get('losses', 0)}L)\n"
        f"Win Rate: {week.get('winrate', 0.0)}%"
    )
    notifier.send(msg)


def _show_account_info():
    acc = bridge.get_account()
    target = load_active_account()
    profile = config.ACCOUNTS.get(target, {})
    label = profile.get("label", target)
    positions = bridge.get_positions()
    if acc and acc.get("connected"):
        notifier.send(
            f"🏦 <b>Account Information</b>\n\n"
            f"Profile:  <b>{label}</b>\n"
            f"Login:    <code>{acc.get('login', '?')}</code>\n"
            f"Server:   {acc.get('server', '?')}\n"
            f"Balance:  <b>${acc.get('balance', 0.0):.2f} {acc.get('currency', 'USD')}</b>\n"
            f"Equity:   <b>${acc.get('equity', 0.0):.2f}</b>\n"
            f"Leverage: 1:{acc.get('leverage', '?')}\n"
            f"Open Positions: {len(positions) if positions else 0}\n\n"
            f"Quick Switch: /real | /demo"
        )
    else:
        notifier.send("⚠️ MT5 Bridge is currently offline or reconnecting.")


def main():
    print("=" * 60)
    print("  FXAlexG Trading Bot v3.1 — Institutional Strategy Edition")
    print("=" * 60)

    trade_logger.init_db()
    active_acc = load_active_account()
    print(f"[{_ts()}] Active Account Profile: {active_acc}")

    if not notifier._load_chat_id():
        print("⏳ Waiting for Telegram /start to @anonye_trading_bot...")
        while not notifier._load_chat_id():
            notifier.discover_chat_id()
            time.sleep(5)
    print("✅ Telegram bot connected.")

    acc = bridge.get_account()
    if acc and acc.get("connected"):
        bal = acc.get("balance", 0.0)
        print(f"✅ MT5 Bridge online — Account: {acc.get('login')} | Balance: ${bal:.2f}")
        notifier.send_startup(bal, config.SYMBOLS)
    else:
        print(f"⚠️ MT5 Bridge not fully connected at {config.BRIDGE_URL}")
        notifier.send(
            f"🤖 <b>FXAlexG Bot v3.1 Started</b>\n\n"
            f"Active Profile: <b>{active_acc.upper()}</b>\n"
            f"Pairs: {', '.join(config.SYMBOLS)}\n"
            f"Risk: {config.RISK_PERCENT}% per trade | Max/Day: {config.MAX_TRADES_DAY}\n"
            f"Regime: ADX > {config.ADX_MIN} | Cooldown: {config.COOLDOWN_HOURS}h post-loss\n"
            f"TP1: 1:{config.TP1_RR} (50% partial) | TP2: 1:{config.TP2_RR} (trailing)\n"
            f"Commands: /real /demo /account /news /help"
        )

    last_scan_slot  = (-1, -1)
    last_ema_check  = 0.0
    weekly_report_sent = False
    last_tp_check   = 0.0
    last_cmd_check  = 0.0

    while True:
        try:
            now = datetime.now(timezone.utc)
            h, m = now.hour, now.minute

            check_closed_positions()

            # Poll Telegram commands every 5s
            if time.time() - last_cmd_check >= 5:
                handle_telegram_commands()
                last_cmd_check = time.time()

            # Manage open positions (TP1, Trailing SL, TTL) every 15s
            if time.time() - last_tp_check >= 15:
                manage_open_positions()
                last_tp_check = time.time()

            # 4H EMA invalidation check every 15m
            if time.time() - last_ema_check >= 900:
                check_ema_invalidation()
                last_ema_check = time.time()

            # Weekend analysis
            if (now.weekday() == 5 and now.hour == config.WEEKEND_ANALYSIS_HOUR
                    and not weekly_analyst.already_ran_this_week()):
                try:
                    weekly_analyst.run_all(config.SYMBOLS)
                except Exception as e:
                    print(f"[{_ts()}] Weekend analysis error: {e}")

            # Daily Auto News Broadcast (06:00 UTC)
            today_date = now.strftime("%Y-%m-%d")
            if now.hour == 6 and getattr(config, 'last_news_date', '') != today_date:
                try:
                    news_msg = news_filter.get_todays_news()
                    notifier.send(news_msg)
                    config.last_news_date = today_date
                except Exception as e:
                    print(f"[{_ts()}] Auto news error: {e}")

            # Kill Zone & 4H Candle Close Scans
            kz   = current_kill_zone()
            slot = (h, (m // 15) * 15)

            should_scan = False
            if kz:
                if slot != last_scan_slot:
                    should_scan = True
            else:
                if h in config.SCAN_HOURS and m == 0 and slot != last_scan_slot:
                    should_scan = True

            if should_scan:
                label = f"KILL ZONE ({kz.upper()})" if kz else "4H CLOSE"
                print(f"\n[{_ts()}] ── {label} — scanning ──")
                run_scan(kill_zone=kz)
                last_scan_slot = slot

            time.sleep(15)

        except KeyboardInterrupt:
            print("\nStopped.")
            notifier.send("🛑 FXAlexG Bot stopped.")
            break
        except Exception as e:
            print(f"[{_ts()}] LOOP ERROR: {e}")
            notifier.send_error(str(e))
            time.sleep(30)


if __name__ == "__main__":
    main()
