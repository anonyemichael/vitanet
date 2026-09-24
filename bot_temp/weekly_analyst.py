"""
Weekend top-down analysis: W1 → D1 → 4H for each symbol.
Runs once on Saturday at WEEKEND_ANALYSIS_HOUR UTC.
No bridge dependency for scheduling — data comes from the MT5 bridge OHLCV endpoint
(which serves historical data even when forex markets are closed).
"""

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import config
import data_provider as dp
import strategy

BOT_DIR      = Path(__file__).parent
OUTLOOK_FILE = BOT_DIR / "weekly_outlook.json"


# ── Price formatting ──────────────────────────────────────────────────────────

def _fmt(symbol, price):
    if price is None:
        return "N/A"
    if "XAU" in symbol or "BTC" in symbol or "ETH" in symbol:
        return f"{price:,.2f}"
    if "JPY" in symbol:
        return f"{price:.3f}"
    return f"{price:.5f}"


# ── Internal helpers ──────────────────────────────────────────────────────────

def _nearest_zone(aoi_zones, price):
    if not aoi_zones:
        return None
    return min(aoi_zones, key=lambda z: abs(z["mid"] - price))


def _pct_away(zone, price):
    if zone is None or price == 0:
        return None
    return round(abs(zone["mid"] - price) / price * 100, 2)


def _combine_bias(w1_bias, d1_position, h4_bias):
    """Majority vote from W1 structure, D1 position, and 4H EMA side."""
    pos_bias = "bullish" if d1_position == "discount" else "bearish"
    votes = [w1_bias, pos_bias, h4_bias]
    bull = votes.count("bullish")
    bear = votes.count("bearish")
    if bull > bear:
        return "bullish"
    if bear > bull:
        return "bearish"
    return "neutral"


def _watch_direction(overall_bias, d1_position):
    if overall_bias == "bullish" and d1_position == "discount":
        return "LONG"
    if overall_bias == "bearish" and d1_position == "premium":
        return "SHORT"
    return "WAIT"


def _notes(symbol, overall_bias, d1_position, nearest_aoi, current_price):
    direction = _watch_direction(overall_bias, d1_position)
    if direction == "WAIT":
        return "Conflicting signals — no clear directional bias"
    pct = _pct_away(nearest_aoi, current_price)
    if nearest_aoi is None:
        return f"{direction} bias — no AOI zone identified nearby"
    zone_price = _fmt(symbol, nearest_aoi["mid"])
    if pct is not None and pct <= 1.5:
        return f"{direction} setup near — approaching {zone_price} AOI ({pct}% away)"
    if pct is not None and pct <= 5.0:
        return f"{direction} bias — watch {zone_price} AOI ({pct}% away)"
    return f"{direction} bias — nearest zone {zone_price} is {pct}% away"


# ── Main analysis ─────────────────────────────────────────────────────────────

def analyze_symbol(symbol):
    """
    W1 → D1 → 4H top-down analysis.
    Returns structured dict. Raises ValueError if data is unavailable.
    """
    df_w  = dp.get_weekly(symbol, count=52)
    df_d  = dp.get_daily(symbol, count=200)
    df_4h = dp.get_4h(symbol, count=200)

    if df_w is None or df_d is None or df_4h is None:
        raise ValueError(f"data unavailable for {symbol}")

    df_w  = strategy.add_indicators(df_w)
    df_d  = strategy.add_indicators(df_d)
    df_4h = strategy.add_indicators(df_4h)

    current_price = float(df_d["close"].iloc[-1])

    # W1 structure — reuse existing strategy function
    w1_bias = strategy.get_weekly_bias(df_w)

    # D1 equilibrium (premium = above midpoint, discount = below)
    d1_eq       = strategy.get_equilibrium(df_d, n=100)
    d1_position = "premium" if current_price > d1_eq else "discount"

    # D1 AOI zones sorted by proximity to current price
    daily_zones = strategy.find_aoi_zones(df_d, symbol)
    daily_zones.sort(key=lambda z: abs(z["mid"] - current_price))
    nearest_aoi = daily_zones[0] if daily_zones else None

    # Key levels (PDH/PDL/PWH/PWL)
    key_levels = strategy.get_key_levels(df_d, df_w)

    # 4H bias — reuse existing strategy function
    h4_bias  = strategy.get_4h_bias(df_4h)
    ema21_4h = float(df_4h["ema21"].iloc[-1])

    # Overall bias: majority vote
    overall_bias = _combine_bias(w1_bias, d1_position, h4_bias)
    watch_dir    = _watch_direction(overall_bias, d1_position)

    return {
        "symbol":          symbol,
        "current_price":   round(current_price, 5),
        "w1_bias":         w1_bias,
        "d1_eq":           round(d1_eq, 5),
        "d1_position":     d1_position,
        "h4_bias":         h4_bias,
        "ema21_4h":        round(ema21_4h, 5),
        "overall_bias":    overall_bias,
        "watch_direction": watch_dir,
        "aoi_zones":       daily_zones[:5],
        "nearest_aoi":     nearest_aoi,
        "nearest_aoi_pct": _pct_away(nearest_aoi, current_price),
        "key_levels":      key_levels,
        "notes":           _notes(symbol, overall_bias, d1_position, nearest_aoi, current_price),
    }


def run_all(symbols):
    """Run analyze_symbol() for every symbol. Returns {"run_date": ..., "analyses": [...]}"""
    results = []
    for sym in symbols:
        try:
            results.append(analyze_symbol(sym))
        except Exception as e:
            results.append({"symbol": sym, "error": str(e)})
    return {
        "run_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "analyses": results,
    }


# ── Persistence ───────────────────────────────────────────────────────────────

def save(outlook):
    """Atomic write — write to .tmp then rename to avoid JSON corruption."""
    tmp = OUTLOOK_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(outlook, indent=2))
    tmp.replace(OUTLOOK_FILE)


def load():
    """Load weekly_outlook.json. Returns None if missing or unreadable."""
    if not OUTLOOK_FILE.exists():
        return None
    try:
        return json.loads(OUTLOOK_FILE.read_text())
    except Exception:
        return None


def already_ran_this_week():
    """True if weekly_outlook.json was written on this week's Saturday."""
    outlook = load()
    if not outlook:
        return False
    now = datetime.now(timezone.utc)
    # Saturday is weekday 5; find how many days ago the last Saturday was
    days_since_sat = (now.weekday() - 5) % 7
    this_saturday  = (now - timedelta(days=days_since_sat)).strftime("%Y-%m-%d")
    return outlook.get("run_date") == this_saturday
