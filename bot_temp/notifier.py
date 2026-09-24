"""
Telegram notifications. Sends trade alerts, errors, and daily summaries.
"""

import requests
import json
import os
from datetime import datetime
import config

CHAT_ID_FILE = os.path.join(os.path.dirname(__file__), "chat_id.json")
OFFSET_FILE  = os.path.join(os.path.dirname(__file__), "tg_offset.json")


def _load_chat_id():
    if config.TELEGRAM_CHAT_ID:
        return config.TELEGRAM_CHAT_ID
    if os.path.exists(CHAT_ID_FILE):
        with open(CHAT_ID_FILE) as f:
            data = json.load(f)
            return data.get("chat_id")
    return None


def _save_chat_id(chat_id):
    with open(CHAT_ID_FILE, "w") as f:
        json.dump({"chat_id": chat_id}, f)
    config.TELEGRAM_CHAT_ID = chat_id


def _load_offset():
    if os.path.exists(OFFSET_FILE):
        with open(OFFSET_FILE) as f:
            return json.load(f).get("offset", 0)
    return 0


def _save_offset(offset):
    with open(OFFSET_FILE, "w") as f:
        json.dump({"offset": offset}, f)


def discover_chat_id():
    """Poll getUpdates once and save the first chat ID found."""
    url = f"https://api.telegram.org/bot{config.TELEGRAM_TOKEN}/getUpdates"
    try:
        r = requests.get(url, timeout=10)
        data = r.json()
        for update in data.get("result", []):
            msg = update.get("message") or update.get("edited_message")
            if msg:
                chat_id = msg["chat"]["id"]
                _save_chat_id(chat_id)
                print(f"✅ Chat ID discovered: {chat_id}")
                return chat_id
    except Exception as e:
        print(f"Could not discover chat ID: {e}")
    return None


DEFAULT_KEYBOARD = {
    "keyboard": [
        [{"text": "📊 Market Pulse"}, {"text": "🏦 Balance & Status"}],
        [{"text": "🥇 Gold"}, {"text": "💶 EUR/USD"}, {"text": "₿ Bitcoin"}],
        [{"text": "📈 P&L Report"}, {"text": "📰 Today's News"}, {"text": "🔄 Switch Account"}]
    ],
    "resize_keyboard": True,
    "persistent": True
}


def get_commands():
    """Poll for new Telegram messages and return list of command strings.
    Supports both slash commands and natural language button taps.
    Uses an offset file to avoid processing the same update twice."""
    offset = _load_offset()
    url = f"https://api.telegram.org/bot{config.TELEGRAM_TOKEN}/getUpdates"
    commands = []
    try:
        params = {"timeout": 0}
        if offset:
            params["offset"] = offset
        r = requests.get(url, params=params, timeout=10)
        data = r.json()
        chat_id = _load_chat_id()
        for update in data.get("result", []):
            new_offset = update["update_id"] + 1
            if new_offset > offset:
                offset = new_offset
            msg = update.get("message")
            if not msg:
                continue
            # Only process messages from our chat
            if chat_id and msg["chat"]["id"] != int(chat_id):
                continue
            text = msg.get("text", "").strip()
            if text:
                commands.append({
                    "command": text.split()[0].lower() if text.startswith("/") else text.lower(),
                    "text": text
                })
        _save_offset(offset)
    except Exception as e:
        print(f"Telegram poll error: {e}")
    return commands


def send(text, keyboard=True):
    chat_id = _load_chat_id()
    if not chat_id:
        print(f"[TELEGRAM - no chat_id] {text}")
        return False
    url = f"https://api.telegram.org/bot{config.TELEGRAM_TOKEN}/sendMessage"
    payload = {
        "chat_id":    chat_id,
        "text":       text,
        "parse_mode": "HTML",
    }
    if keyboard:
        payload["reply_markup"] = DEFAULT_KEYBOARD
    try:
        r = requests.post(url, json=payload, timeout=10)
        return r.status_code == 200
    except Exception as e:
        print(f"Telegram send error: {e}")
        return False


def send_trade_opened(setup, lot, risk_usd, risk_pct):
    emoji = "🟢" if setup["direction"] == "bullish" else "🔴"
    side  = "LONG" if setup["direction"] == "bullish" else "SHORT"
    sym   = setup["symbol"]
    confluences = "\n".join(f"  ✅ {c}" for c in setup["met"])
    tag = "DRY RUN — " if config.DRY_RUN else ""
    acct = config.ACCOUNTS.get(config.ACTIVE_ACCOUNT, {}).get("label", config.ACTIVE_ACCOUNT)

    msg = (
        f"{emoji} <b>{tag}TRADE OPENED — {sym} {side}</b>\n\n"
        f"💰 Entry:  <b>{setup['entry']}</b>\n"
        f"🛑 SL:     <b>{setup['sl']}</b>\n"
        f"🎯 TP1:    <b>{setup.get('tp1', 'N/A')}</b>\n"
        f"🎯 TP2:    <b>{setup.get('tp2', setup['tp'])}</b>\n"
        f"📊 RR:     <b>1:{setup['rr']}</b>\n"
        f"📦 Lots:   <b>{lot}</b>\n"
        f"💵 Risk:   <b>${risk_usd} ({risk_pct}%)</b>\n"
        f"⭐ Grade:  <b>{setup['grade']} ({setup['score']}%)</b>\n"
        f"🏦 Account: <b>{acct}</b>\n\n"
        f"<b>Confluences:</b>\n{confluences}\n\n"
        f"⏰ {datetime.utcnow().strftime('%d %b %Y %H:%M')} UTC"
    )
    send(msg)


