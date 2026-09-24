from __future__ import annotations

import json
import logging
import re
import requests
from datetime import datetime

logger = logging.getLogger("ai_engine")

# â”€â”€ API Configurations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
GEMINI_API_KEY = "REDACTED_GEMINI_KEY"
GEMINI_MODEL = "gemini-2.5-flash"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"

OPENROUTER_API_KEY = "REDACTED_OPENROUTER_KEY"
OPENROUTER_MODEL = "deepseek/deepseek-chat"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

TIMEOUT = 15


# â”€â”€ Core AI Calling Functions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def call_gemini(prompt: str, system_instruction: str = "") -> str:
    """Call Google Gemini 2.5 Flash API directly."""
    payload = {
        "contents": [
            {"parts": [{"text": prompt}]}
        ]
    }
    if system_instruction:
        payload["systemInstruction"] = {
            "parts": [{"text": system_instruction}]
        }
    
    r = requests.post(GEMINI_URL, json=payload, timeout=TIMEOUT)
    if r.status_code == 200:
        data = r.json()
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    else:
        raise RuntimeError(f"Gemini API error {r.status_code}: {r.text[:300]}")


def call_openrouter(prompt: str, system_instruction: str = "") -> str:
    """Call OpenRouter API (DeepSeek/Claude)."""
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://fxalexg-bot.trading",
        "X-Title": "FXAlexG Bot"
    }
    messages = []
    if system_instruction:
        messages.append({"role": "system", "content": system_instruction})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": OPENROUTER_MODEL,
        "messages": messages,
        "temperature": 0.2,
        "max_tokens": 1000
    }
    r = requests.post(OPENROUTER_URL, headers=headers, json=payload, timeout=TIMEOUT)
    if r.status_code == 200:
        data = r.json()
        return data["choices"][0]["message"]["content"].strip()
    else:
        raise RuntimeError(f"OpenRouter error {r.status_code}: {r.text[:300]}")


def query_ai(prompt: str, system_instruction: str = "") -> tuple[str, str]:
    """
    Dual-Provider query with automatic failover.
    Returns (response_text, provider_name).
    """
    # 1. Try Gemini first (Primary, lightning fast)
    try:
        res = call_gemini(prompt, system_instruction)
        return res, "Gemini 2.5 Flash"
    except Exception as e:
        logger.warning(f"Gemini failed ({e}), falling back to OpenRouter...")
    
    # 2. Fallback to OpenRouter (Secondary)
    try:
        res = call_openrouter(prompt, system_instruction)
        return res, f"OpenRouter ({OPENROUTER_MODEL})"
    except Exception as e2:
        logger.error(f"Both AI providers failed! OpenRouter error: {e2}")
        raise RuntimeError(f"All AI providers unavailable: {e2}")


# â”€â”€ Specialized Trading Functions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

SYSTEM_QUANT_PROMPT = """You are an elite quantitative institutional FX & Crypto trader and master of the FXAlexG & Smart Money Concepts (SMC) strategy.
You evaluate setups strictly based on:
1. Multi-Timeframe Trend Alignment (Weekly, Daily, 4H)
2. Dealing Range Equilibrium & Optimal Trade Entry (OTE 61.8% - 79% Fibonacci discount for longs, premium for shorts)
3. Liquidity Sweeps, Change of Character (CHoCH), Order Blocks / Areas of Interest (AOI), and Fair Value Gaps (FVG)
4. Traps: Liquidity grabs against the retail crowd, low ADX consolidation chop, upcoming high-impact economic news
5. Risk-to-Reward ratio (minimum 1:2.0 RR)

Be concise, decisive, analytical, and highly protective of capital."""


