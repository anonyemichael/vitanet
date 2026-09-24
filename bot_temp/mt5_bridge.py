"""
MT5 Bridge — local HTTP server connecting trading bot to MetaTrader 5.
Runs under Wine on Linux or natively on Windows.

Features:
  - Reliable account switching (Demo <-> Real) with password & profile fallback
  - Order execution (Market, SL/TP, Partial Close, Modify SL/TP)
  - Live positions, account info, and history deals
  - Multi-timeframe OHLCV bar retrieval (M1, M5, M15, M30, H1, H4, D1, W1)
"""

import sys
import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import MetaTrader5 as mt5

PORT = 5001


def init_mt5():
    if not mt5.initialize():
        print(f"MT5 init failed: {mt5.last_error()}")
        return False
    account = mt5.account_info()
    if not account:
        print(f"Cannot read account: {mt5.last_error()}")
        return False
    print("=" * 55)
    print("  MT5 Bridge Online")
    print(f"  Account : {account.login} ({account.server})")
    print(f"  Balance : {account.balance} {account.currency} | Equity: {account.equity}")
    print(f"  Leverage: 1:{account.leverage}")
    print("=" * 55)
    return True


def get_account_dict():
    acc = mt5.account_info()
    if not acc:
        return None
    return {
        "status":    "ok",
        "connected": True,
        "balance":   acc.balance,
        "equity":    acc.equity,
        "currency":  acc.currency,
        "server":    acc.server,
        "login":     acc.login,
        "leverage":  acc.leverage,
        "margin_free": acc.margin_free,
    }


def get_positions():
    positions = mt5.positions_get()
    if positions is None:
        return []
    res = []
    for p in positions:
        res.append({
            "ticket":        p.ticket,
            "symbol":        p.symbol,
            "type":          "buy" if p.type == mt5.ORDER_TYPE_BUY else "sell",
            "volume":        p.volume,
            "open_price":    p.price_open,
            "current_price": p.price_current,
            "sl":            p.sl,
            "tp":            p.tp,
            "profit":        p.profit,
            "time":          p.time,
            "comment":       p.comment,
        })
    return res


