"""Parse CLI target specs into PyRIT prompt targets."""

from __future__ import annotations

from typing import Any

from pyrit.prompt_target import OpenAIChatTarget


def parse_openai_target(spec: str) -> str:
    """Parse ``openai:<model_name>`` and return the model name."""
    t = spec.strip()
    if ":" not in t:
        raise ValueError(f"Invalid target {spec!r}; expected openai:<model_name>")
    provider, model = t.split(":", 1)
    if provider.lower() != "openai" or not model.strip():
        raise ValueError(f"Invalid target {spec!r}; only openai:<model_name> is supported")
    return model.strip()


def openai_chat_from_spec(spec: str, **kwargs: Any) -> OpenAIChatTarget:
    """Build ``OpenAIChatTarget``; optional kwargs e.g. ``temperature=1.1``."""
    return OpenAIChatTarget(model_name=parse_openai_target(spec), **kwargs)