def evaluate_setup(setup: dict, market_context: dict = None) -> dict:
    """
    AI Pre-Trade Gatekeeper: Evaluates a candidate trade setup before execution.
    Returns a dict with verdict, confidence, narrative, and trap detection.
    """
    sym = setup.get("symbol", "UNKNOWN")
    direction = setup.get("direction", "UNKNOWN").upper()
    entry = setup.get("entry")
    sl = setup.get("sl")
    tp1 = setup.get("tp1")
    tp2 = setup.get("tp2")
    rr = setup.get("rr", "N/A")
    grade = setup.get("grade", "N/A")
    score = setup.get("score", 0)
    confluences = ", ".join(setup.get("met", []))
    adx = setup.get("adx", "N/A")
    trigger = setup.get("trigger", "N/A")

    ctx_str = ""
    if market_context:
        ctx_str = f"""
Additional Market Context:
- ATR: {market_context.get('atr', 'N/A')}
- 4H RSI: {market_context.get('rsi', 'N/A')}
- Distance to nearest AOI: {market_context.get('aoi_dist', 'At AOI')}
- Upcoming Economic News: {market_context.get('news', 'None reported')}
- Spread Points: {market_context.get('spread', 'Normal')}
"""

    prompt = f"""Evaluate this candidate trade setup:

Symbol: {sym}
Direction: {direction}
Entry Price: {entry}
Stop Loss: {sl}
Take Profit 1: {tp1}
Take Profit 2: {tp2}
Risk/Reward Ratio: 1:{rr}
Mechanical Grade: {grade} ({score} points)
Trigger: {trigger}
4H ADX Trend Strength: {adx}
Confluences Detected: {confluences}
{ctx_str}

Analyze this setup and output ONLY a valid JSON object with these exact keys:
{{
  "verdict": "APPROVED" | "REJECTED" | "CAUTION",
  "confidence": <integer 0 to 100>,
  "risk_quality": "HIGH" | "MEDIUM" | "POOR",
  "trap_detected": <true or false>,
  "trap_warning": "<description of any trap or false breakout risk, or 'None'>",
  "narrative": "<2-sentence crisp institutional breakdown of why this setup should or should not be taken>"
}}
Do NOT wrap in markdown code fences. Return raw JSON only."""

    try:
        raw, provider = query_ai(prompt, SYSTEM_QUANT_PROMPT)
        # Clean potential markdown fences
        clean = re.sub(r"^```json\s*", "", raw.strip(), flags=re.MULTILINE)
        clean = re.sub(r"```$", "", clean.strip(), flags=re.MULTILINE)
        result = json.loads(clean)
        result["provider"] = provider
        return result
    except Exception as e:
        logger.error(f"Setup evaluation failed: {e}")
        # Fail-safe fallback: rely on mechanical grade
        return {
            "verdict": "APPROVED" if grade == "A+" else "CAUTION",
            "confidence": 75 if grade == "A+" else 60,
            "risk_quality": "MEDIUM",
            "trap_detected": False,
            "trap_warning": "AI evaluation timed out â€” fallback to mechanical rules",
            "narrative": f"Mechanical {grade} setup with {score} points. Confluences: {confluences}.",
            "provider": "Fallback"
        }


def analyze_market_pair(symbol: str, tf_data: dict) -> str:
    """
    On-Demand Deep Pair Analysis for Telegram /ai <symbol> command.
    """
    prompt = f"""Provide an institutional-grade technical and price action analysis for {symbol}.

Current Market Structure Data:
- Current Price: {tf_data.get('price')}
- Weekly Bias: {tf_data.get('w_bias')}
- Daily Trend: {tf_data.get('d_trend')} (Price vs EMA200: {tf_data.get('d_ema200_side')})
- 4H Bias: {tf_data.get('h4_bias')} (EMA21: {tf_data.get('h4_ema21')})
- 4H ADX: {tf_data.get('adx')} | 4H RSI: {tf_data.get('rsi')}
- Dealing Range: Low={tf_data.get('swing_low')}, High={tf_data.get('swing_high')}, Equilibrium={tf_data.get('equilibrium')}
- Current Position in Range: {tf_data.get('zone_position')} (Discount/Premium)
- Nearest Daily AOI / Order Block: {tf_data.get('nearest_aoi')}
- Spread: {tf_data.get('spread')} points

Structure your response clearly with HTML tags for Telegram:
<b>{symbol} â€” Institutional Market Breakdown</b>
â€¢ <b>Bias & Structure</b>: (W1/D1/4H summary)
â€¢ <b>Key Levels</b>: (Support/Resistance/AOI/Equilibrium)
â€¢ <b>Trade Scenarios</b>: (Bullish trigger vs Bearish trigger)
â€¢ <b>Risk & Trap Warning</b>: (Chop/news/invalidation levels)
â€¢ <b>Actionable Stance</b>: (LONG / SHORT / WAIT)"""

    try:
        raw, provider = query_ai(prompt, SYSTEM_QUANT_PROMPT)
        return raw + f"\n\n<i>Powered by {provider}</i>"
    except Exception as e:
        return f"âŒ AI Analysis error for {symbol}: {str(e)}"


