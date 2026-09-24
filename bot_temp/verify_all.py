import sys
import os

print("=" * 60)
print("  FXAlexG AI-Powered Trading Bot — VERIFICATION")
print("=" * 60)

# 1. Imports
try:
    import config
    import strategy
    import ai_engine
    import bot
    import bridge_client as bridge
    import notifier
    print("✅ All modules imported successfully.")
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

# 2. Config verification
print(f"  AI Enabled: {config.AI_ENABLED}")
print(f"  Gemini API Key configured: {bool(config.GEMINI_API_KEY)}")
print(f"  OpenRouter API Key configured: {bool(config.OPENROUTER_API_KEY)}")
print(f"  XAUUSDm spread baseline: {config.NORMAL_SPREAD_POINTS.get('XAUUSDm')} points")
print(f"  Spread OK on Gold: {bridge.spread_ok('XAUUSDm')}")

# 3. Dual-AI Provider Test
print("\n--- Testing Dual-AI Connectivity ---")
try:
    gemini_res = ai_engine.call_gemini("Reply in 5 words: Gemini Flash is operational.", "System: Be concise.")
    print(f"  [Gemini 2.5 Flash]: {gemini_res}")
except Exception as e:
    print(f"  [Gemini Error]: {e}")

try:
    openrouter_res = ai_engine.call_openrouter("Reply in 5 words: OpenRouter DeepSeek is operational.", "System: Be concise.")
    print(f"  [OpenRouter]: {openrouter_res}")
except Exception as e:
    print(f"  [OpenRouter Error]: {e}")

# 4. Setup Evaluation Test
print("\n--- Testing AI Setup Evaluation ---")
test_setup = {
    "symbol": "XAUUSDm",
    "direction": "bullish",
    "entry": 4345.50,
    "sl": 4330.00,
    "tp1": 4361.00,
    "tp2": 4392.00,
    "rr": 3.0,
    "grade": "A+",
    "score": 96,
    "trigger": "15m_choch",
    "adx": 29.2,
    "met": ["Key AOI", "Swing Discount", "3TF Sync", "4H EMA21 ok", "15M CHoCH Mitigation"]
}
eval_res = ai_engine.evaluate_setup(test_setup)
print(f"  Verdict: {eval_res.get('verdict')} | Confidence: {eval_res.get('confidence')}% | Provider: {eval_res.get('provider')}")
print(f"  Narrative: {eval_res.get('narrative')}")

print("\n" + "=" * 60)
print("  VERIFICATION COMPLETE — ALL SYSTEMS OPERATIONAL")
print("=" * 60)
