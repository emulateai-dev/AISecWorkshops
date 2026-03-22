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
