#!/usr/bin/env python3
"""
The Gauntlet — terminal client. Talks to the same backend API as the Web UI,
so grading/sessions are identical.

    python cli/play.py --challenge two-faced
    python cli/play.py --challenge two-faced --level L3 --session myrun1
    GAUNTLET_URL=http://localhost:8000 python cli/play.py --list
"""
from __future__ import annotations
import argparse
import json
import os
import sys
import urllib.request

BASE = os.environ.get("GAUNTLET_URL", "http://localhost:8000")


def _req(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(f"✗ {e.code}: {e.read().decode()}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--challenge")
    ap.add_argument("--level", default=None, help="L1..L5 (naive..fortified)")
    ap.add_argument("--think", default=None, choices=["low", "medium", "high"], help="reasoning_effort override")
    ap.add_argument("--session", default=None)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    if a.list or not a.challenge:
        print("\nChallenges:")
        for c in _req("GET", "/challenges"):
            tag = " (agentic — Phase 2)" if c["agentic"] else ""
            print(f"  {c['badge']} {c['id']:<16} {c['topic']}{tag}")
        if not a.challenge:
            return

    body = {"challenge": a.challenge}
    if a.level:
        body["level"] = a.level
    if a.think:
        body["overrides"] = {"reasoning_effort": a.think}
    if a.session:
        body["session_id"] = a.session
    s = _req("POST", "/sessions", body)

    guards = ", ".join(s.get("guards") or []) or "none"
    print(f"\n  {s['badge']} {s['challenge'].upper()}  ·  {s['level']} ({s.get('level_label')})  ·  🧠 {s.get('reasoning_effort') or 'default'}")
    print(f"  model: {s['model']}   guards: {guards}")
    print(f"  Session: {s['session_id']}")
    print(f"  Goal: {s['brief']}")
    print("  Type prompts. Ctrl-D to quit.\n")

    while True:
        try:
            msg = input("you> ").strip()
        except EOFError:
            print(); break
        if not msg:
            continue
        r = _req("POST", f"/sessions/{s['session_id']}/chat", {"message": msg})
        print(f"model> {r['reply']}\n")
        if r["won"] and not r["already_solved"]:
            sc = r["score"]
            print(f"  ✅ WIN in {r['attempts']} attempt(s) · total {r['total']}")
            print(f"  Score: Sev {sc['severity']} · Br {sc['breadth']} · Nov {sc['novelty']} · "
                  f"Rep {sc['reproducibility']} · Ins {sc['insight']}\n")


if __name__ == "__main__":
    main()
