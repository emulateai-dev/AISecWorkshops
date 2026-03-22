"""Executor-related runners."""

from __future__ import annotations

from aisec_gradio.levels.prompt_sending import run_prompt_sending


def run_prompt_sending_lab(*, objective: str) -> str:
    if not objective or not objective.strip():
        return "Enter an **objective** in the field above, then click **Run for me**."
    text, err = run_prompt_sending(objective.strip())
    if err:
        return f"**PyRIT error:** `{err}`\n\nCheck **Setup** and `~/.pyrit` credentials."
    return text
