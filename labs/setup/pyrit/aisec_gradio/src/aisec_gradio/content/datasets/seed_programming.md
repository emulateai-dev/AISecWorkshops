# Creating seeds programmatically and with YAML

PyRIT models test content as **seeds**: objectives, prompts, multimodal pieces, and groupings. This assignment follows the official **seed programming** guide—create seeds in Python or declare them in YAML, then wire them into attacks and executors.

**Official doc:** [Creating Seeds Programmatically and with YAML](https://azure.github.io/PyRIT/code/datasets/seed-programming/)

**Local PyRIT reference (submodule):** `PyRIT/doc/code/datasets/2_seed_programming.ipynb` / `2_seed_programming.py`

The workshop UI includes **Sample code** below the summary: a text-only `SeedAttackGroup` that prints parameters from `PromptSendingAttack` (benign objective). For multimodal and YAML sections, follow the official notebook.

## Concepts

- **Attack parameters:** Many attacks consume an **objective**, an optional **next message**, and optional **prepended conversation**. Attacks expose patterns like `from_seed_group` to derive these from a **`SeedAttackGroup`**.
- **Building groups in code:** You can assemble `SeedObjective`, `SeedPrompt` (roles, `data_type` such as text or `image_path`), and related types to describe multi-turn or multimodal setup—then inspect how parameters map before executing.
- **Execution:** `AttackExecutor` can run attacks from seed groups so orchestration stays consistent with the rest of PyRIT (targets, scorers, memory).
- **YAML:** Declarative definitions for prompts, objectives, groups, and datasets—useful for version control, reuse, and sharing cases across a team. Load paths such as `SeedPrompt.from_yaml_file(...)` or dataset YAML as described in the doc.

## Lab safety

Use **authorized endpoints** and **benign objectives** in examples. Copy patterns from the official notebook, not harmful scenarios. The coach may use **execute_python** only for small, safe snippets in the sandbox.

## See also

- [Loading built-in datasets](https://azure.github.io/PyRIT/code/datasets/loading-datasets/)
- [Writing your own datasets](https://azure.github.io/PyRIT/code/datasets/dataset-writing/)
