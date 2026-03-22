"""Suggest pyrit-cli commands using HELP.md + OpenAI-compatible chat API."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any

from dotenv import load_dotenv

from pyrit_cli.env_status import pyrit_dir
from pyrit_cli.help_loader import load_help_markdown

_DEFAULT_BASE = "https://api.openai.com/v1"
_DEFAULT_MODEL = "gpt-4o-mini"


def load_pyrit_dotenv() -> None:
    d = pyrit_dir()
    load_dotenv(d / ".env", override=False)
    load_dotenv(d / ".env.local", override=True)


def resolve_api_key(explicit: str | None) -> str:
    if explicit and explicit.strip():
        return explicit.strip()
    for key in ("OPENAI_API_KEY", "OPENAI_CHAT_KEY"):
        v = os.environ.get(key, "").strip()
        if v and not v.startswith("${"):
            return v
    raise ValueError(
        "No API key: pass --api-key or set OPENAI_API_KEY or OPENAI_CHAT_KEY in the environment "
        "(e.g. after `pyrit-cli setup configure` or in ~/.pyrit/.env)."
    )


def resolve_base_url(explicit: str | None) -> str:
    if explicit and explicit.strip():
        return explicit.strip().rstrip("/")
    v = os.environ.get("OPENAI_CHAT_ENDPOINT", "").strip()
    if v and not v.startswith("${"):
        return v.rstrip("/")
    return _DEFAULT_BASE


def _chat_completions_url(base: str) -> str:
    return f"{base.rstrip('/')}/chat/completions"


def suggest_command(
    user_goal: str,
    *,
    model: str,
    api_key: str,
    base_url: str,
) -> str:
    help_md = load_help_markdown()
    system = (
        "You help users choose the correct pyrit-cli shell command for authorized red-teaming and "
        "workshop demos. You MUST base suggestions only on the reference below.\n\n"
        "Rules:\n"
        "- Output a single runnable bash example starting with `pyrit-cli` (use line continuations `\\` if needed).\n"
        "- Prefer the smallest command that fits the goal (e.g. prompt-sending-attack for one-shot; "
        "red-teaming-attack for multi-turn with --true-description; tap-attack only if they ask for TAP/tree).\n"
        "- Use placeholder objectives like benign test strings when the user is vague.\n"
        "- After the command, one short line starting with # explaining the choice.\n"
        "- Do not invent flags that are not in the reference. Do not output anything before the command line.\n\n"
        "### pyrit-cli HELP reference\n\n"
        + help_md
    )
    user = f"What pyrit-cli command fits this goal?\n\n{user_goal.strip()}"

    body: dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.2,
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        _chat_completions_url(base_url),
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Chat API HTTP {e.code}: {detail[:800]}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Chat API request failed: {e}") from e

    try:
        choices = payload["choices"]
        return str(choices[0]["message"]["content"]).strip()
    except (KeyError, IndexError, TypeError) as e:
        raise RuntimeError(f"Unexpected API response: {repr(payload)[:500]}") from e


def run_ask_ai(
    user_goal: str,
    *,
    model: str | None,
    api_key: str | None,
    base_url: str | None,
) -> str:
    load_pyrit_dotenv()
    key = resolve_api_key(api_key)
    base = resolve_base_url(base_url)
    m = (model or os.environ.get("OPENAI_CHAT_MODEL") or _DEFAULT_MODEL).strip()
    return suggest_command(user_goal, model=m, api_key=key, base_url=base)