def do_order(symbol, side, lot=0.01, price=None, stop_loss=0.0, take_profit=0.0, comment="FXAlexG Bot"):
    mt5.symbol_select(symbol, True)
    info = mt5.symbol_info(symbol)
    if not info:
        raise ValueError(f"Symbol not found: {symbol}")

    tick = mt5.symbol_info_tick(symbol)
    if not tick:
        raise ValueError(f"Cannot get tick for: {symbol}")

    order_type = mt5.ORDER_TYPE_BUY if side.lower() == "buy" else mt5.ORDER_TYPE_SELL
    req_price = tick.ask if side.lower() == "buy" else tick.bid

    # Clamp lot size to broker constraints
    step = info.volume_step if info.volume_step > 0 else 0.01
    vol = round(round(float(lot) / step) * step, 2)
    vol = max(info.volume_min, min(info.volume_max, vol))

    req = {
        "action":       mt5.TRADE_ACTION_DEAL,
        "symbol":       symbol,
        "volume":       vol,
        "type":         order_type,
        "price":        req_price,
        "sl":           float(stop_loss) if stop_loss else 0.0,
        "tp":           float(take_profit) if take_profit else 0.0,
        "deviation":    20,
        "magic":        10101,
        "comment":      comment,
        "type_time":    mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(req)
    if not result:
        raise RuntimeError(f"Order send returned None: {mt5.last_error()}")

    if result.retcode != mt5.TRADE_RETCODE_DONE:
        # Retry with FOK filling if IOC failed
        if result.retcode in (10030, 10031):
            req["type_filling"] = mt5.ORDER_FILLING_FOK
            result = mt5.order_send(req)

        if result.retcode != mt5.TRADE_RETCODE_DONE:
            raise RuntimeError(f"Order failed (code {result.retcode}): {result.comment}")

    print(f"  ORDER EXECUTED: {side.upper()} {vol} {symbol} @ {result.price} (Ticket #{result.order})")
    return {
        "ticket": result.order,
        "deal":   result.deal,
        "volume": result.volume,
        "price":  result.price,
        "symbol": symbol,
        "side":   side,
    }


def close_position(ticket, volume=None):
    positions = mt5.positions_get(ticket=ticket)
    if not positions:
        raise ValueError(f"Position {ticket} not found")
    pos = positions[0]

    mt5.symbol_select(pos.symbol, True)
    tick = mt5.symbol_info_tick(pos.symbol)
    if not tick:
        raise ValueError(f"Cannot get tick for {pos.symbol}")

    close_side = mt5.ORDER_TYPE_SELL if pos.type == mt5.ORDER_TYPE_BUY else mt5.ORDER_TYPE_BUY
    close_price = tick.bid if pos.type == mt5.ORDER_TYPE_BUY else tick.ask

    close_vol = float(volume) if volume else pos.volume
    close_vol = min(close_vol, pos.volume)

    req = {
        "action":       mt5.TRADE_ACTION_DEAL,
        "symbol":       pos.symbol,
        "volume":       close_vol,
        "type":         close_side,
        "position":     ticket,
        "price":        close_price,
        "deviation":    20,
        "magic":        10101,
        "comment":      "Partial Close" if close_vol < pos.volume else "Close Position",
        "type_time":    mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(req)
    if not result:
        raise RuntimeError(f"Close order returned None: {mt5.last_error()}")

    if result.retcode != mt5.TRADE_RETCODE_DONE:
        if result.retcode in (10030, 10031):
            req["type_filling"] = mt5.ORDER_FILLING_FOK
            result = mt5.order_send(req)
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            raise RuntimeError(f"Close failed (code {result.retcode}): {result.comment}")

    print(f"  CLOSED: {close_vol} of {pos.volume} lot on #{ticket} @ {result.price}")
    return {
        "closed_ticket": ticket,
        "price":         result.price,
        "profit":        pos.profit,
        "volume_closed": close_vol,
        "partial":       close_vol < pos.volume,
    }


def modify_position(ticket, stop_loss=None, take_profit=None):
    positions = mt5.positions_get(ticket=ticket)
    if not positions:
        raise ValueError(f"Position {ticket} not found")
    pos = positions[0]

    new_sl = float(stop_loss) if stop_loss is not None else pos.sl
    new_tp = float(take_profit) if take_profit is not None else pos.tp

    req = {
        "action":   mt5.TRADE_ACTION_SLTP,
        "symbol":   pos.symbol,
        "position": ticket,
        "sl":       new_sl,
        "tp":       new_tp,
    }

    result = mt5.order_send(req)
    if not result or result.retcode != mt5.TRADE_RETCODE_DONE:
        err_code = result.retcode if result else mt5.last_error()
        err_msg = result.comment if result else "No response"
        raise RuntimeError(f"Modify SL/TP failed (code {err_code}): {err_msg}")

    print(f"  MODIFY SL/TP: Ticket #{ticket} {pos.symbol} -> SL: {new_sl}, TP: {new_tp}")
    return {"ticket": ticket, "sl": new_sl, "tp": new_tp}


def switch_account(login, password, server):
    """Reliably disconnect from current MT5 account and reconnect to specified profile."""
    print(f"  SWITCH REQUEST: Login {login} @ {server}")
    
    login_int = int(login)
    server_str = str(server).strip()
    pw_str = str(password).strip() if password else ""

    # Try login directly if initialized
    authorized = False
    if pw_str:
        authorized = mt5.login(login_int, password=pw_str, server=server_str)
    else:
        authorized = mt5.login(login_int, server=server_str)

    if not authorized:
        # Re-initialize MT5 with new credentials
        print(f"  Direct login returned False ({mt5.last_error()}), re-initializing...")
        mt5.shutdown()
        time.sleep(1)
        if pw_str:
            if not mt5.initialize(login=login_int, password=pw_str, server=server_str):
                raise RuntimeError(f"MT5 initialize failed for {login_int}@{server_str}: {mt5.last_error()}")
        else:
            if not mt5.initialize(login=login_int, server=server_str):
                # Fallback initialize without parameters
                if not mt5.initialize():
                    raise RuntimeError(f"MT5 base initialize failed: {mt5.last_error()}")
                if not mt5.login(login_int, server=server_str):
                    raise RuntimeError(f"MT5 login failed for {login_int}@{server_str}: {mt5.last_error()}")

    acc = mt5.account_info()
    if not acc:
        raise RuntimeError(f"Cannot read account info after switch: {mt5.last_error()}")

    print(f"  SWITCHED SUCCESSFULLY: Account {acc.login} ({acc.server}) | Balance: ${acc.balance:.2f} {acc.currency}")
    return {
        "login":    acc.login,
        "server":   acc.server,
        "balance":  acc.balance,
        "equity":   acc.equity,
        "currency": acc.currency,
        "leverage": acc.leverage,
    }


def get_symbol_info(symbol):
    mt5.symbol_select(symbol, True)
    info = mt5.symbol_info(symbol)
    if not info:
        return {"error": f"Symbol not found: {symbol}"}
    return {
        "symbol":          info.name,
        "description":     info.description,
        "digits":          info.digits,
        "spread":          info.spread,
        "contract_size":   info.trade_contract_size,
        "volume_min":      info.volume_min,
        "volume_max":      info.volume_max,
        "volume_step":     info.volume_step,
        "tick_size":       info.trade_tick_size,
        "tick_value":      info.trade_tick_value,
        "currency_base":   info.currency_base,
        "currency_profit": info.currency_profit,
    }


def get_ohlcv(symbol, timeframe_str, count):
    tf_map = {
        "M1":  mt5.TIMEFRAME_M1,
        "M5":  mt5.TIMEFRAME_M5,
        "M15": mt5.TIMEFRAME_M15,
        "M30": mt5.TIMEFRAME_M30,
        "H1":  mt5.TIMEFRAME_H1,
        "H4":  mt5.TIMEFRAME_H4,
        "D1":  mt5.TIMEFRAME_D1,
        "W1":  mt5.TIMEFRAME_W1,
        "MN1": mt5.TIMEFRAME_MN1,
    }
    tf = tf_map.get(timeframe_str.upper())
    if tf is None:
        return {"error": f"Invalid timeframe: {timeframe_str}"}

    mt5.symbol_select(symbol, True)
    rates = mt5.copy_rates_from_pos(symbol, tf, 0, int(count))
    if rates is None or len(rates) == 0:
        return {"error": "not found"}

    bars = []
    for r in rates:
        bars.append({
            "time":   int(r["time"]),
            "open":   float(r["open"]),
            "high":   float(r["high"]),
            "low":    float(r["low"]),
            "close":  float(r["close"]),
            "volume": float(r["tick_volume"]),
        })
    return {"bars": bars}



import datetime as dt

def get_pnl_report(timeframe):
    now = dt.datetime.now(dt.timezone.utc)
    if timeframe == "today":
        date_from = dt.datetime(now.year, now.month, now.day, tzinfo=dt.timezone.utc)
    elif timeframe == "week":
        monday = now - dt.timedelta(days=now.weekday())
        date_from = dt.datetime(monday.year, monday.month, monday.day, tzinfo=dt.timezone.utc)
    else:
        return {"error": "Invalid timeframe"}
    
    date_to = now + dt.timedelta(days=1)
    
    deals = mt5.history_deals_get(date_from, date_to)
    if deals is None:
        return {"error": "not found"}
        
    profit = 0.0
    wins = 0
    losses = 0
    
    for d in deals:
        if getattr(d, 'entry', -1) == 1: # DEAL_ENTRY_OUT
            net = d.profit + getattr(d, 'swap', 0.0) + getattr(d, 'commission', 0.0)
            if net > 0:
                wins += 1
            elif net < 0:
                losses += 1
            profit += net
            
    total = wins + losses
    winrate = round((wins / total * 100), 1) if total > 0 else 0.0
    
    return {
        "profit": round(profit, 2),
        "wins": wins,
        "losses": losses,
        "winrate": winrate,
        "total_trades": total
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send_json(self, code, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self):
        try:
            if self.path == "/health":
                acc = get_account_dict()
                if acc:
                    self.send_json(200, acc)
                else:
                    self.send_json(200, {"status": "offline", "connected": False})
            elif self.path == "/positions":
                self.send_json(200, {"positions": get_positions()})
            elif self.path.startswith("/symbol/"):
                symbol = self.path.split("/symbol/")[1]
                self.send_json(200, get_symbol_info(symbol))
            elif self.path.startswith("/history/"):
                ticket = int(self.path.split("/history/")[1])
                deals = mt5.history_deals_get(position=ticket)
                if deals:
                    profit = round(sum(d.profit for d in deals), 2)
                    self.send_json(200, {"ticket": ticket, "profit": profit})
                else:
                    self.send_json(200, {"ticket": ticket, "profit": None})
            elif self.path.startswith("/report/"):
                timeframe = self.path.split("/report/")[1]
                self.send_json(200, get_pnl_report(timeframe))
            elif self.path.startswith("/ohlcv/"):
                parts = self.path.split("/")
                if len(parts) >= 5:
                    symbol = parts[2]
                    timeframe = parts[3]
                    count = int(parts[4])
                    self.send_json(200, get_ohlcv(symbol, timeframe, count))
                else:
                    self.send_json(400, {"error": "invalid ohlcv path"})
            else:
                self.send_json(404, {"error": "not found"})
        except Exception as e:
            self.send_json(500, {"error": str(e)})

    def do_POST(self):
        try:
            if self.path == "/order":
                data = self.read_body()
                result = do_order(
                    symbol=data["symbol"],
                    side=data["side"],
                    lot=data.get("lot", 0.01),
                    price=data.get("price"),
                    stop_loss=data.get("stop_loss", 0.0),
                    take_profit=data.get("take_profit", 0.0),
                    comment=data.get("comment", "FXAlexG Bot"),
                )
                self.send_json(200, result)
            elif self.path == "/close":
                data = self.read_body()
                result = close_position(
                    int(data["ticket"]),
                    volume=data.get("volume"),
                )
                self.send_json(200, result)
            elif self.path == "/modify":
                data = self.read_body()
                result = modify_position(
                    int(data["ticket"]),
                    stop_loss=data.get("stop_loss"),
                    take_profit=data.get("take_profit"),
                )
                self.send_json(200, result)
            elif self.path == "/switch":
                data = self.read_body()
                result = switch_account(
                    data["login"],
                    data.get("password", ""),
                    data["server"],
                )
                self.send_json(200, result)
            else:
                self.send_json(404, {"error": "not found"})
        except Exception as e:
            self.send_json(400, {"error": str(e)})


if __name__ == "__main__":
    if not init_mt5():
        sys.exit(1)

    print(f"HTTP Server listening on http://127.0.0.1:{PORT}")
    try:
        HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nBridge stopped.")
        mt5.shutdown()
