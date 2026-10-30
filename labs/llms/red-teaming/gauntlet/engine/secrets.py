"""
Secret/key resolution for the Gauntlet.

Keys are loaded in this order, per provider:
  1. existing environment variable (e.g. GROQ_API_KEY)  -> kept as-is
  2. <secrets_dir>/<key_file>  (e.g. ~/.secrets/GROQ_API_KEY.txt, or /secrets in Docker)

Values are NEVER printed or returned — only a readiness map (present/absent).
"""
from __future__ import annotations
import os
from pathlib import Path


def resolve_keys(provider_cfg: dict, secrets_dir: str | None = None) -> dict:
    """Populate env vars from secret files when absent. Return a readiness map."""
    secrets_dir = secrets_dir or os.environ.get("SECRETS_DIR") or "/secrets"
    base = Path(os.path.expanduser(secrets_dir))

    readiness: dict[str, bool] = {}
    env = provider_cfg.get("key_env")
    key_file = provider_cfg.get("key_file")
    name = provider_cfg.get("name", "provider")

    if not env:  # provider needs no key (e.g. ollama)
        readiness[name] = True
        return readiness

    if os.environ.get(env):
        readiness[name] = True
        return readiness

    candidate = base / key_file if key_file else None
    if candidate and candidate.is_file():
        val = candidate.read_text(encoding="utf-8").strip()
        if val:
            os.environ[env] = val
            readiness[name] = True
            return readiness

    readiness[name] = False
    return readiness


def readiness_table(readiness: dict) -> str:
    rows = []
    for name, ok in readiness.items():
        rows.append(f"  {'✅' if ok else '⬜'} {name}{'' if ok else '  (no key — set env or mount ~/.secrets)'}")
    return "\n".join(rows)