def generate_session_pulse(symbols_summary: list) -> str:
    """
    Generates macro session commentary across scanned pairs.
    """
    summary_text = "\n".join(symbols_summary)
    prompt = f"""Review the current state of tracked Forex, Crypto, and Gold pairs:
{summary_text}

Provide a concise 3-4 sentence Macro Pulse for the trading session:
1. US Dollar & Risk Sentiment (Risk-On vs Risk-Off)
2. Best setup developing right now
3. Key pitfall to avoid today.

Format with bold HTML tags suitable for Telegram."""

    try:
        raw, provider = query_ai(prompt, SYSTEM_QUANT_PROMPT)
        return raw + f"\n\n<i>ðŸ§  Market Pulse by {provider}</i>"
    except Exception as e:
        return f"Market Pulse unavailable: {e}"


def review_trade_outcome(trade: dict) -> str:
    """
    Post-trade review after trade hits TP or SL.
    """
    sym = trade.get("symbol")
    direction = trade.get("direction")
    pnl = trade.get("profit", 0.0)
    outcome = "WIN" if pnl > 0 else "LOSS"

    prompt = f"""Conduct a brief 2-sentence post-trade review:
Symbol: {sym}
Direction: {direction}
Outcome: {outcome} (${pnl:.2f})
Entry: {trade.get('entry')} | Exit: {trade.get('exit_price')}
Planned SL: {trade.get('sl')} | Planned TP: {trade.get('tp')}

Identify the key technical reason this trade {outcome.lower()}ed and one rule for future trades."""

    try:
        raw, provider = query_ai(prompt, SYSTEM_QUANT_PROMPT)
        return raw
    except Exception:
        return f"Trade closed with {outcome} of ${pnl:.2f}."


def chat_ai(user_query: str, bot_status: dict = None) -> str:
    """
    Interactive AI assistant for Telegram /ai <query> command.
    """
    ctx = ""
    if bot_status:
        ctx = f"""Current Bot Status:
- Active Account: {bot_status.get('account')}
- Balance: ${bot_status.get('balance', 0):.2f}
- Open Positions: {bot_status.get('open_trades', 0)}
- Trades Today: {bot_status.get('daily_trades', 0)}
"""

    prompt = f"""{ctx}
User asks: {user_query}

Respond as the AI Brain of the FXAlexG Trading Bot. Be helpful, concise, and focused on trading and performance. Use Telegram HTML formatting."""

    try:
        raw, provider = query_ai(prompt, SYSTEM_QUANT_PROMPT)
        return raw + f"\n\n<i>ðŸ¤– {provider}</i>"
    except Exception as e:
        return f"âŒ AI Assistant error: {e}"


# â”€â”€ Self-Test â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

if __name__ == "__main__":
    print("Testing Dual-AI Trading Engine...")
    test_setup = {
        "symbol": "EURUSDm",
        "direction": "bullish",
        "entry": 1.1610,
        "sl": 1.1580,
        "tp1": 1.1640,
        "tp2": 1.1700,
        "rr": 3.0,
        "grade": "A+",
        "score": 96,
        "trigger": "15m_choch",
        "adx": 28.5,
        "met": ["Key AOI", "Swing Discount/Premium", "3TF Sync", "4H EMA21 ok", "15M CHoCH Mitigation"]
    }
    evaluation = evaluate_setup(test_setup)
    print("Setup Evaluation Result:")
    print(json.dumps(evaluation, indent=2))
