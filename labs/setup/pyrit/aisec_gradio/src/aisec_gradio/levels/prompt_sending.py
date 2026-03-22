"""Level 1: PromptSendingAttack + OpenAIChatTarget (matches workshop notebook 00)."""

from __future__ import annotations

import asyncio
import io
import os
from contextlib import redirect_stdout
from pathlib import Path

from dotenv import load_dotenv


def _load_env() -> None:
    base = Path.home() / ".pyrit"
    load_dotenv(base / ".env")
    load_dotenv(base / ".env.local", override=True)


async def run_prompt_sending_async(objective: str, model_name: str | None = None) -> tuple[str, str]:
    """Returns (summary_markdown, error_message_or_empty)."""
    _load_env()
    from pyrit.executor.attack import ConsoleAttackResultPrinter, PromptSendingAttack
    from pyrit.prompt_target import OpenAIChatTarget
    from pyrit.setup import IN_MEMORY, initialize_pyrit_async

    await initialize_pyrit_async(memory_db_type=IN_MEMORY)

    model = (
        model_name
        or os.getenv("OPENAI_CHAT_MODEL")
        or os.getenv("PLATFORM_OPENAI_CHAT_GPT4O_MODEL")
        or "gpt-4o"
    )

    target = OpenAIChatTarget(model_name=model)
    attack = PromptSendingAttack(objective_target=target)
    result = await attack.execute_async(objective=objective)

    lines: list[str] = []
    lines.append(f"**Outcome:** `{getattr(result, 'outcome', 'n/a')}`")
    if getattr(result, "outcome_reason", None):
        lines.append(f"**Reason:** {result.outcome_reason}")
    lines.append("")
    printer = ConsoleAttackResultPrinter()
    buf = io.StringIO()
    with redirect_stdout(buf):
        await printer.print_conversation_async(result=result)
    lines.append("```")
    lines.append(buf.getvalue() or "(no conversation text)")
    lines.append("```")
    return "\n".join(lines), ""


def run_prompt_sending(objective: str, model_name: str | None = None) -> tuple[str, str]:
    try:
        return asyncio.run(run_prompt_sending_async(objective, model_name))
    except Exception as e:
        return "", str(e)
