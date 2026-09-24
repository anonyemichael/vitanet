with open('/home/ubuntu/fxalexg_bot/bot.py', 'r') as f:
    content = f.read()

# Find and replace the notify block (using byte-exact match from repr output)
OLD = (
    '                notifier.send(\n'
    '                    f"⚠️ <b>EMA INVALIDATION — {symbol}</b>\n\n"\n'
    '                    f"{side} #{ticket}: price {price:.5f} crossed {cross} 21 EMA ({ema21:.5f})\n\n"\n'
    '                    f"Setup is invalidated. Hard SL is still in place — set & forget."\n'
    '                )\n'
    '                print(f"[{_ts()}] ⚠️ EMA invalidation: {symbol} {side} #{ticket}")'
)

NEW = (
    '                close_result = bridge.close_position(ticket)\n'
    '                if close_result and "error" not in close_result:\n'
    '                    profit = close_result.get("profit", 0)\n'
    '                    trade_logger.log_trade_closed(ticket, profit)\n'
    '                    msg = (\n'
    '                        f"\U0001f534 <b>EMA INVALIDATION — CLOSED {symbol}</b>\n\n"\n'
    '                        f"{side} #{ticket}: price {price:.5f} crossed {cross} 21 EMA ({ema21:.5f})\n"\n'
    '                        f"P&L: ${profit:.2f} | Closed early to protect capital."\n'
    '                    )\n'
    '                else:\n'
    '                    err = close_result.get("error", "unknown") if close_result else "no response"\n'
    '                    msg = (\n'
    '                        f"⚠️ <b>EMA INVALIDATION — {symbol}</b>\n\n"\n'
    '                        f"{side} #{ticket}: price {price:.5f} crossed {cross} 21 EMA ({ema21:.5f})\n"\n'
    '                        f"Auto-close FAILED ({err}) — close manually or let SL handle it."\n'
    '                    )\n'
    '                notifier.send(msg)\n'
    '                print(f"[{_ts()}] EMA invalidation closed: {symbol} {side} #{ticket}")'
)

if OLD not in content:
    print("ERROR: old EMA notify not found — searching fragments")
    print(repr(content[content.find('ema_alerted.add'):content.find('ema_alerted.add')+500]))
    exit(1)

content = content.replace(OLD, NEW)

# Patch 2: stale re-entry guard
OLD2 = (
    '            if grade not in ("A+", "B+"):\n'
    '                continue\n'
    '\n'
    '            # Spread check — skip if abnormally wide'
)
NEW2 = (
    '            if grade not in ("A+", "B+"):\n'
    '                continue\n'
    '\n'
    '            # Stale setup guard — don\'t re-enter the same setup within 48h\n'
    '            if trade_logger.was_setup_traded_recently(symbol, setup["direction"], setup["sl"]):\n'
    '                msg = f"⏭ {symbol}: skipping — same setup (SL={setup[\'sl\']}) traded in last 48h"\n'
    '                print(f"[{_ts()}] {msg}")\n'
    '                notifier.send(msg)\n'
    '                continue\n'
    '\n'
    '            # Spread check — skip if abnormally wide'
)

if OLD2 not in content:
    print("ERROR: grade anchor not found")
    exit(1)

content = content.replace(OLD2, NEW2)

with open('/home/ubuntu/fxalexg_bot/bot.py', 'w') as f:
    f.write(content)

print("All patches applied OK")
