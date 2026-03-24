# Assignment 11: Author a Custom Jailbreak Template (YAML)

**Time:** ~25 minutes  
**Difficulty:** Intermediate  
**Models:** Ollama (local) recommended; any `pyrit-cli` chat target works

---

## Objective

Learn how **PyRIT** loads jailbreak-style prompts from **YAML** (`SeedPrompt` + `TextJailBreak`), validate your file with **`pyrit-cli`**, and run a **single-turn** attack with your template—using only **benign** objectives unless your instructor supplies otherwise.

---

## Policy and scope

- This lab is about **file format and tooling**, not about crafting effective harmful jailbreaks.
- Use **mechanical** objectives for demos (e.g. `Reply with exactly: OK`) or text **approved by your instructor**.
- For upstream PyRIT, treat templates under [`pyrit/datasets/jailbreak/templates/`](../../../setup/pyrit/PyRIT/pyrit/datasets/jailbreak/templates/) as the **format reference** (paths may change between PyRIT versions).

---

## Background: PyRIT YAML vs generic “template” snippets

PyRIT jailbreak YAML files are **`SeedPrompt`** documents. They are **not** arbitrary keys like a top-level `template:` block.

A minimal shape matches shipped examples (see e.g. `dan_1.yaml` / `role_play.yaml` in PyRIT):

| Field | Role |
|-------|------|
| `name` | Short title |
| `description` | Human-readable summary |
| `parameters` | List of template variables; include **`prompt`** so the attack can inject the objective |
| `data_type` | Usually `text` |
| `value` | The template body; use Jinja-style placeholders such as **`{{ prompt }}`** where the objective should appear |

Optional fields (`authors`, `source`, …) match other shipped seeds.

---

## Step 1 — Start from the workshop example

This repo includes a **benign** starter file:

[`templates/workshop_custom_benign.yaml`](./templates/workshop_custom_benign.yaml)

Copy it to a new name (e.g. `my_lab_template.yaml`) in the same folder or your own directory, then edit **`name`**, **`description`**, and **`value`** while keeping **`parameters: [prompt]`** and a **`{{ prompt }}`** placeholder somewhere in `value`.

**Same text as `jailbreak-templates inspect better_dan.yaml`:** This repo also ships [`templates/workshop_better_dan_copy.yaml`](./templates/workshop_better_dan_copy.yaml)—a byte-for-byte copy of PyRIT’s bundled `better_dan.yaml` (dual `[GPT]:` / `[BetterDAN]:` framing, etc.). Use it to compare **`inspect better_dan.yaml`** vs **`inspect`** on a **filesystem path**, and to run **`--jailbreak-template`** against a local file. **Not** a benign template; use only in **authorized** lab settings. The starter file above stays policy-safe for format-only exercises.

---

## Step 2 — Validate with `pyrit-cli` (any path)

**`jailbreak-templates inspect`** accepts either a **shipped basename** (e.g. `dan_1.yaml`) or a **path to your file** when that path exists on disk.

From the workshop repo (adjust the path to your copy):

```bash
pyrit-cli jailbreak-templates inspect \
  labs/llms/red-teaming/jailbreaks/templates/my_lab_template.yaml
```

Fix any render errors (missing `{{ prompt }}`, bad YAML, extra required parameters). If your template declares **more** than `prompt` under `parameters`, pass **`--param key=value`** to `inspect` (repeatable), same idea as **`--jailbreak-template-param`** on attacks.

---

## Step 3 — Run with `pyrit-cli` (custom path)

**`pyrit-cli`** resolves **`--jailbreak-template`** as follows:

- If the string is a **path to an existing file**, that file is loaded with `TextJailBreak(template_path=...)`.
- Otherwise it is treated as a **basename** inside PyRIT’s bundled jailbreak directory (`TextJailBreak(template_file_name=...)`).

Example (benign objective):

```bash
pyrit-cli redteam prompt-sending-attack \
  --target ollama:qwen3:0.6b \
  --objective "Reply with exactly: OK" \
  --jailbreak-template labs/llms/red-teaming/jailbreaks/templates/my_lab_template.yaml \
  --scoring-mode auto
```

**`red-teaming-attack`** supports the same **`--jailbreak-template`** behavior for the victim prepended context (see [HELP.md](../../../setup/pyrit/pyrit_cli/src/pyrit_cli/HELP.md)).

---

## Step 4 — Optional: Python (same mechanism as the CLI)

Useful if you are not using the CLI or want to script batches. This mirrors **`PromptSendingAttack`** + prepended conversation:

```python
import asyncio
import os
from pathlib import Path

from pyrit.datasets import TextJailBreak
from pyrit.executor.attack import AttackExecutor, ConsoleAttackResultPrinter, PromptSendingAttack
from pyrit.models import Message
from pyrit.prompt_target import OpenAIChatTarget
from pyrit.setup import IN_MEMORY, initialize_pyrit_async


def ollama_openai_target(model: str = "qwen3:0.6b") -> OpenAIChatTarget:
    h = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434").strip()
    base = h if h.startswith("http") else f"http://{h}"
    base = base.rstrip("/")
    if not base.endswith("/v1"):
        base = f"{base}/v1"
    return OpenAIChatTarget(
        model_name=model,
        endpoint=base,
        api_key="not-needed",
        is_json_supported=False,
    )


async def main() -> None:
    await initialize_pyrit_async(memory_db_type=IN_MEMORY)

    template_path = Path("labs/llms/red-teaming/jailbreaks/templates/workshop_custom_benign.yaml").resolve()
    jb = TextJailBreak(template_path=str(template_path))
    prepended = [Message.from_system_prompt(jb.get_jailbreak_system_prompt())]

    target = ollama_openai_target()
    attack = PromptSendingAttack(objective_target=target, attack_scoring_config=None)
    executor = AttackExecutor()
    printer = ConsoleAttackResultPrinter()

    results = await executor.execute_attack_async(
        attack=attack,
        objectives=["Reply with exactly: OK"],
        prepended_conversation=prepended,
    )
    for r in results:
        await printer.print_result_async(r)


if __name__ == "__main__":
    asyncio.run(main())
```

Run from the **AISecWorkshops repo root** (or change `template_path`). Enable scoring by building an `AttackScoringConfig` like in [Benchmarking Model Safety](./benchmarking_safety.md).

---

## Deliverables

1. Your **`my_lab_template.yaml`** (or equivalent): what you changed vs `workshop_custom_benign.yaml` and why.
2. Output or notes from **`jailbreak-templates inspect`** on your file.
3. One **`prompt-sending-attack`** run (or Python run) with a **benign** objective: did the model comply, refuse, or partially comply? Why might the template matter?

---

## References

- Bundled CLI reference: [HELP.md](../../../setup/pyrit/pyrit_cli/src/pyrit_cli/HELP.md) (`jailbreak-templates inspect`, `prompt-sending-attack`, `red-teaming-attack`)
- PyRIT prepended conversation behavior: [Prompt Sending Attack](https://azure.github.io/PyRIT/code/executor/attack/prompt-sending-attack/)
- Shipped YAML examples: `labs/setup/pyrit/PyRIT/pyrit/datasets/jailbreak/templates/`

---

**Back to:** [LLM Jailbreaks index](./README.md)
