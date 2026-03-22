"""LangChain tools: sandboxed Python + workshop runners."""

from __future__ import annotations

from langchain_core.tools import tool

from aisec_gradio.agent.sandbox import format_sandbox_result, run_python_sandbox
from aisec_gradio.runners import run_assignment
from aisec_gradio.runners.datasets import fetch_dataset_seed_preview
from aisec_gradio.workshop_registry import assignment_by_ids, merge_sandbox_policy, parse_assignment_key


def make_tools(assignment_key: str) -> list:
    """Build tool callables bound to the current assignment (policy + runner_id)."""
    try:
        sid, aid = parse_assignment_key(assignment_key)
    except ValueError:
        sid, aid = "datasets", "builtin"
    meta = assignment_by_ids(sid, aid) or {}
    policy = merge_sandbox_policy(meta)

    @tool
    def execute_python(code: str) -> str:
        """Execute Python in an isolated subprocess (same interpreter as this app). Use for PyRIT, prints, imports. Returns stdout/stderr."""
        res = run_python_sandbox(code, policy)
        return format_sandbox_result(res)

    @tool
    def run_workshop_runner(objective: str = "") -> str:
        """Run this assignment's default workshop runner (same as the Run for me button). For prompt-sending, pass the objective text."""
        rid = meta.get("runner_id", "stub")
        return run_assignment(rid, objective=objective)

    @tool
    def fetch_dataset_seed_preview_tool(dataset_names: str, max_seeds: int = 5) -> str:
        """Fetch built-in PyRIT datasets by name and show sample seed values (comma-separated names). May use network/HF cache."""
        return fetch_dataset_seed_preview(dataset_names, max_seeds=max_seeds)

    return [execute_python, run_workshop_runner, fetch_dataset_seed_preview_tool]
