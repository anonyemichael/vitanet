import sqlite3
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path

DB_PATH = Path(__file__).parent / "trades.db"


def _conn():
    return sqlite3.connect(str(DB_PATH))


def init_db():
    conn = _conn()
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS trades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            opened_at TEXT,
            closed_at TEXT,
            symbol TEXT,
            direction TEXT,
            grade TEXT,
            score INTEGER,
            lot REAL,
            entry REAL,
            sl REAL,
            tp REAL,
            rr REAL,
            risk_usd REAL,
            result_usd REAL,
            ticket INTEGER,
            status TEXT DEFAULT 'open',
            tp1 REAL,
            tp2 REAL,
            partial_closed INTEGER DEFAULT 0,
            partial_profit REAL DEFAULT 0.0
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scanned_at TEXT,
            symbol TEXT,
            grade TEXT,
            score INTEGER,
            direction TEXT,
            action TEXT
        )
    """)
    conn.commit()
    conn.close()


def log_trade_opened(setup, lot, risk_usd, ticket):
    conn = _conn()
    c = conn.cursor()
    now = datetime.now(timezone.utc).isoformat()
    c.execute("""
        INSERT INTO trades (opened_at, symbol, direction, grade, score, lot, entry, sl, tp, rr, risk_usd, ticket, status, tp1, tp2)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?)
    """, (
        now, setup["symbol"], setup["direction"], setup["grade"], setup["score"],
        lot, setup["entry"], setup["sl"], setup["tp"], setup["rr"], risk_usd, ticket,
        setup.get("tp1"), setup.get("tp2"),
    ))
    conn.commit()
    conn.close()


def log_trade_closed(ticket, result_usd):
    conn = _conn()
    c = conn.cursor()
    now = datetime.now(timezone.utc).isoformat()
    c.execute("UPDATE trades SET closed_at = ?, result_usd = ?, status = 'closed' WHERE ticket = ? AND status = 'open'",
              (now, result_usd, ticket))
    conn.commit()
    conn.close()


def log_partial_close(ticket, partial_profit):
    conn = _conn()
    c = conn.cursor()
    c.execute("UPDATE trades SET partial_closed = 1, partial_profit = ? WHERE ticket = ?",
              (partial_profit, ticket))
    conn.commit()
    conn.close()


def is_partial_closed(ticket):
    conn = _conn()
    c = conn.cursor()
    c.execute("SELECT partial_closed FROM trades WHERE ticket = ?", (ticket,))
    row = c.fetchone()
    conn.close()
    return bool(row and row[0])


def log_scan(symbol, grade, score, direction, action):
    conn = _conn()
    c = conn.cursor()
    now = datetime.now(timezone.utc).isoformat()
    c.execute("INSERT INTO scans (scanned_at, symbol, grade, score, direction, action) VALUES (?, ?, ?, ?, ?, ?)",
              (now, symbol, grade, score, direction, action))
    conn.commit()
    conn.close()


def get_open_trade_tickets():
    conn = _conn()
    c = conn.cursor()
    c.execute("SELECT ticket FROM trades WHERE status = 'open'")
    tickets = [r[0] for r in c.fetchall()]
    conn.close()
    return tickets


def get_trade_by_ticket(ticket):
    conn = _conn()
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM trades WHERE ticket = ?", (ticket,))
    row = c.fetchone()
    conn.close()
    return dict(row) if row else None


def get_daily_trade_count():
    conn = _conn()
    c = conn.cursor()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    c.execute("SELECT COUNT(*) FROM trades WHERE opened_at LIKE ?", (f"{today}%",))
    count = c.fetchone()[0]
    conn.close()
    return count


def get_kill_zone_trade_count(kill_zone):
    """Returns number of trades opened in the current kill zone session today."""
    conn = _conn()
    c = conn.cursor()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    c.execute("SELECT COUNT(*) FROM trades WHERE opened_at LIKE ?", (f"{today}%",))
    count = c.fetchone()[0]
    conn.close()
    return count


# ── v3.1 NEW: Re-Entry Cooldown Support ─────────────────────────────────────

def get_last_loss_time(symbol):
    """
    Returns the closed_at datetime of the most recent LOSING trade for this symbol.
    Returns None if no recent loss exists.
    Used by bot.py for re-entry cooldown logic.
    """
    conn = _conn()
    c = conn.cursor()
    c.execute("""
        SELECT closed_at FROM trades
        WHERE symbol = ? AND status = 'closed' AND result_usd < 0
        ORDER BY closed_at DESC
        LIMIT 1
    """, (symbol,))
    row = c.fetchone()
    conn.close()
    if row and row[0]:
        try:
            return datetime.fromisoformat(row[0]).replace(tzinfo=timezone.utc)
        except Exception:
            return None
    return None


def is_in_cooldown(symbol, cooldown_hours):
    """
    Returns (True, hours_remaining) if the symbol is still in cooldown after a recent loss.
    Returns (False, 0) if no cooldown applies.
    """
    last_loss = get_last_loss_time(symbol)
    if last_loss is None:
        return False, 0
    now = datetime.now(timezone.utc)
    elapsed = (now - last_loss).total_seconds() / 3600.0
    if elapsed < cooldown_hours:
        remaining = round(cooldown_hours - elapsed, 1)
        return True, remaining
    return False, 0
