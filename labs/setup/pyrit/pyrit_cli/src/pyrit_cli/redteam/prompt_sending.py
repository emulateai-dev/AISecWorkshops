"""PromptSendingAttack runner (see PyRIT docs)."""

from __future__ import annotations

import asyncio
from collections.abc import Sequence
from pathlib import Path

from pyrit.common.path import DATASETS_PATH
from pyrit.executor.attack import ConsoleAttackResultPrinter, PromptSendingAttack
from pyrit.models import SeedDataset
from pyrit.setup import IN_MEMORY, initialize_pyrit_async

from pyrit_cli.redteam.targets import openai_chat_from_spec


def resolve_pyrit_dataset_path(spec: str) -> Path:
    """spec is path after 'pyrit:' prefix."""
    raw = spec[6:].strip() if spec.lower().startswith("pyrit:") else spec.strip()
    p = Path(raw).expanduser()
    if p.is_absolute():
        return p
    return (Path(DATASETS_PATH) / raw).resolve()


def load_objectives_from_pyrit_dataset(spec: str) -> Sequence[str]:
    path = resolve_pyrit_dataset_path(spec)
    if not path.is_file():
        raise FileNotFoundError(f"PyRIT dataset file not found: {path}")
    ds = SeedDataset.from_yaml_file(path)
    return list(ds.get_values())


def load_objectives_from_hf(
    repo_id: str,
    *,
    split: str,
    column: str,
    config: str | None,
) -> list[str]:
    try:
        from datasets import load_dataset
    except ImportError as e:
        raise ImportError(
            "Hugging Face datasets require: pip install 'pyrit-cli[hf]' or pip install datasets"
        ) from e

    kwargs: dict = {}
    if config:
        kwargs["name"] = config
    ds = load_dataset(repo_id, split=split, **kwargs)
    col = ds[column]
    return [str(x) for x in col if x is not None and str(x).strip()]


def collect_objectives(
    objective: str | None,
    dataset: str | None,
    *,
    hf_split: str,
    hf_column: str,
    hf_config: str | None,
    limit: int | None,
) -> list[str]:
    if dataset and objective:
        raise ValueError("Use either --objective or --dataset, not both.")
    if not dataset and not objective:
        raise ValueError("Provide --objective or --dataset.")

    if objective:
        obs = [objective.strip()]
    elif dataset.lower().startswith("pyrit:"):
        obs = list(load_objectives_from_pyrit_dataset(dataset))
    elif dataset.lower().startswith("hf:"):
        repo_id = dataset.split(":", 1)[1].strip()
        if not repo_id:
            raise ValueError("Invalid --dataset hf:; need hf:<org/dataset>")
        obs = load_objectives_from_hf(
            repo_id, split=hf_split, column=hf_column, config=hf_config
        )
    else:
        raise ValueError(
            "Invalid --dataset; use pyrit:<path_under_pyrit_datasets> or hf:<hub_dataset_id>"
        )

    if limit is not None:
        obs = obs[:limit]
    if not obs:
        raise ValueError("No objectives after loading dataset / applying --limit.")
    return obs


async def run_prompt_sending_async(target: str, objectives: Sequence[str]) -> None:
    await initialize_pyrit_async(memory_db_type=IN_MEMORY)  # type: ignore[arg-type]

    chat_target = openai_chat_from_spec(target)
    attack = PromptSendingAttack(objective_target=chat_target)
    printer = ConsoleAttackResultPrinter()

    for obj in objectives:
        result = await attack.execute_async(objective=obj)  # type: ignore[misc]
        await printer.print_result_async(result)


def run_prompt_sending(target: str, objectives: Sequence[str]) -> None:
    asyncio.run(run_prompt_sending_async(target, objectives))
