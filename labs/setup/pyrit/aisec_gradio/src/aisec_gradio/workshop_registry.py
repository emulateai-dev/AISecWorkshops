"""Section/assignment registry for Red Team workshop (replaces level-based LEVELS)."""

from __future__ import annotations

from typing import Any

# Canonical PyRIT docs (Azure)
PYRIT_BASE_URL = "https://azure.github.io/PyRIT/"
PYRIT_LOADING_DATASETS_URL = "https://azure.github.io/PyRIT/code/datasets/loading-datasets/"
PYRIT_SEED_PROGRAMMING_URL = "https://azure.github.io/PyRIT/code/datasets/seed-programming/"
PYRIT_DATASET_WRITING_URL = "https://azure.github.io/PyRIT/code/datasets/dataset-writing/"

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
                "id": "seed_programming",
                "title": "Creating seeds programmatically and YAML",
                "doc_url": PYRIT_SEED_PROGRAMMING_URL,
                "summary_relpath": "datasets/seed_programming.md",
                "reference_files": [],
                "coach_system": (
                    "Coach on PyRIT seed programming: SeedPrompt, SeedObjective, SeedAttackGroup, "
                    "from_seed_group / params, AttackExecutor, YAML vs code, SeedDataset.from_yaml_file. "
                    "Use benign examples only; do not reproduce harmful content from upstream docs. "
                    "**run_workshop_runner** runs the bundled seed-group → parameter extraction demo (no model fire)."
                ),
                "runner_id": "datasets_seed_programming",
            },
            {
                "id": "dataset_writing",
                "title": "Writing your own datasets",
                "doc_url": PYRIT_DATASET_WRITING_URL,
                "summary_relpath": "datasets/dataset_writing.md",
                "reference_files": [],
                "coach_system": (
                    "Coach on writing datasets: specific seed objectives, one task per LLM/scorer, "
                    "database as source of truth, traceability. "
                    "**run_workshop_runner** prints the sample tight-objective example from the lab."
                ),
                "runner_id": "datasets_dataset_writing",
            },
        ],
    },
    {
        "id": "prompt_targets",
        "title": "Prompt Targets",
        "assignments": [
            {
                "id": "intro",
                "title": "Prompt targets intro",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "prompt_targets/intro.md",
                "reference_files": [],
                "coach_system": (
                    "Explain PromptTarget vs PromptChatTarget, send_prompt_async, and multimodal targets. "
                    "Reference the assignment markdown. "
                    "**run_workshop_runner** is stub."
                ),
                "runner_id": "stub",
            },
            {
                "id": "openai_chat",
                "title": "OpenAI Chat Target",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "prompt_targets/openai_chat.md",
                "reference_files": ["prompt_targets/intro.md"],
                "coach_system": (
                    "Coach on OpenAIChatTarget, environment variables, and OpenAI-compatible endpoints. "
                    "Use **execute_python** only with benign examples and authorized keys. "
                    "**run_workshop_runner** is stub."
                ),
                "runner_id": "stub",
            },
            {
                "id": "openai_completions",
                "title": "OpenAI Completions",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "prompt_targets/openai_completions.md",
                "reference_files": ["prompt_targets/intro.md"],
                "coach_system": (
                    "Contrast completions vs chat targets; discuss when a completions-style API fits. "
                    "**run_workshop_runner** is stub."
                ),
                "runner_id": "stub",
            },
        ],
    },
    {
        "id": "converters",
        "title": "Converters",
        "assignments": [
            {
                "id": "intro",
                "title": "Converters intro",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "converters/intro.md",
                "reference_files": [],
                "coach_system": (
                    "Explain what converters do in the pipeline (before targets). "
                    "Mention text-to-text vs multimodal vs interactive. **run_workshop_runner** is stub."
                ),
                "runner_id": "stub",
            },
            {
                "id": "text_to_text",
                "title": "Text-to-text converters",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "converters/text_to_text.md",
                "reference_files": ["converters/intro.md"],
                "coach_system": (
                    "Coach on encoding, obfuscation, translation-style converters. "
                    "Use **execute_python** for small, safe experiments only."
                ),
                "runner_id": "stub",
            },
            {
                "id": "multimodal",
                "title": "Multimodal converters",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "converters/multimodal.md",
                "reference_files": ["converters/intro.md"],
                "coach_system": (
                    "Explain image/audio/video/file converters and pairing with multimodal targets. "
                    "Warn about large assets and network use in sandbox."
                ),
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
                "doc_url": PYRIT_BASE_URL,
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
                "id": "role_play_attack",
                "title": "Role-play attack",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "executors/role_play_attack.md",
                "reference_files": ["executors/intro_attacks.md"],
                "coach_system": (
                    "Explain role-play attack concepts and responsible use. **run_workshop_runner** is stub; "
                    "point to PyRIT notebooks for full runs."
                ),
                "runner_id": "stub",
            },
            {
                "id": "crescendo_attack",
                "title": "Crescendo attack",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "executors/crescendo_attack.md",
                "reference_files": ["executors/intro_attacks.md"],
                "coach_system": (
                    "Explain multi-turn escalation patterns from the docs. **run_workshop_runner** is stub."
                ),
                "runner_id": "stub",
            },
            {
                "id": "flip_attack",
                "title": "Flip attack",
                "doc_url": PYRIT_BASE_URL,
                "summary_relpath": "executors/flip_attack.md",
                "reference_files": ["executors/intro_attacks.md"],
                "coach_system": (
                    "Explain flip attack and chat-history requirements. **run_workshop_runner** is stub."
                ),
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
