import sys
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")
import notifier

msg = (
    "🧠 <b>FXAlexG Dual-AI Institutional Engine Online!</b>\n\n"
    "• <b>Primary Brain:</b> Google Gemini 2.5 Flash\n"
    "• <b>Reasoning Brain:</b> OpenRouter (DeepSeek)\n"
    "• <b>Pre-Trade Gatekeeper:</b> Active (Trap detection & setup confirmation)\n"
    "• <b>Gold Spread Filter:</b> Fixed & active\n\n"
    "<b>Try new commands in Telegram:</b>\n"
    "• <code>/ai EURUSD</code> or <code>/ai GOLD</code> — Deep SMC analysis\n"
    "• <code>/ai pulse</code> — Live session macro breakdown\n"
    "• <code>/ai status</code> — Dual-AI engine latency & health\n"
    "• <code>/ai [question]</code> — Freeform trading advisor"
)
success = notifier.send(msg)
print("Telegram Notification Sent:", success)
