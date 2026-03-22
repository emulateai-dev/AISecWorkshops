"""LangGraph ReAct agent for the workshop coach."""

from __future__ import annotations

import os
from typing import Any

from aisec_gradio.agent.context import load_assignment_context
from aisec_gradio.agent.tools import make_tools
from aisec_gradio.coach import COACH_BASE, default_model, load_pyrit_env
from aisec_gradio.workshop_registry import assignment_by_ids, parse_assignment_key


def _history_to_langchain(history: list[Any]) -> list:
    from langchain_core.messages import AIMessage, HumanMessage

    out = []
    for item in history or []:
        if isinstance(item, dict):
            role = item.get("role", "")
            raw = item.get("content", "")
            content = raw if isinstance(raw, str) else str(raw)
            if not content.strip():
                continue
            if role == "user":
                out.append(HumanMessage(content=content))
            elif role == "assistant":
                out.append(AIMessage(content=content))
        elif isinstance(item, (list, tuple)) and len(item) >= 2:
            u, a = item[0], item[1]
            if u:
                out.append(HumanMessage(content=str(u)))
            if a:
                out.append(AIMessage(content=str(a)))
    return out


def _last_ai_text(messages: list) -> str:
    from langchain_core.messages import AIMessage

    for m in reversed(messages):
        if isinstance(m, AIMessage):
            c = m.content
            if isinstance(c, str):
                return c
            if isinstance(c, list):
                parts = []
                for block in c:
                    if isinstance(block, dict) and block.get("type") == "text":
                        parts.append(block.get("text", ""))
                    else:
                        parts.append(str(block))
                return "".join(parts)
            return str(c)
    return ""


def _chat_model():
    load_pyrit_env()
    from langchain_openai import ChatOpenAI

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
    return ChatOpenAI(
        model=default_model(),
        api_key=api_key,
        base_url=base_url,
        temperature=0.2,
    )


def invoke_workshop_agent(assignment_key: str, history: list[Any], user_message: str) -> str:
    """Run the LangGraph ReAct agent; return the assistant reply text."""
    from langchain_core.messages import HumanMessage, SystemMessage
    from langgraph.prebuilt import create_react_agent

    model = _chat_model()
    tools = make_tools(assignment_key)
    agent = create_react_agent(model, tools)

    try:
        sid, aid = parse_assignment_key(assignment_key)
    except ValueError:
        sid, aid = "datasets", "builtin"
    meta = assignment_by_ids(sid, aid) or {}

    ctx = load_assignment_context(assignment_key)
    system = (
        f"{COACH_BASE}\n\n{meta.get('coach_system', '')}\n\n"
        "## Assignment context (read before answering)\n\n"
        f"{ctx}\n\n"
        "Use **execute_python** for computed results or PyRIT APIs. "
        "Use **fetch_dataset_seed_preview_tool** to load sample seeds from named built-in datasets. "
        "Use **run_workshop_runner** for the one-click default. "
        "Do not invent tool outputs."
    )

    messages = [SystemMessage(content=system)]
    messages.extend(_history_to_langchain(history))
    messages.append(HumanMessage(content=user_message.strip()))

    result = agent.invoke({"messages": messages})
    out_msgs = result.get("messages", [])
    return _last_ai_text(out_msgs) or "(No response.)"
