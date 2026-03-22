# Executors and attacks (overview)

**Executors** in PyRIT orchestrate how prompts flow: attacks apply strategies (single-shot, multi-turn, benchmarks), use **converters**, send to **targets**, and record results in **memory** with **scorers**.

**Attacks** are higher-level patterns: e.g. prompt sending, role-play, tree search, many-shot—each with different requirements on targets (`PromptChatTarget` vs `PromptTarget`) and configuration.

**Safety**

Run only against systems you **own** or are **explicitly authorized** to test. Tune rate limits and objectives for benign lab use.

**Official docs**

- [Attacks](https://azure.github.io/PyRIT/code/executor/attack/)
