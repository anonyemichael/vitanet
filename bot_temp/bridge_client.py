"""
HTTP client for the MT5 bridge (mt5_bridge.py).
The bridge can be running on:
  - localhost:5001 (local PC or Wine on Oracle)
  - A Cloudflare tunnel URL (bridge on user's PC, exposed to internet)

Set BRIDGE_URL in config.py.
"""

import requests
from config import BRIDGE_URL

TIMEOUT = 12


def health():
    try:
        r = requests.get(f"{BRIDGE_URL}/health", timeout=TIMEOUT)
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def get_account():
    h = health()
    if not h or "error" in h or not h.get("connected"):
        return None
    return h


def get_positions():
    try:
        r = requests.get(f"{BRIDGE_URL}/positions", timeout=TIMEOUT)
        return r.json().get("positions", [])
    except Exception:
        return []


def get_symbol_info(symbol):
    try:
        r = requests.get(f"{BRIDGE_URL}/symbol/{symbol}", timeout=TIMEOUT)
        return r.json()
    except Exception:
        return None


def place_order(symbol, direction=None, lot=0.01, sl=0.0, tp=0.0, side=None, stop_loss=None, take_profit=None, comment="FXAlexG Bot"):
    """
    Place a market order with hard SL and TP.
    Accepts both (symbol, direction, lot, sl, tp) and keyword arguments.
    """
    if side is None:
        if direction in ("bullish", "long", "buy"):
            side = "buy"
        else:
            side = "sell"

    final_sl = stop_loss if stop_loss is not None else sl
    final_tp = take_profit if take_profit is not None else tp

    try:
        r = requests.post(f"{BRIDGE_URL}/order", json={
            "symbol":      symbol,
            "side":        side.lower(),
            "lot":         float(lot),
            "stop_loss":   float(final_sl) if final_sl else 0.0,
            "take_profit": float(final_tp) if final_tp else 0.0,
            "comment":     comment,
        }, timeout=TIMEOUT)
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def spread_ok(symbol):
    """Return True if current spread is within 3x the normal baseline."""
    from config import NORMAL_SPREAD_POINTS, MAX_SPREAD_MULT
    info = get_symbol_info(symbol)
    if not info or "spread" not in info:
        return True
    live_spread = info["spread"]
    baseline    = NORMAL_SPREAD_POINTS.get(symbol, 50)
    return live_spread <= baseline * MAX_SPREAD_MULT


def is_online():
    h = health()
    return h is not None and "error" not in h and h.get("connected", False)


def get_position_result(ticket):
    """Fetch realized P&L for a closed position by its order/position ticket."""
    try:
        r = requests.get(f"{BRIDGE_URL}/history/{ticket}", timeout=TIMEOUT)
        data = r.json()
        return data.get("profit")
    except Exception:
        return None


def close_position(ticket):
    try:
        r = requests.post(f"{BRIDGE_URL}/close", json={"ticket": int(ticket)}, timeout=TIMEOUT)
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def partial_close(ticket, volume):
    """Close a partial volume of a position."""
    try:
        r = requests.post(f"{BRIDGE_URL}/close", json={
            "ticket": int(ticket),
            "volume": float(volume),
        }, timeout=TIMEOUT)
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def modify_sl(ticket, new_sl, new_tp=None):
    """Modify the SL (and optionally TP) of an open position."""
    payload = {"ticket": int(ticket), "stop_loss": float(new_sl)}
    if new_tp is not None:
        payload["take_profit"] = float(new_tp)
    try:
        r = requests.post(f"{BRIDGE_URL}/modify", json=payload, timeout=TIMEOUT)
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def switch_account(login, password, server):
    """Switch MT5 to a different account via the bridge."""
    try:
        r = requests.post(f"{BRIDGE_URL}/switch", json={
            "login": int(login),
            "password": str(password) if password else "",
            "server": str(server),
        }, timeout=30)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def get_report(timeframe="today"):
    """Fetch PnL report for 'today' or 'week'."""
    try:
        r = requests.get(f"{BRIDGE_URL}/report/{timeframe}", timeout=TIMEOUT)
        return r.json()
    except Exception as e:
        return {"error": str(e)}
