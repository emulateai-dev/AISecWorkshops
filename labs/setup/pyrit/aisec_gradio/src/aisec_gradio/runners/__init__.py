"""Dispatch PyRIT workshop runners by ``runner_id``."""

from __future__ import annotations

from typing import Callable

from aisec_gradio.runners import datasets as datasets_runners
from aisec_gradio.runners import executors as executors_runners
from aisec_gradio.runners.stub_runners import run_stub

RunnerFn = Callable[..., str]

_REGISTRY: dict[str, RunnerFn] = {
    "datasets_list_names": datasets_runners.run_list_builtin_dataset_names,
    "datasets_seed_programming": datasets_runners.run_seed_programming_demo,
    "datasets_dataset_writing": datasets_runners.run_dataset_writing_demo,
    "stub": run_stub,
    "executors_prompt_sending": executors_runners.run_prompt_sending_lab,
}


def run_assignment(runner_id: str, *, objective: str = "") -> str:
    fn = _REGISTRY.get(runner_id)
    if not fn:
        return f"**Unknown runner:** `{runner_id}`"
    try:
        if runner_id == "executors_prompt_sending":
            return fn(objective=objective)
        return fn()
    except Exception as e:
        return f"**Error:** `{type(e).__name__}: {e}`"
