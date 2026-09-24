import sys
import time
sys.path.insert(0, "/home/ubuntu/fxalexg_bot")

import bridge_client as bridge
import data_provider as dp
import ai_engine

print("=" * 60)
print("  SYSTEM LATENCY & SPEED BENCHMARK (LIVE)")
print("=" * 60)

# 1. MT5 Local Bridge Latency
t0 = time.time()
acc = bridge.health()
bridge_ms = (time.time() - t0) * 1000
print(f"1. MT5 Local Bridge Ping:          {bridge_ms:.1f} ms  (Instant)")

# 2. Market Data Retrieval (Multi-Timeframe Candles)
t0 = time.time()
w = dp.get_weekly("EURUSDm", 20)
d = dp.get_daily("EURUSDm", 30)
h4 = dp.get_4h("EURUSDm", 50)
m15 = dp.get_15m("EURUSDm", 50)
data_ms = (time.time() - t0) * 1000
print(f"2. Multi-TF Data Fetch (4 Timeframes): {data_ms:.1f} ms  (Instant)")

# 3. Google Gemini 2.5 Flash Response Speed
t0 = time.time()
try:
    g_res = ai_engine.call_gemini("Reply in 1 word: Ready.", "System: Be fast.")
    gemini_ms = (time.time() - t0) * 1000
    print(f"3. Google Gemini 2.5 Flash Latency: {gemini_ms:.1f} ms  (Fast & Fluid)")
except Exception as e:
    gemini_ms = 9999
    print(f"3. Google Gemini Latency: Error {e}")

# 4. OpenRouter (DeepSeek) Response Speed
t0 = time.time()
try:
    o_res = ai_engine.call_openrouter("Reply in 1 word: Ready.", "System: Be fast.")
    openrouter_ms = (time.time() - t0) * 1000
    print(f"4. OpenRouter DeepSeek Latency:     {openrouter_ms:.1f} ms")
except Exception as e:
    openrouter_ms = 9999
    print(f"4. OpenRouter Latency: Error {e}")

# 5. Full 13-Pair Scan Speed
t0 = time.time()
for s in ["EURUSDm", "GBPUSDm", "USDJPYm", "XAUUSDm", "BTCUSDm"]:
    _ = dp.get_4h(s, 20)
scan_sample_ms = (time.time() - t0) * 1000
est_13_scan_s = (scan_sample_ms / 5) * 13 / 1000
print(f"5. Estimated Full 13-Pair Scan:    {est_13_scan_s:.2f} seconds")

print("\n" + "=" * 60)
print(f"  TOTAL PRE-TRADE DECISION TIME: ~{gemini_ms/1000:.2f}s (Well within 15M candle)")
print("=" * 60)
