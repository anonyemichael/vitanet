import requests
import config

print(f"{'SYMBOL':<10} | {'LIVE SPREAD':<12} | {'CONFIG BASELINE':<15} | {'MAX ALLOWED':<12} | {'SPREAD OK':<10}")
print("-" * 70)

for sym in config.SYMBOLS:
    try:
        r = requests.get(f"http://localhost:5001/symbol/{sym}", timeout=5)
        if r.status_code == 200:
            data = r.json()
            spread = data.get("spread", 0)
            baseline = config.NORMAL_SPREAD_POINTS.get(sym, 50)
            max_allowed = baseline * config.MAX_SPREAD_MULT
            ok = spread <= max_allowed
            print(f"{sym:<10} | {spread:<12} | {baseline:<15} | {max_allowed:<12} | {str(ok):<10}")
        else:
            print(f"{sym:<10} | HTTP {r.status_code}")
    except Exception as e:
        print(f"{sym:<10} | Error: {e}")
