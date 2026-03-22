"""LangGraph ReAct agent for the workshop coach + streaming manual ReAct for Gradio."""

from __future__ import annotations

import html
import json
import os
from collections.abc import Iterator
from typing import Any

from aisec_gradio.agent.context import load_assignment_context
from aisec_gradio.agent.sandbox import format_sandbox_result, stream_python_sandbox
from aisec_gradio.agent.tools import make_tools
from aisec_gradio.coach import COACH_BASE, default_model, load_pyrit_env
from aisec_gradio.runners import run_assignment
from aisec_gradio.runners.datasets import fetch_dataset_seed_preview
from aisec_gradio.workshop_registry import assignment_by_ids, merge_sandbox_policy, parse_assignment_key


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


def _copy_gradio_history(history: list[Any]) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for item in history or []:
        if isinstance(item, dict):
            role = item.get("role", "")
            raw = item.get("content", "")
            content = raw if isinstance(raw, str) else str(raw)
            if role in ("user", "assistant") and content:
                out.append({"role": role, "content": content})
        elif isinstance(item, (list, tuple)) and len(item) >= 2:
            u, a = item[0], item[1]
            if u:
                out.append({"role": "user", "content": str(u)})
            if a:
                out.append({"role": "assistant", "content": str(a)})
    return out


def _message_content_to_text(content: Any) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(str(block.get("text", "")))
            elif isinstance(block, str):
                parts.append(block)
            else:
                parts.append(str(block))
        return "".join(parts)
    return str(content)


def _normalize_tool_args(raw: Any) -> dict[str, Any]:
    if raw is None:
        return {}
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            return json.loads(raw)
        except Exception:
            return {}
    return {}


def _last_ai_text(messages: list) -> str:
    from langchain_core.messages import AIMessage

    for m in reversed(messages):
        if isinstance(m, AIMessage):
            return _message_content_to_text(m.content)
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


def _system_and_meta(assignment_key: str) -> tuple[str, dict[str, Any]]:
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
    return system, meta


def _format_coach_reply_with_trace(tool_trace: str, final_text: str) -> str:
    """Gradio Chatbot: collapsible raw program/tool output, then markdown answer (allow details/summary)."""
    ft = (final_text or "").strip() or "(No response.)"
    tr = (tool_trace or "").strip()
    if not tr:
        return ft
    safe = html.escape(tr, quote=False)
    return (
        "<details><summary>Program &amp; tool output</summary>"
        f"<pre><code>{safe}</code></pre></details>\n\n{ft}"
    )


def invoke_workshop_agent(assignment_key: str, history: list[Any], user_message: str) -> str:
    """Run the coach to completion; drain the streaming implementation (single code path)."""
    last = ""
    for state in stream_workshop_agent(assignment_key, history, user_message):
        for m in reversed(state):
            if m.get("role") == "assistant":
                last = m.get("content", "") or ""
                break
    return last.strip() or "(No response.)"


