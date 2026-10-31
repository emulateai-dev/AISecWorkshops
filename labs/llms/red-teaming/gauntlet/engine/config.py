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


# ---------------- providers ----------------
def providers() -> dict:
    return provider_config().get("providers", {}) or {}


def active_provider_name() -> str:
    """Which provider supplies the guard/grader models + default (env overridable)."""
    return os.environ.get("GAUNTLET_PROVIDER") or provider_config().get("active_provider") or "groq"


def active_provider() -> dict:
    return providers().get(active_provider_name(), {})


def active_profile_name() -> str:
    """Which per-level model table to use (env overridable)."""
    return os.environ.get("GAUNTLET_PROFILE") or provider_config().get("active_models") or active_provider_name()


def level_models() -> dict:
    """The active profile's {level: model} table."""
    return provider_config().get("level_models", {}).get(active_profile_name(), {})


def provider_default_model() -> str:
    ap = active_provider()
    return ap.get("default_model") or provider_config().get("model") or "groq/openai/gpt-oss-20b"


def the_model(override: str | None = None, level: str | None = None) -> str:
    """Resolve the target model:
      per-session override  >  active profile's per-level model  >  active provider default."""
    if override:
        return override
    if level:
        m = level_models().get(level)
        if m:
            return m
    return provider_default_model()


def target_temperature() -> float:
    try:
        return float(provider_config().get("temperature", 0.3))
    except (TypeError, ValueError):
        return 0.3


def default_effort(override: str | None = None) -> str | None:
    eff = override or provider_config().get("reasoning_effort")
    return eff if eff in EFFORTS else None


def guards_config() -> dict:
    return provider_config().get("guards", {}) or {}


def classifier_model() -> str:
    """Model for the LLM guardrails + the privileged grader fallback.
    'auto' (or unset) resolves to the active provider's classifier_model, else its default."""
    m = guards_config().get("classifier_model")
    if m and m != "auto":
        return m
    ap = active_provider()
    return ap.get("classifier_model") or provider_default_model()


def safety_model() -> str:
    """Content-safety model. 'auto' resolves to the active provider's safety_model, else classifier."""
    m = guards_config().get("safety_model")
    if m and m != "auto":
        return m
    ap = active_provider()
    return ap.get("safety_model") or classifier_model()


def hardening_clauses() -> dict:
    return provider_config().get("hardening", {})


def softening_clauses() -> dict:
    return provider_config().get("softening", {})


def effective_system(base_system: str, level: str) -> str:
    """Base system prompt + this level's hardening clauses + its soft-corner clauses.
    Soft corners come LAST (the model weights later instructions) — they are the intended,
    graduated gap that makes the challenge solvable with a technique (none at L5)."""
    lv = level_spec(level)
    hard = hardening_clauses()
    soft = softening_clauses()
    hp = [hard[n].strip() for n in lv.get("harden", []) if n in hard]
    sp = [soft[n].strip() for n in lv.get("soften", []) if n in soft]
    parts = [base_system.rstrip()]
    if hp:
        parts.append("\n".join(f"- {c}" for c in hp))
    if sp:
        parts.append("\n".join(sp))
    return "\n\n".join(parts)


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
