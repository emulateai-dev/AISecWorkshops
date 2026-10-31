"""SQLite session store. Sessions, messages and findings persist across restarts."""
from __future__ import annotations
import json
import os
import sqlite3
import time
from pathlib import Path

DB_PATH = Path(os.environ.get("GAUNTLET_DB", Path(__file__).resolve().parent.parent / "data" / "gauntlet.db"))


def _conn() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def init() -> None:
    with _conn() as c:
        c.executescript(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                challenge TEXT, level TEXT, model TEXT, reasoning_effort TEXT,
                spec TEXT,                 -- frozen effective challenge spec (json)
                created REAL, solved INTEGER DEFAULT 0,
                attempts INTEGER DEFAULT 0, score TEXT
            );
            CREATE TABLE IF NOT EXISTS messages (
                session_id TEXT, idx INTEGER, role TEXT, content TEXT, ts REAL
            );
            CREATE TABLE IF NOT EXISTS findings (
                session_id TEXT, created REAL, finding TEXT
            );
            """
        )


def create_session(sid: str, challenge: str, level: str, model: str, spec: dict,
                   reasoning_effort: str | None = None) -> None:
    with _conn() as c:
        c.execute(
            "INSERT INTO sessions (id, challenge, level, model, reasoning_effort, spec, created) "
            "VALUES (?,?,?,?,?,?,?)",
            (sid, challenge, level, model, reasoning_effort, json.dumps(spec), time.time()),
        )


def session_exists(sid: str) -> bool:
    with _conn() as c:
        return c.execute("SELECT 1 FROM sessions WHERE id=?", (sid,)).fetchone() is not None


def get_session(sid: str) -> dict | None:
    with _conn() as c:
        row = c.execute("SELECT * FROM sessions WHERE id=?", (sid,)).fetchone()
        if not row:
            return None
        d = dict(row)
        d["spec"] = json.loads(d["spec"])
        d["score"] = json.loads(d["score"]) if d["score"] else None
        d["solved"] = bool(d["solved"])
        return d


def get_messages(sid: str) -> list[dict]:
    with _conn() as c:
        rows = c.execute("SELECT role, content FROM messages WHERE session_id=? ORDER BY idx", (sid,)).fetchall()
        return [dict(r) for r in rows]


def add_message(sid: str, role: str, content: str) -> None:
    with _conn() as c:
        n = c.execute("SELECT COUNT(*) FROM messages WHERE session_id=?", (sid,)).fetchone()[0]
        c.execute(
            "INSERT INTO messages (session_id, idx, role, content, ts) VALUES (?,?,?,?,?)",
            (sid, n, role, content, time.time()),
        )


def bump_attempts(sid: str) -> int:
    with _conn() as c:
        c.execute("UPDATE sessions SET attempts = attempts + 1 WHERE id=?", (sid,))
        return c.execute("SELECT attempts FROM sessions WHERE id=?", (sid,)).fetchone()[0]


def mark_solved(sid: str, score: dict, finding: dict) -> None:
    with _conn() as c:
        c.execute("UPDATE sessions SET solved=1, score=? WHERE id=?", (json.dumps(score), sid))
        c.execute("INSERT INTO findings (session_id, created, finding) VALUES (?,?,?)",
                  (sid, time.time(), json.dumps(finding)))


def get_finding(sid: str) -> dict | None:
    with _conn() as c:
        row = c.execute("SELECT finding FROM findings WHERE session_id=? ORDER BY created DESC LIMIT 1", (sid,)).fetchone()
        return json.loads(row[0]) if row else None


def list_sessions() -> list[dict]:
    with _conn() as c:
        rows = c.execute("SELECT id, challenge, level, model, attempts, solved, created "
                         "FROM sessions ORDER BY created DESC").fetchall()
        return [dict(r) | {"solved": bool(r["solved"])} for r in rows]