def send_trade_closed(symbol, direction, result_usd, balance, week_count):
    emoji   = "💚" if result_usd >= 0 else "❤️"
    outcome = "WIN" if result_usd >= 0 else "LOSS"
    sign    = "+" if result_usd >= 0 else ""
    msg = (
        f"{emoji} <b>TRADE CLOSED — {symbol}</b>\n\n"
        f"📈 Result:  <b>{outcome} {sign}${result_usd:.4f}</b>\n"
        f"💼 Balance: <b>${balance:.4f}</b>\n"
        f"📅 Week trades: <b>{week_count}/2 used</b>\n\n"
        f"⏰ {datetime.utcnow().strftime('%d %b %Y %H:%M')} UTC"
    )
    send(msg)


def send_scan_summary(pairs_scanned, setups_found, open_trades, week_count):
    acct = config.ACCOUNTS.get(config.ACTIVE_ACCOUNT, {}).get("label", config.ACTIVE_ACCOUNT)
    msg = (
        f"🔍 <b>SCAN COMPLETE — {datetime.utcnow().strftime('%d %b %Y %H:%M')} UTC</b>\n\n"
        f"Pairs scanned:  {pairs_scanned}\n"
        f"A+/B+ setups:  {setups_found}\n"
        f"Open trades:   {open_trades}\n"
        f"Week trades:   {week_count}/2\n"
        f"Account:       {acct}\n"
    )
    if setups_found == 0:
        msg += "\n⏳ No valid setups — waiting for next 4H close."
    send(msg)


def send_error(error_text):
    send(f"⚠️ <b>BOT ERROR</b>\n\n<code>{error_text[:500]}</code>")


def send_startup(balance, symbols):
    mode = "🔴 DRY RUN (no real trades)" if config.DRY_RUN else "🟢 LIVE TRADING"
    acct = config.ACCOUNTS.get(config.ACTIVE_ACCOUNT, {}).get("label", config.ACTIVE_ACCOUNT)
    msg = (
        f"🤖 <b>FXAlexG Bot v2 STARTED</b>\n\n"
        f"Mode:     {mode}\n"
        f"Account:  {acct}\n"
        f"Balance:  ${balance:.4f}\n"
        f"Pairs:    {', '.join(symbols)}\n"
        f"Risk/trade: {config.RISK_PERCENT}%\n"
        f"Max/day: {config.MAX_TRADES_DAY} | Max/KZ: {config.MAX_TRADES_KILL_ZONE}\n"
        f"TP1: 1:{config.TP1_RR} (50%) | TP2: 1:{config.TP2_RR}\n\n"
        f"Commands: /real /demo /account\n"
        f"⏰ {datetime.utcnow().strftime('%d %b %Y %H:%M')} UTC"
    )
    send(msg)


def send_weekly_outlook(analyses):
    from datetime import timedelta

    def _fmt(symbol, price):
        if price is None:
            return 'N/A'
        if 'XAU' in symbol or 'BTC' in symbol or 'ETH' in symbol:
            return f'{price:,.2f}'
        if 'JPY' in symbol:
            return f'{price:.3f}'
        return f'{price:.5f}'

    now = datetime.utcnow()
    days_until_mon = (7 - now.weekday()) % 7 or 7
    monday_str = (now + timedelta(days=days_until_mon)).strftime('%-d %b')

    lines = [f'📅 <b>WEEKLY OUTLOOK — Week of {monday_str}</b>\n']
    priority = []

    for a in analyses:
        sym = a['symbol']
        if 'error' in a:
            lines.append(f'⚪ <b>{sym}</b> — ⚠️ error: {str(a["error"])[:60]}')
            continue

        bias  = a.get('overall_bias', 'neutral')
        watch = a.get('watch_direction', 'WAIT')
        emoji = '🟢' if bias == 'bullish' else ('🔴' if bias == 'bearish' else '⚪')
        label = 'LONG BIAS' if bias == 'bullish' else ('SHORT BIAS' if bias == 'bearish' else 'WAIT')

        nearest     = a.get('nearest_aoi')
        pct         = a.get('nearest_aoi_pct')
        kl          = a.get('key_levels', {})
        w1          = a.get('w1_bias', '?').title()
        d1_pos      = a.get('d1_position', '?').title()
        h4          = a.get('h4_bias', '?').title()

        block  = f'{emoji} <b>{sym}</b> — {label}\n'
        block += f'  W1: {w1} | D1: {d1_pos} | 4H: {h4}\n'
        if nearest:
            zone_p = _fmt(sym, nearest['mid'])
            block += f'  Zone: {zone_p} ({pct}% away) → {watch}\n'
        kl_parts = [f'{k} {_fmt(sym, v)}' for k, v in kl.items() if k in ('PWH', 'PWL')]
        if kl_parts:
            block += f'  {" | ".join(kl_parts)}\n'
        block += f'  📝 {a.get("notes", "")}'
        lines.append(block)

        if watch != 'WAIT' and pct is not None and pct <= 2.0 and nearest:
            priority.append(f'  • {sym} {watch} @ {_fmt(sym, nearest["mid"])}')

    if priority:
        lines.append('<b>📋 PRIORITY THIS WEEK:</b>\n' + '\n'.join(priority))

    lines.append(f'⏰ {now.strftime("%d %b %Y %H:%M")} UTC')
    msg = '\n\n'.join(lines)

    # Split if over Telegram limit
    if len(msg) > 3800:
        part1 = '\n\n'.join(lines[:len(lines)//2])
        part2 = '\n\n'.join(lines[len(lines)//2:])
        send(part1)
        send(part2)
    else:
        send(msg)
