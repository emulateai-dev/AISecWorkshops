"""Section/assignment registry for Red Team workshop (replaces level-based LEVELS)."""

from __future__ import annotations

from typing import Any

# Canonical PyRIT docs (Azure)
PYRIT_LOADING_DATASETS_URL = "https://azure.github.io/PyRIT/code/datasets/loading-datasets/"

# Defaults merged with per-assignment ``sandbox_policy`` for ``execute_python``.
DEFAULT_SANDBOX_POLICY: dict[str, Any] = {
    "timeout_sec": 90,
    "max_output_chars": 200_000,
    "allow_network": False,
}

# Assignment keys are "section_id:assignment_id"
SECTIONS: list[dict[str, Any]] = [
    {
        "id": "datasets",
        "title": "Datasets",
        "assignments": [
            {
                "id": "builtin",
                "title": "Built-in Datasets",
                "doc_url": PYRIT_LOADING_DATASETS_URL,
                "summary_relpath": "datasets/built_in_summary.md",
                "reference_files": [
                    "datasets/built_in_summary.md",
                ],
                "sandbox_policy": {
                    "timeout_sec": 120,
                    "allow_network": True,
                },
                "coach_system": (
                    "You are a lab coach for PyRIT datasets. Explain built-in vs remote datasets, "
                    "memory vs direct load. Use **execute_python** to run snippets that list datasets or fetch "
                    "sample seeds when the user asks for data. Use **run_workshop_runner** for the one-click "
                    "list-names default. Never invent tool output."
                ),
                "runner_id": "datasets_list_names",
            },
            {
                "id": "seeds_memory_stub",
                "title": "Adding seeds to memory (stub)",
                "doc_url": PYRIT_LOADING_DATASETS_URL,
                "summary_relpath": "datasets/seeds_memory_stub.md",
                "reference_files": ["datasets/seeds_memory_stub.md"],
                "coach_system": (
                    "Stub assignment. Point to PyRIT memory docs. Use execute_python only for small exploratory "
                    "code if appropriate."
                ),
                "runner_id": "stub",
            },
        ],
    },
    {
        "id": "prompt_targets",
        "title": "Prompt Targets",
        "assignments": [
            {
                "id": "overview_stub",
                "title": "OpenAI-compatible targets (stub)",
                "doc_url": "https://azure.github.io/PyRIT/",
                "summary_relpath": "prompt_targets/overview_stub.md",
                "reference_files": ["prompt_targets/overview_stub.md"],
                "coach_system": "Stub: discuss OpenAIChatTarget and env vars OPENAI_CHAT_*.",
                "runner_id": "stub",
            },
        ],
    },
    {
        "id": "converters",
        "title": "Converters",
        "assignments": [
            {
                "id": "overview_stub",
                "title": "Prompt converters (stub)",
                "doc_url": "https://azure.github.io/PyRIT/",
                "summary_relpath": "converters/overview_stub.md",
                "reference_files": ["converters/overview_stub.md"],
                "coach_system": "Stub: converters transform prompts before sending to a target.",
                "runner_id": "stub",
            },
        ],
    },
    {
        "id": "executors",
        "title": "Executors",
        "assignments": [
            {
                "id": "prompt_sending",
                "title": "Prompt sending attack",
                "doc_url": "https://azure.github.io/PyRIT/",
                "summary_relpath": "executors/prompt_sending.md",
                "reference_files": ["executors/prompt_sending.md"],
                "sandbox_policy": {"timeout_sec": 180},
                "coach_system": (
                    "Coach on PromptSendingAttack. For **run_workshop_runner** pass the user's objective when they "
                    "want the default attack run. Authorized testing only."
                ),
                "runner_id": "executors_prompt_sending",
            },
            {
                "id": "more_stub",
                "title": "More attacks (stub)",
                "doc_url": "https://azure.github.io/PyRIT/",
                "summary_relpath": "executors/more_stub.md",
                "reference_files": ["executors/more_stub.md"],
                "coach_system": "Stub for additional executor types.",
                "runner_id": "stub",
            },
        ],
    },
]


def merge_sandbox_policy(meta: dict[str, Any] | None) -> dict[str, Any]:
    """Merge DEFAULT_SANDBOX_POLICY with assignment ``sandbox_policy``."""
    out = dict(DEFAULT_SANDBOX_POLICY)
    if meta and meta.get("sandbox_policy"):
        out.update(meta["sandbox_policy"])
    return out


def section_by_id(section_id: str) -> dict[str, Any] | None:
    for s in SECTIONS:
        if s["id"] == section_id:
            return s
    return None


def assignment_by_ids(section_id: str, assignment_id: str) -> dict[str, Any] | None:
    s = section_by_id(section_id)
    if not s:
        return None
    for a in s["assignments"]:
        if a["id"] == assignment_id:
            return a
    return None


def assignment_key(section_id: str, assignment_id: str) -> str:
    return f"{section_id}:{assignment_id}"


def parse_assignment_key(key: str) -> tuple[str, str]:
    if ":" not in key:
        raise ValueError(f"Invalid assignment key: {key}")
    a, b = key.split(":", 1)
    return a, b


def radio_choices_for_section(section_id: str) -> list[tuple[str, str]]:
    """Gradio ``Radio`` tuples are ``(display_name, value)`` — value is ``section_id:assignment_id``."""
    s = section_by_id(section_id)
    if not s:
        return []
    return [(a["title"], assignment_key(section_id, a["id"])) for a in s["assignments"]]


def default_assignment_key() -> str:
    first = SECTIONS[0]["assignments"][0]
    return assignment_key(SECTIONS[0]["id"], first["id"])