def stream_workshop_agent(
    assignment_key: str,
    history: list[Any],
    user_message: str,
) -> Iterator[list[dict[str, str]]]:
    """Yield Gradio chat history snapshots: user row, then growing assistant (tools + stream)."""
    from langchain_core.messages import AIMessage, HumanMessage, SystemMessage, ToolMessage

    user_message = user_message.strip()
    if not user_message:
        yield _copy_gradio_history(history)
        return

    system, meta = _system_and_meta(assignment_key)
    policy = merge_sandbox_policy(meta)
    runner_id = meta.get("runner_id", "stub")

    model = _chat_model()
    tools = make_tools(assignment_key)
    model_w = model.bind_tools(tools)

    lc_messages: list = [
        SystemMessage(content=system),
        *_history_to_langchain(history),
        HumanMessage(content=user_message),
    ]

    gn = _copy_gradio_history(history)
    gn.append({"role": "user", "content": user_message})
    assistant_buf = "_Thinking…_"
    tool_trace_sections: list[str] = []
    yield list(gn) + [{"role": "assistant", "content": assistant_buf}]

    def emit() -> list[dict[str, str]]:
        return list(gn) + [{"role": "assistant", "content": assistant_buf}]

    def _joined_trace() -> str:
        return "\n\n---\n\n".join(tool_trace_sections)

    max_rounds = 16
    for _ in range(max_rounds):
        full = None
        try:
            for chunk in model_w.stream(lc_messages):
                full = chunk if full is None else full + chunk
                text = _message_content_to_text(full.content)
                if text and not full.tool_calls:
                    assistant_buf = text
                    yield emit()
        except Exception as e:
            err = f"**Error:** `{type(e).__name__}: {e}`"
            assistant_buf = (
                _format_coach_reply_with_trace(_joined_trace(), err) if tool_trace_sections else err
            )
            yield emit()
            return

        if full is None:
            assistant_buf = (
                _format_coach_reply_with_trace(_joined_trace(), "(No response.)")
                if tool_trace_sections
                else "(No response.)"
            )
            yield emit()
            return

        if full.tool_calls:
            lc_messages.append(
                AIMessage(
                    content=full.content,
                    tool_calls=list(full.tool_calls),
                )
            )
            for tc in full.tool_calls:
                tid = tc.get("id") or ""
                name = tc.get("name") or ""
                args = _normalize_tool_args(tc.get("args"))
                tool_body = ""

                if name == "execute_python":
                    code = str(args.get("code", ""))
                    header = "\n\n**execute_python** (live)\n```\n"
                    footer = "\n```\n"
                    live = ""
                    assistant_buf = (assistant_buf if assistant_buf != "_Thinking…_" else "") + header + footer
                    gen = stream_python_sandbox(code, policy)
                    try:
                        while True:
                            try:
                                piece = next(gen)
                                live += piece
                                assistant_buf = (
                                    (assistant_buf.split(header)[0] if header in assistant_buf else "")
                                    + header
                                    + live
                                    + footer
                                )
                                if assistant_buf.strip() in ("", "_Thinking…_"):
                                    assistant_buf = header.strip() + "\n```\n" + live + footer
                                yield emit()
                            except StopIteration as e:
                                sres = e.value
                                break
                    except Exception as ex:
                        sres = None
                        tool_body = f"**sandbox error:** `{type(ex).__name__}: {ex}`"
                    if sres is not None:
                        tool_body = format_sandbox_result(sres)
                    tool_trace_sections.append(
                        f"**execute_python**\n\n```python\n{code}\n```\n\n{tool_body}"
                    )
                    lc_messages.append(ToolMessage(content=tool_body, tool_call_id=tid))

                elif name == "run_workshop_runner":
                    assistant_buf += "\n\n_Running workshop runner…_\n"
                    yield emit()
                    obj = str(args.get("objective", "") or "")
                    try:
                        tool_body = run_assignment(runner_id, objective=obj)
                    except Exception as ex:
                        tool_body = f"**Error:** `{type(ex).__name__}: {ex}`"
                    assistant_buf = assistant_buf.replace("_Running workshop runner…_", "").rstrip() + (
                        f"\n\n**run_workshop_runner**\n{tool_body}\n"
                    )
                    yield emit()
                    tool_trace_sections.append(f"**run_workshop_runner**\n\n{tool_body}")
                    lc_messages.append(ToolMessage(content=tool_body, tool_call_id=tid))

                elif name == "fetch_dataset_seed_preview_tool":
                    assistant_buf += "\n\n_Fetching dataset seeds…_\n"
                    yield emit()
                    names = str(args.get("dataset_names", "") or "")
                    max_seeds = int(args.get("max_seeds", 5) or 5)
                    try:
                        tool_body = fetch_dataset_seed_preview(names, max_seeds=max_seeds)
                    except Exception as ex:
                        tool_body = f"**Error:** `{type(ex).__name__}: {ex}`"
                    assistant_buf = (
                        assistant_buf.replace("_Fetching dataset seeds…_", "").rstrip()
                        + f"\n\n**fetch_dataset_seed_preview_tool**\n{tool_body}\n"
                    )
                    yield emit()
                    tool_trace_sections.append(f"**fetch_dataset_seed_preview_tool**\n\n{tool_body}")
                    lc_messages.append(ToolMessage(content=tool_body, tool_call_id=tid))

                else:
                    tool_body = f"Unknown tool: `{name}`"
                    assistant_buf += f"\n\n{tool_body}\n"
                    yield emit()
                    tool_trace_sections.append(tool_body)
                    lc_messages.append(ToolMessage(content=tool_body, tool_call_id=tid))

            assistant_buf = assistant_buf.replace("_Thinking…_", "").strip() or assistant_buf
            continue

        lc_messages.append(AIMessage(content=full.content))
        final_text = _message_content_to_text(full.content).strip()
        if final_text:
            joined = _joined_trace()
            assistant_buf = (
                _format_coach_reply_with_trace(joined, final_text) if joined.strip() else final_text
            )
            yield emit()
        elif tool_trace_sections:
            assistant_buf = _format_coach_reply_with_trace(_joined_trace(), "(No response.)")
            yield emit()
        return

    note = "_(Stopped: max tool rounds.)_"
    joined = _joined_trace()
    assistant_buf = _format_coach_reply_with_trace(joined, note) if joined.strip() else (assistant_buf + f"\n\n{note}")
    yield emit()
