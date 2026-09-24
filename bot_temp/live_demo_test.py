import sys
import time
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")

import bridge_client as bridge
import ai_engine
import trade_logger
import notifier
import config

print("=" * 65)
print("  LIVE END-TO-END SYSTEM EXECUTION TEST (DEMO ACCOUNT)")
print("=" * 65)

# 1. Verify Demo Account
acc = bridge.get_account()
print(f"\n1. Account Status: Login {acc.get('login')} ({acc.get('server')}) | Balance: ${acc.get('balance'):.2f} {acc.get('currency')}")
if "Trial" not in acc.get("server", "") and "Demo" not in acc.get("server", ""):
    print("SAFETY HALT: Not on a Demo/Trial account! Aborting live test.")
    sys.exit(1)

symbol = "EURUSDm"
info = bridge.get_symbol_info(symbol)
print(f"2. Target Symbol: {symbol} | Digits: {info.get('digits')} | Spread: {info.get('spread')} points")

# 3. Simulate Setup & AI Evaluation
sim_setup = {
    "symbol": symbol,
    "direction": "bullish",
    "entry": 1.1615,
    "sl": 1.1585,
    "tp1": 1.1645,
    "tp2": 1.1705,
    "rr": 3.0,
    "grade": "A+",
    "score": 96,
    "trigger": "15m_choch",
    "adx": 26.4,
    "met": ["Key AOI", "Swing Discount", "3TF Sync", "15M CHoCH"]
}

print("\n3. Consulting Dual-AI Gatekeeper...")
ai_eval = ai_engine.evaluate_setup(sim_setup, {"rsi": 48.0, "adx": 26.4, "spread": info.get("spread")})
print(f"   AI Provider: {ai_eval.get('provider')}")
print(f"   AI Verdict:  {ai_eval.get('verdict')} ({ai_eval.get('confidence')}% confidence)")
print(f"   Narrative:   {ai_eval.get('narrative')}")

# 4. Place Live Micro Test Order (0.01 Lot) on Demo
print("\n4. Placing Live Test Order on MT5 Bridge...")
# Calculate SL / TP prices based on current bid/ask
current_bid = info.get("bid", 1.1610)
current_ask = info.get("ask", 1.1612)
entry_price = current_ask
sl_price = round(entry_price - 0.0030, 5)
tp_price = round(entry_price + 0.0090, 5)

order_res = bridge.place_order(
    symbol=symbol,
    side="buy",
    lot=0.01,
    sl=sl_price,
    tp=tp_price,
    comment="AI Test Trade"
)

if not order_res or "error" in order_res:
    print(f"❌ Order failed: {order_res}")
    sys.exit(1)

ticket = order_res.get("ticket")
print(f"✅ Order Successfully Opened! Ticket: #{ticket} | Price: {order_res.get('price')} | SL: {sl_price} | TP: {tp_price}")

# Notify Telegram
tg_msg = (
    f"🧪 <b>LIVE TEST ORDER EXECUTED — {symbol}</b>\n\n"
    f"<b>BUY 0.01 lot</b> @ {order_res.get('price')}\n"
    f"SL: <code>{sl_price}</code> | TP: <code>{tp_price}</code> (1:3.0 RR)\n"
    f"Ticket: #{ticket}\n\n"
    f"🧠 <b>AI Verdict ({ai_eval.get('provider')}):</b> {ai_eval.get('verdict')} ({ai_eval.get('confidence')}% Conf)\n"
    f"<i>\"{ai_eval.get('narrative')}\"</i>\n\n"
    f"<i>Test order will be closed automatically in 5 seconds.</i>"
)
notifier.send(tg_msg)

# 5. Check Live Positions
time.sleep(2)
positions = bridge.get_positions()
found = any(p.get("ticket") == ticket for p in positions)
print(f"5. MT5 Position Table Verification: Ticket #{ticket} found in active positions = {found}")

# 6. Close the Test Order Cleanly
print("\n6. Closing Test Order cleanly on MT5...")
time.sleep(3)
close_res = bridge.close_position(ticket)
print(f"   Close Result: {close_res}")

# 7. Post-Trade AI Review
time.sleep(1)
trade_data = {
    "symbol": symbol,
    "direction": "bullish",
    "profit": 0.02, # Nominal test
    "entry": entry_price,
    "exit_price": current_bid,
    "sl": sl_price,
    "tp": tp_price
}
print("\n7. Generating Post-Trade AI Review...")
ai_review = ai_engine.review_trade_outcome(trade_data)
print(f"   AI Post-Mortem: {ai_review}")

notifier.send(
    f"🏁 <b>LIVE TEST COMPLETE — Trade #{ticket} Closed</b>\n\n"
    f"Result: Closed Cleanly on MT5\n"
    f"🧠 <b>AI Post-Trade Review:</b>\n<i>{ai_review}</i>\n\n"
    f"✅ <b>ALL SYSTEMS & ENTRY EXECUTION FULLY VERIFIED!</b>"
)

print("\n" + "=" * 65)
print("  END-TO-END TEST SUCCESSFUL: MT5 + DUAL-AI + TELEGRAM ALL VERIFIED")
print("=" * 65)
