with open('/home/ubuntu/fxalexg_bot/bot.py', 'r') as f:
    content = f.read()

# Patch 1: EMA invalidation closes the trade
OLD_EMA = 'Set & forget: bot alerts but does NOT close early; hard SL handles it.'
NEW_EMA = 'EMA cross = setup invalidated; cut the trade early to protect capital.'

if OLD_EMA not in content:
    print("ERROR: EMA docstring not found")
    exit(1)

content = content.replace(OLD_EMA, NEW_EMA)

OLD_NOTIFY = '''                notifier.send(
                    f"⚠️ <b>EMA INVALIDATION — {symbol}</b>\n\n"
                    f"{side} #{ticket}: price {price:.5f} crossed {cross} 21 EMA ({ema21:.5f})\n\n"
                    f"Setup is invalidated. Hard SL is still in place — set & forget."
                )
                print(f"[{_ts()}] ⚠️ EMA invalidation: {symbol} {side} #{ticket}")'''

NEW_NOTIFY = '''                close_result = bridge.close_position(ticket)
                if close_result and "error" not in close_result:
                    profit = close_result.get("profit", 0)
                    trade_logger.log_trade_closed(ticket, profit)
                    msg = (
                        f"\U0001f534 <b>EMA INVALIDATION — CLOSED {symbol}</b>\n\n"
                        f"{side} #{ticket}: price {price:.5f} crossed {cross} 21 EMA ({ema21:.5f})\n"
                        f"P&L: ${profit:.2f} | Closed early to protect capital."
                    )
                else:
                    err = close_result.get("error", "unknown") if close_result else "no response"
                    msg = (
                        f"\u26a0\ufe0f <b>EMA INVALIDATION — {symbol}</b>\n\n"
                        f"{side} #{ticket}: price {price:.5f} crossed {cross} 21 EMA ({ema21:.5f})\n"
                        f"Auto-close FAILED ({err}) — close manually or let SL handle it."
                    )
                notifier.send(msg)
                print(f"[{_ts()}] EMA invalidation closed: {symbol} {side} #{ticket}")'''

if OLD_NOTIFY not in content:
    print("ERROR: old notify block not found")
    exit(1)

content = content.replace(OLD_NOTIFY, NEW_NOTIFY)

# Patch 2: Add stale re-entry guard before placing order
# Find the spread check line and add re-entry guard before it
OLD_REENTRY = '''            if grade not in ("A+", "B+"):
                continue

            # Spread check — skip if abnormally wide'''

NEW_REENTRY = '''            if grade not in ("A+", "B+"):
                continue

            # Stale setup guard — don't re-enter the same setup within 48h
            if trade_logger.was_setup_traded_recently(symbol, setup["direction"], setup["sl"]):
                msg = f"\u23ed {symbol}: skipping — same setup (SL={setup['sl']}) traded in last 48h"
                print(f"[{_ts()}] {msg}")
                notifier.send(msg)
                continue

            # Spread check — skip if abnormally wide'''

if OLD_REENTRY not in content:
    print("ERROR: reentry anchor not found")
    exit(1)

content = content.replace(OLD_REENTRY, NEW_REENTRY)

with open('/home/ubuntu/fxalexg_bot/bot.py', 'w') as f:
    f.write(content)

print("All patches applied OK")
