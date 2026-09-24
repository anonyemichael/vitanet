"""
Market data via MT5 bridge — pulls directly from MT5 running on Oracle.
No yfinance, no Yahoo rate limits.
"""

import requests
import pandas as pd
from datetime import timezone
import config

# MT5 symbol names (with 'm' suffix as configured on Exness)
SYMBOL_MAP = {
    "EURUSDm": "EURUSDm",
    "GBPUSDm": "GBPUSDm",
    "XAUUSDm": "XAUUSDm",
    "USDJPYm": "USDJPYm",
    "GBPJPYm": "GBPJPYm",
}


def _fetch(symbol, timeframe, count):
    """Call the bridge /ohlcv endpoint and return a clean DataFrame."""
    sym = SYMBOL_MAP.get(symbol, symbol)
    url = f"{config.BRIDGE_URL}/ohlcv/{sym}/{timeframe}/{count}"
    try:
        r = requests.get(url, timeout=15)
        data = r.json()
        if "error" in data:
            print(f"[data] {symbol} {timeframe}: bridge error — {data['error']}")
            return None
        bars = data["bars"]
        df = pd.DataFrame(bars)
        df["time"] = pd.to_datetime(df["time"], unit="s", utc=True)
        df = df.set_index("time")
        df = df[["open", "high", "low", "close", "volume"]].astype(float)
        df.attrs["symbol"] = symbol
        df.attrs["timeframe"] = timeframe
        return df
    except Exception as e:
        print(f"[data] {symbol} {timeframe}: fetch failed — {e}")
        return None


def get_weekly(symbol, count=100):
    return _fetch(symbol, "W1", count)


def get_daily(symbol, count=200):
    return _fetch(symbol, "D1", count)


def get_4h(symbol, count=200):
    return _fetch(symbol, "H4", count)


def get_current_price(symbol):
    sym = SYMBOL_MAP.get(symbol, symbol)
    url = f"{config.BRIDGE_URL}/symbol/{sym}"
    try:
        r = requests.get(url, timeout=10)
        data = r.json()
        # Get live tick price from /symbol/ endpoint
        tick_url = f"{config.BRIDGE_URL}/ohlcv/{sym}/M30/1"
        tr = requests.get(tick_url, timeout=10)
        td = tr.json()
        if "bars" in td and td["bars"]:
            return float(td["bars"][-1]["close"])
    except Exception as e:
        print(f"[data] price fetch failed for {symbol}: {e}")
    return None

def get_15m(symbol, count=200):
    return _fetch(symbol, "M15", count)

