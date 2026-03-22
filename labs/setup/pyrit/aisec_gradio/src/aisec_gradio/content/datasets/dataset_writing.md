# Writing your own datasets

For real red-teaming work you often **author datasets**—either checked into PyRIT-style definitions or stored in your database. This assignment summarizes PyRIT’s **dataset writing** guidance: how to phrase objectives, structure components, and operate responsibly at scale.

**Official doc:** [Writing Your Own Datasets](https://azure.github.io/PyRIT/code/datasets/dataset-writing/)

**Local PyRIT reference (submodule):** `PyRIT/doc/code/datasets/3_dataset_writing.md`

The **Sample code** panel shows a small `SeedObjective` example illustrating specific vs vague wording (no API calls).

## Seed objectives: be specific

Objectives drive **scorers** and success criteria. Vague objectives allow models to answer in abstract ways that stay inside policy, which makes evaluation ambiguous. Prefer **concrete, testable** wording aligned to what you actually want to measure (see examples in the official guide—framed for safety research, not misuse).

## One task per LLM component

Split responsibilities: e.g. separate **refusal detection** from **harm scoring** into different scorers instead of one model doing everything. Narrow tasks tend to **improve accuracy** in practice.

## Database as source of truth

When possible, treat the **memory database** as the system of record: normalized data, **traceability**, reuse, and collaboration. Pair with good hygiene for sensitive red-team content.

## See also

- [Creating seeds programmatically and with YAML](https://azure.github.io/PyRIT/code/datasets/seed-programming/)
- [Loading built-in datasets](https://azure.github.io/PyRIT/code/datasets/loading-datasets/)
