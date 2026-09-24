import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import notifier

msg = (
    "✨ <b>Telegram 1-Tap Interactive Menu is Live!</b>\n\n"
    "You <b>never have to memorize or type slash commands</b> again!\n\n"
    "👇 <b>Just tap the buttons at the bottom of your screen:</b>\n"
    "• <b>[ 📊 Market Pulse ]</b> — Macro session breakdown\n"
    "• <b>[ 🏦 Balance & Status ]</b> — Check live balance & equity\n"
    "• <b>[ 🥇 Gold ]</b> / <b>[ 💶 EUR/USD ]</b> / <b>[ ₿ Bitcoin ]</b> — Instant AI analysis\n"
    "• <b>[ 📈 P&L Report ]</b> — Today & week's profits\n"
    "• <b>[ 📰 Today's News ]</b> — High-impact economic calendar\n"
    "• <b>[ 🔄 Switch Account ]</b> — Toggle between Demo & Real\n\n"
    "💬 <i>You can also just talk to me in normal English (e.g. 'is gold bullish?' or 'how are my trades?').</i>"
)

res = notifier.send(msg)
print("Menu Sent:", res)
