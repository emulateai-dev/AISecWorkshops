"""Load provider.yaml + challenges.yaml; build effective system prompts and level specs."""
from __future__ import annotations
import os
from pathlib import Path
from functools import lru_cache
import yaml

CONFIG_DIR = Path(os.environ.get("GAUNTLET_CONFIG", Path(__file__).resolve().parent.parent / "config"))
EFFORTS = ("low", "medium", "high")


@lru_cache(maxsize=1)
def provider_config() -> dict:
    return yaml.safe_load((CONFIG_DIR / "provider.yaml").read_text())


@lru_cache(maxsize=1)
def challenges() -> dict:
    return yaml.safe_load((CONFIG_DIR / "challenges.yaml").read_text())


@lru_cache(maxsize=1)
def challenge_info() -> dict:
    """Optional per-challenge learning content (config/info.yaml)."""
    f = CONFIG_DIR / "info.yaml"
    if not f.is_file():
        return {}
    return yaml.safe_load(f.read_text()) or {}


def get_challenge(challenge_id: str) -> dict:
    ch = challenges().get(challenge_id)
    if not ch:
        raise KeyError(f"unknown challenge: {challenge_id}")
    return ch


def levels() -> dict:
    return provider_config()["levels"]


def level_spec(level: str) -> dict:
    lv = levels().get(level)
    if not lv:
        raise KeyError(f"unknown level: {level}")
    return lv


def the_model(override: str | None = None, level: str | None = None) -> str:
    """Resolve the target model: per-session override > per-level model > provider default."""
    if override:
        return override
    if level:
        lm = levels().get(level, {}).get("model")
        if lm:
            return lm
    return provider_config()["provider"]["model"]


def default_effort(override: str | None = None) -> str | None:
    eff = override or provider_config()["provider"].get("reasoning_effort")
    return eff if eff in EFFORTS else None


def guards_config() -> dict:
    return provider_config().get("guards", {}) or {}


def classifier_model() -> str:
    """Model for the LLM guardrails + the privileged grader fallback.
    Resolves by provider/availability: an explicit config value, else the challenge model."""
    m = guards_config().get("classifier_model")
    return the_model() if (not m or m == "auto") else m


def safety_model() -> str:
    """Content-safety model (e.g. Llama-Guard). Falls back to the classifier model."""
    m = guards_config().get("safety_model")
    return classifier_model() if (not m or m == "auto") else m


def hardening_clauses() -> dict:
    return provider_config().get("hardening", {})


def effective_system(base_system: str, level: str) -> str:
    """Base system prompt + the hardening clauses this level stacks on."""
    clauses = hardening_clauses()
    picked = [clauses[name].strip() for name in level_spec(level).get("harden", []) if name in clauses]
    if not picked:
        return base_system
    return base_system.rstrip() + "\n\n" + "\n".join(f"- {c}" for c in picked)


def default_level(challenge_id: str) -> str:
    diff = get_challenge(challenge_id).get("difficulty", "easy")
    return {"easy": "L1", "medium": "L2", "hard": "L3"}.get(diff, "L1")


def public_view(challenge_id: str) -> dict:
    """Player-facing metadata (never includes secret or system prompt)."""
    ch = get_challenge(challenge_id)
    badge = {"easy": "🟢", "medium": "🟡", "hard": "🔴"}.get(ch.get("difficulty"), "⚪")
    return {
        "id": challenge_id, "topic": ch.get("topic"), "difficulty": ch.get("difficulty"),
        "badge": badge, "brief": ch.get("brief"), "agentic": bool(ch.get("agentic")),
        "default_level": default_level(challenge_id),
    }


def info_view(challenge_id: str) -> dict:
    """Player-facing learning panel: description + techniques + a non-spoiler hint."""
    ch = get_challenge(challenge_id)   # raises KeyError if unknown
    info = dict(challenge_info().get(challenge_id, {}))
    badge = {"easy": "🟢", "medium": "🟡", "hard": "🔴"}.get(ch.get("difficulty"), "⚪")
    return {
        "id": challenge_id, "topic": ch.get("topic"), "difficulty": ch.get("difficulty"),
        "badge": badge, "brief": ch.get("brief"), "agentic": bool(ch.get("agentic")),
        "summary": info.get("summary"), "techniques": info.get("techniques", []),
        "hint": info.get("hint"), "references": info.get("references", []),
    }


def levels_view() -> list[dict]:
    """Player-facing ladder description."""
    out = []
    for name, lv in levels().items():
        out.append({"level": name, "label": lv.get("label"), "model": the_model(level=name),
                    "hardening": lv.get("harden", []), "guards": lv.get("guards", [])})
    return out
