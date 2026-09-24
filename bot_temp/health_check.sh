#!/bin/bash
echo "=============================================="
echo "  FXAlexG Bot — Full System Health Check"
echo "  $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "=============================================="
echo ""

# 1. Services
echo "=== 1. SYSTEMD SERVICES ==="
echo -n "  mt5-bridge.service:  "; sudo systemctl is-active mt5-bridge.service
echo -n "  fxalexg-bot.service: "; sudo systemctl is-active fxalexg-bot.service
echo ""

# 2. Bridge Health
echo "=== 2. MT5 BRIDGE HEALTH ==="
HEALTH=$(curl -s http://localhost:5001/health)
echo "  $HEALTH"
echo ""

# 3. Account Info
echo "=== 3. ACCOUNT INFO ==="
echo "$HEALTH" | python3 -c '
import sys, json
d = json.load(sys.stdin)
if d.get("connected"):
    print(f"  Login:    {d.get(\"login\")}")
    print(f"  Server:   {d.get(\"server\")}")
    print(f"  Balance:  ${d.get(\"balance\", 0):.2f} {d.get(\"currency\", \"USD\")}")
    print(f"  Equity:   ${d.get(\"equity\", 0):.2f}")
    print(f"  Leverage: 1:{d.get(\"leverage\")}")
    print(f"  Status:   CONNECTED")
else:
    print("  Status: OFFLINE")
'
echo ""

# 4. Positions
echo "=== 4. OPEN POSITIONS ==="
POS=$(curl -s http://localhost:5001/positions)
echo "  $POS"
echo ""

# 5. Symbol Accessibility
echo "=== 5. SYMBOL ACCESSIBILITY ==="
for sym in EURUSDm GBPUSDm USDJPYm AUDUSDm USDCADm EURJPYm GBPJPYm BTCUSDm ETHUSDm XAUUSDm SOLUSDm XRPUSDm LTCUSDm; do
    RESULT=$(curl -s "http://localhost:5001/symbol/$sym")
    SPREAD=$(echo "$RESULT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("spread","ERR"))' 2>/dev/null)
    ERR=$(echo "$RESULT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("error",""))' 2>/dev/null)
    if [ -z "$ERR" ]; then
        echo "  ✅ $sym — spread=$SPREAD"
    else
        echo "  ❌ $sym — ERROR: $ERR"
    fi
done
echo ""

# 6. OHLCV Data
echo "=== 6. OHLCV DATA TEST (EURUSDm H4) ==="
OHLCV=$(curl -s http://localhost:5001/ohlcv/EURUSDm/H4/3)
BARS=$(echo "$OHLCV" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("bars",[])))' 2>/dev/null)
echo "  Bars returned: $BARS (expected 3)"
echo ""

# 7. News Filter
echo "=== 7. NEWS FILTER ==="
cd /home/ubuntu/fxalexg_bot
python3 -c 'import news_filter; print(news_filter.get_todays_news())' 2>&1 | sed 's/^/  /'
echo ""

# 8. PNL Reports
echo "=== 8. PNL REPORTS ==="
echo -n "  Today:  "; curl -s http://localhost:5001/report/today
echo ""
echo -n "  Week:   "; curl -s http://localhost:5001/report/week
echo ""
echo ""

# 9. AutoTrading Config
echo "=== 9. AUTOTRADING CONFIG ==="
python3 -c '
ini = "/home/ubuntu/.wine_exness/drive_c/Program Files/MetaTrader 5/Config/common.ini"
with open(ini, "rb") as f:
    data = f.read()
if data[:2] == b"\xff\xfe":
    text = data[2:].decode("utf-16-le")
else:
    text = data.decode("utf-8", errors="replace")
for line in text.splitlines():
    s = line.strip()
    if s.startswith("Enabled="):
        val = s.split("=")[1]
        if val == "1":
            print("  ✅ Experts Enabled=1 (AutoTrading ON)")
        else:
            print("  ❌ Experts Enabled=0 (AutoTrading OFF)")
        break
'
echo ""

# 10. Telegram
echo "=== 10. TELEGRAM BOT ==="
python3 -c '
import notifier
chat_id = notifier._load_chat_id()
if chat_id:
    print(f"  ✅ Chat ID loaded: {chat_id}")
else:
    print("  ❌ No Chat ID found")
'
echo ""

# 11. Bot Config
echo "=== 11. BOT CONFIG ==="
python3 -c '
import config
print(f"  Symbols:        {len(config.SYMBOLS)} pairs")
print(f"  Risk:           {config.RISK_PERCENT}% per trade")
print(f"  Max/Day:        {config.MAX_TRADES_DAY}")
print(f"  Max Concurrent: {config.MAX_CONCURRENT}")
print(f"  ADX Min:        {config.ADX_MIN}")
print(f"  Cooldown:       {config.COOLDOWN_HOURS}h")
print(f"  TP1 RR:         1:{config.TP1_RR}")
print(f"  TP2 RR:         1:{config.TP2_RR}")
print(f"  Min Grade:      {config.MIN_GRADE}")
'
echo ""

# 12. Recent Bot Logs
echo "=== 12. RECENT BOT LOGS (last 15 lines) ==="
sudo journalctl -u fxalexg-bot.service -n 15 --no-pager 2>&1 | sed 's/^/  /'
echo ""

echo "=============================================="
echo "  HEALTH CHECK COMPLETE"
echo "=============================================="
