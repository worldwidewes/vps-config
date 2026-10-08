"""SQLite persistence: every check is stored; stock transitions are stored as events."""
import os
import sqlite3
from datetime import datetime, timezone

DB_PATH = os.environ.get("DB_PATH", "/data/stock.db")


def _connect() -> sqlite3.Connection:
    os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db() -> None:
    with _connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS checks (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                ts       TEXT NOT NULL,
                retailer TEXT NOT NULL,
                product  TEXT NOT NULL,
                status   TEXT NOT NULL,
                price    REAL,
                detail   TEXT,
                url      TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_checks_retailer_ts ON checks(retailer, ts DESC);

            CREATE TABLE IF NOT EXISTS events (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                ts       TEXT NOT NULL,
                retailer TEXT NOT NULL,
                product  TEXT NOT NULL,
                status   TEXT NOT NULL,
                price    REAL,
                url      TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts DESC);

            CREATE TABLE IF NOT EXISTS meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
            """
        )


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def record_check(retailer, product, status, price, detail, url) -> str | None:
    """Store a check. Return the previous status if it changed, else None."""
    with _connect() as conn:
        prev = conn.execute(
            "SELECT status FROM checks WHERE retailer=? ORDER BY id DESC LIMIT 1",
            (retailer,),
        ).fetchone()
        prev_status = prev["status"] if prev else None

        conn.execute(
            "INSERT INTO checks (ts, retailer, product, status, price, detail, url) "
            "VALUES (?,?,?,?,?,?,?)",
            (now_iso(), retailer, product, status, price, detail, url),
        )

        if prev_status != status:
            conn.execute(
                "INSERT INTO events (ts, retailer, product, status, price, url) "
                "VALUES (?,?,?,?,?,?)",
                (now_iso(), retailer, product, status, price, url),
            )
            return prev_status
    return None


def latest():
    """One most-recent row per retailer, newest first."""
    with _connect() as conn:
        rows = conn.execute(
            """
            SELECT c.* FROM checks c
            JOIN (SELECT retailer, MAX(id) AS mid FROM checks GROUP BY retailer) m
              ON c.id = m.mid
            ORDER BY c.retailer
            """
        ).fetchall()
        return [dict(r) for r in rows]


def events(limit: int = 40):
    with _connect() as conn:
        rows = conn.execute(
            "SELECT * FROM events ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]


def history(retailer: str, limit: int = 200):
    with _connect() as conn:
        rows = conn.execute(
            "SELECT ts, status, price FROM checks WHERE retailer=? ORDER BY id DESC LIMIT ?",
            (retailer, limit),
        ).fetchall()
        return [dict(r) for r in reversed(rows)]


def set_meta(key: str, value: str) -> None:
    with _connect() as conn:
        conn.execute(
            "INSERT INTO meta(key,value) VALUES(?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, value),
        )


def get_meta(key: str) -> str | None:
    with _connect() as conn:
        row = conn.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return row["value"] if row else None
