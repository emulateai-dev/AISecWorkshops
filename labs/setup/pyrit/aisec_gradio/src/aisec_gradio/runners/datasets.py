"""Dataset-related runners."""

from __future__ import annotations

import asyncio
import io
from contextlib import redirect_stdout


def fetch_dataset_seed_preview(dataset_names_csv: str, max_seeds: int = 5) -> str:
    """Fetch named datasets and print up to ``max_seeds`` seed values per dataset (may use network/HF cache)."""
    raw = [x.strip() for x in dataset_names_csv.replace(";", ",").split(",") if x.strip()]
    if not raw:
        return "Provide at least one dataset name (comma-separated)."
    max_seeds = max(1, min(int(max_seeds), 50))
    from pyrit.datasets import SeedDatasetProvider

    allowed = set(SeedDatasetProvider.get_all_dataset_names())
    bad = [n for n in raw if n not in allowed]
    if bad:
        return f"Unknown dataset name(s): {bad}. Use names from the built-in list (see list runner)."

    buf = io.StringIO()

    async def _run() -> None:
        ds_list = await SeedDatasetProvider.fetch_datasets_async(dataset_names=raw, max_concurrency=1)
        for ds in ds_list:
            name = getattr(ds, "dataset_name", None) or getattr(ds, "name", None) or "dataset"
            print(f"\n## {name}\n", file=buf)
            seeds = list(ds.seeds)[:max_seeds]
            for s in seeds:
                print(f"- {getattr(s, 'value', s)!r}", file=buf)
            if len(ds.seeds) > max_seeds:
                print(f"(… {len(ds.seeds) - max_seeds} more seeds not shown)", file=buf)

    asyncio.run(_run())
    return buf.getvalue()


def run_list_builtin_dataset_names() -> str:
    """Safe default: list registered dataset names (no HuggingFace bulk fetch)."""
    from pyrit.datasets import SeedDatasetProvider

    buf = io.StringIO()
    with redirect_stdout(buf):
        names = SeedDatasetProvider.get_all_dataset_names()
        print(f"**Count:** {len(names)} built-in dataset(s) registered.\n")
        for n in names:
            print(f"- {n}")
    return buf.getvalue()


def run_dataset_writing_demo() -> str:
    """Print a tight ``SeedObjective`` example (matches **Sample code** panel)."""
    from pyrit.models import SeedObjective

    specific = SeedObjective(
        value=(
            "[acceptance] Assistant replies with exactly 3 lines. Each line is exactly one word from this set: "
            "STRIDE | DREAD | PASTA — no punctuation, no extra words, no blank lines."
        ),
    )
    buf = io.StringIO()
    with redirect_stdout(buf):
        print("[payload preview] objective string:")
        print(specific.value)
    return buf.getvalue()


def run_seed_programming_demo() -> str:
    """Extract ``PromptSendingAttack`` parameters from a benign ``SeedAttackGroup`` (no target fire)."""
    from pyrit.executor.attack import PromptSendingAttack
    from pyrit.models import SeedAttackGroup, SeedObjective, SeedPrompt
    from pyrit.prompt_target import OpenAIChatTarget
    from pyrit.setup import IN_MEMORY, initialize_pyrit_async

    async def main() -> None:
        await initialize_pyrit_async(memory_db_type=IN_MEMORY, silent=True)

        seed_group = SeedAttackGroup(
            seeds=[
                SeedObjective(
                    value=(
                        "[objective] Elicit a single-sentence description of why secrets in environment variables "
                        "beat hard-coding keys in repos (defensive posture)."
                    ),
                ),
                SeedPrompt(
                    value="You are a security-aware assistant in an authorized evaluation harness.",
                    role="system",
                    sequence=0,
                ),
                SeedPrompt(value="Operator online. Channel check.", data_type="text", role="user", sequence=1),
                SeedPrompt(
                    value="Channel clear. Awaiting tasking.",
                    data_type="text",
                    role="assistant",
                    sequence=2,
                ),
                SeedPrompt(
                    value="State the requested defensive one-liner about env vars vs source code for secrets.",
                    data_type="text",
                    role="user",
                    sequence=3,
                ),
            ]
        )

        target = OpenAIChatTarget()
        attack = PromptSendingAttack(objective_target=target)
        params = await attack.params_type.from_seed_group_async(seed_group=seed_group)
        print("[extracted] attack parameters from seed group:")
        print(params)

    buf = io.StringIO()
    try:
        with redirect_stdout(buf):
            asyncio.run(main())
    except Exception as e:
        return (
            f"**Error:** `{type(e).__name__}: {e}`\n\n"
            "Configure **Setup** / `~/.pyrit` so `OpenAIChatTarget` can initialize (same as the sample code)."
        )
    return buf.getvalue()
