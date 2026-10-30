"""
Per-level defenses that make the same challenge harder.

  input_filter : block the prompt if it contains known attack keywords (raises Blocked)
  out_scan     : redact the secret from the model's reply before it reaches the player
"""
from __future__ import annotations

_BLOCKLIST = [
    "ignore", "system prompt", "reveal", "repeat your", "print your",
    "developer mode", "debug mode", "passphrase", "base64", "decode",
]


class Blocked(Exception):
    """Raised when an input_filter rejects a prompt."""


def apply_input(prompt: str, defenses: list[str]) -> None:
    if "input_filter" not in defenses:
        return
    low = prompt.lower()
    for kw in _BLOCKLIST:
        if kw in low:
            raise Blocked(f"🛡️ Guardrail blocked your input (matched: '{kw}'). Try a subtler approach.")


def apply_output(reply: str, defenses: list[str], secret: str | None) -> str:
    if "out_scan" not in defenses or not secret:
        return reply
    if secret in reply:
        return reply.replace(secret, "🛡️[REDACTED BY OUTPUT GUARD]")
    return reply


def defenses_for(challenge: dict, level: str) -> list[str]:
    return (challenge.get("defenses") or {}).get(level, []) or []
