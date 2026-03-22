"""LLM coach: LangGraph agent + legacy helpers for OpenAI-compatible env."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from openai import OpenAI

COACH_BASE = (
    "You are the red-cell coach for authorized AI security assessments. "
    "Sound like a careful operator: concise, tactical, no glamorizing harm. "
    "Always reinforce scope — only systems they own or have explicit permission to test."
)


def load_pyrit_env() -> None:
    """Load ~/.pyrit/.env and .env.local into process env."""
    base = Path.home() / ".pyrit"
    load_dotenv(base / ".env")
    load_dotenv(base / ".env.local", override=True)


def _client() -> OpenAI:
    load_pyrit_env()
    base_url = (
        os.getenv("OPENAI_CHAT_ENDPOINT")
        or os.getenv("PLATFORM_OPENAI_CHAT_ENDPOINT")
        or "https://api.openai.com/v1"
    )
    base_url = base_url.rstrip("/")
    if not base_url.endswith("/v1"):
        base_url = base_url + "/v1"
    api_key = (
        os.getenv("OPENAI_CHAT_KEY")
        or os.getenv("PLATFORM_OPENAI_CHAT_API_KEY")
        or os.getenv("OPENAI_API_KEY")
        or ""
    )
    if not api_key:
        raise RuntimeError(
            "No API key found. Configure ~/.pyrit via the Setup tab or set OPENAI_API_KEY / platform keys."
        )
    return OpenAI(base_url=base_url, api_key=api_key)


def default_model() -> str:
    load_pyrit_env()
    return (
        os.getenv("OPENAI_CHAT_MODEL")
        or os.getenv("PLATFORM_OPENAI_CHAT_GPT4O_MODEL")
        or "gpt-4o"
    )


def _history_to_openai_messages(history: list[Any]) -> list[dict[str, str]]:
    """Convert Gradio Chatbot history to OpenAI chat messages (no system)."""
    messages: list[dict[str, str]] = []
    if not history:
        return messages
    for item in history:
        if isinstance(item, dict):
            role = item.get("role", "user")
            raw = item.get("content", "")
            content = raw if isinstance(raw, str) else str(raw)
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})
        elif isinstance(item, (list, tuple)) and len(item) >= 2:
            u, a = item[0], item[1]
            if u:
                messages.append({"role": "user", "content": str(u)})
            if a:
                messages.append({"role": "assistant", "content": str(a)})
    return messages


def coach_reply(
    message: str,
    history: list[Any],
    *,
    system_prompt: str,
) -> str:
    """Legacy single-turn chat (unused when LangGraph is enabled)."""
    client = _client()
    model = default_model()
    messages: list[dict] = [{"role": "system", "content": system_prompt}]
    messages.extend(_history_to_openai_messages(history))
    messages.append({"role": "user", "content": message})
    resp = client.chat.completions.create(model=model, messages=messages, temperature=0.7)
    choice = resp.choices[0].message.content
    return choice or ""


def invoke_coach_graph(assignment_key: str, history: list[Any], user_message: str) -> str:
    """LangGraph ReAct coach with tools (execute_python, runners, dataset preview)."""
    from aisec_gradio.agent.graph import invoke_workshop_agent

    return invoke_workshop_agent(assignment_key, history, user_message)
