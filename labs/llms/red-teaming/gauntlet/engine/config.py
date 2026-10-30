"""Load provider.yaml + challenges.yaml and resolve per-level models."""
from __future__ import annotations
import os
from pathlib import Path
from functools import lru_cache
import yaml

CONFIG_DIR = Path(os.environ.get("GAUNTLET_CONFIG", Path(__file__).resolve().parent.parent / "config"))


@lru_cache(maxsize=1)
def provider_config() -> dict:
    return yaml.safe_load((CONFIG_DIR / "provider.yaml").read_text())


@lru_cache(maxsize=1)
def challenges() -> dict:
    return yaml.safe_load((CONFIG_DIR / "challenges.yaml").read_text())


def get_challenge(challenge_id: str) -> dict:
    ch = challenges().get(challenge_id)
    if not ch:
        raise KeyError(f"unknown challenge: {challenge_id}")
    return ch


def levels() -> dict:
    return provider_config()["levels"]


def model_for(challenge_id: str, level: str) -> str:
    """Resolve the backing model for a challenge at a given level, honouring per-challenge overrides."""
    ch = get_challenge(challenge_id)
    eff_level = (ch.get("level_override") or {}).get(level, level)
    lv = levels().get(eff_level)
    if not lv:
        raise KeyError(f"unknown level: {level}")
    return lv["model"]


def default_level(challenge_id: str) -> str:
    diff = get_challenge(challenge_id).get("difficulty", "easy")
    return {"easy": "L1", "medium": "L2", "hard": "L3"}.get(diff, "L1")


def public_view(challenge_id: str) -> dict:
    """Player-facing metadata (never includes secret or system prompt)."""
    ch = get_challenge(challenge_id)
    badge = {"easy": "🟢", "medium": "🟡", "hard": "🔴"}.get(ch.get("difficulty"), "⚪")
    return {
        "id": challenge_id,
        "topic": ch.get("topic"),
        "difficulty": ch.get("difficulty"),
        "badge": badge,
        "brief": ch.get("brief"),
        "agentic": bool(ch.get("agentic")),
        "default_level": default_level(challenge_id),
    }
