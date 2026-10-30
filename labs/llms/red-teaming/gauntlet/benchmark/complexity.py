"""Complexity scoring for techniques: curated tier (C0-C4) + objective auto-score."""
from __future__ import annotations

TIERS = ["C0", "C1", "C2", "C3", "C4"]


def rank(tier: str) -> int:
    return TIERS.index(tier) if tier in TIERS else len(TIERS)


_STACK_MARKERS = ["ignore", "as dan", "hypothetical", "roleplay", "unrestricted tool",
                  "audit", "off the record", "override", "begin your reply", "step by step"]


def auto_score(prompts: list[str], turns: int, adaptive: bool = False, leet: bool = False) -> float:
    """Objective complexity: turns + stacked techniques + obfuscation + length + prior-use."""
    text = " ".join(prompts).lower()
    stacked = min(sum(1 for m in _STACK_MARKERS if m in text), 3)
    obfusc = 1 if (leet or "base64" in text or "x+y" in text or "rev" in text) else 0
    uses_prior = 1 if ("{{last" in text or adaptive) else 0
    return round(1 * turns + 2 * stacked + 2 * obfusc + len(text) / 100 + 3 * uses_prior, 1)


def load_techniques(path: str) -> list[dict]:
    import yaml
    techs = yaml.safe_load(open(path))
    for t in techs:
        t["auto_score"] = auto_score(t.get("prompts", []), t.get("turns", 1),
                                     t.get("adaptive", False), t.get("leet", False))
    # sort by curated tier, then objective score — the order the runner escalates through
    techs.sort(key=lambda t: (rank(t["tier"]), t["auto_score"]))
    return techs
