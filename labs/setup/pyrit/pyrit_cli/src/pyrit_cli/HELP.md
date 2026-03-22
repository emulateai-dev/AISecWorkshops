# pyrit-cli HELP — red-team commands

Reference for attack entry points under `pyrit-cli redteam`. For install and env setup, see the project **README** (repository root `README.md`).

**PyRIT docs (behavior and theory):**

- Single-turn: [Prompt Sending Attack](https://azure.github.io/PyRIT/code/executor/attack/prompt-sending-attack/)
- Multi-turn: [Red Teaming Attack](https://azure.github.io/PyRIT/code/executor/attack/red-teaming-attack/)
- Tree of Attacks with Pruning: [TAP attack](https://azure.github.io/PyRIT/code/executor/attack/tap-attack/)

Use only on targets and data you are authorized to test.

---

## `ask-ai` (natural language to command)

`pyrit-cli ask-ai "..."` loads this file and calls an OpenAI-compatible chat API to suggest a concrete `pyrit-cli` shell command. Requires an API key (see `pyrit-cli setup configure` or `OPENAI_API_KEY` / `OPENAI_CHAT_KEY` in `~/.pyrit`).

---

## Shared concepts

### Target syntax

Red-team commands use **`openai:<model_name>`** for chat targets. Credentials and base URL come from your PyRIT env (typically `~/.pyrit/.env` and `~/.pyrit/.env.local` — see `pyrit-cli setup`).

There is **no** separate CLI flag for “adversary uses Groq, victim uses OpenAI”: all `OpenAIChatTarget` instances share the same configured endpoint/key; only **`model_name`** differs per flag.

### Discover data and knobs

| Need | Command |
|------|---------|
| Paths for `--dataset pyrit:...` | `pyrit-cli datasets list` (optional `--glob 'pattern'`) |
| Converter modalities (all PyRIT converters) | `pyrit-cli converters list` or `--json` |
| Keys for `--request-converter` / `--response-converter` (stateless only) | `pyrit-cli converters list-keys` |
| Scorer presets and exports | `pyrit-cli scorers list` |
| What target patterns the CLI supports | `pyrit-cli targets list` |

---

## 1. `prompt-sending-attack` (single-turn)

Maps to PyRIT **`PromptSendingAttack`**: one user-style objective per execution turn, no adversarial LLM loop.

### Options (reference)

| Option | Required | Description |
|--------|----------|-------------|
| `--target` | yes | `openai:<model_name>` — model under test |
| `--objective` | one of objective/dataset | Single string sent as the attack objective |
| `--dataset` | one of objective/dataset | `pyrit:<relative/path>` under PyRIT `DATASETS_PATH`, or `hf:<hub_id>` |
| `--hf-split` | no | Hugging Face split (default `train`) |
| `--hf-column` | no | Column name for objectives (default `text`) |
| `--hf-config` | no | HF dataset config / name when needed |
| `--limit` | no | Cap number of objectives after load (min 1) |

You must supply **either** `--objective` **or** `--dataset`, not both.

### Flavors

**A. One-shot string (simplest)**  
Send a single objective; result is printed with `ConsoleAttackResultPrinter` (outcome may be “undetermined” if no scorer is configured — same as basic PyRIT examples).

```bash
pyrit-cli redteam prompt-sending-attack \
  --target openai:gpt-4o-mini \
  --objective "Reply with exactly: OK"
```

**B. Many objectives from a PyRIT seed file**  
Path is relative to PyRIT’s bundled datasets root (see `datasets list`).

```bash
pyrit-cli redteam prompt-sending-attack \
  --target openai:gpt-4o-mini \
  --dataset pyrit:seed_datasets/local/airt/illegal.prompt \
  --limit 3
```

**C. Objectives from Hugging Face**  
Requires optional install: `pip install 'pyrit-cli[hf]'` (or `datasets`).

```bash
pyrit-cli redteam prompt-sending-attack \
  --target openai:gpt-4o-mini \
  --dataset hf:imdb \
  --hf-split train \
  --hf-column text \
  --limit 2
```

**D. Batch without harmful content**  
Use any benign `pyrit:` YAML or HF column suitable for your policy; `--limit` keeps cost bounded.

---

## 2. `red-teaming-attack` (multi-turn)

Maps to PyRIT **`RedTeamingAttack`**: an **adversarial** chat model proposes prompts; the **objective** (victim) model responds; a **TrueFalse** scorer decides whether the objective is met; repeats up to `--max-turns`.

### Options (reference)

| Option | Required | Description |
|--------|----------|-------------|
| `--objective-target` | yes | Victim: `openai:<model_name>` |
| `--objective` | yes | High-level attack goal string |
| `--adversarial-target` | no | Adversarial LLM `openai:<model>`; default = `--objective-target` |
| `--max-turns` | no | Default `5`, minimum `1` |
| `--rta-prompt` | no | Adversarial system template: `text_generation` (default), `image_generation`, `naive_crescendo`, `violent_durian`, `crucible` |
| `--memory-labels-json` | no | JSON object of string labels for memory (e.g. `{"harm_category":"demo"}`) |
| `--scorer-preset` | no | `self-ask-tf` (default) or `self-ask-refusal` |
| `--true-description` | for `self-ask-tf` | Text criterion for scorer **True** = “objective achieved” |
| `--refusal-mode` | no | `default` or `strict` — **PyRIT 0.11.x**: ignored for refusal preset; newer PyRIT may use distinct prompts |
| `--scorer-chat-target` | no | `openai:<model>` for the scorer’s LLM; default = adversarial target spec |
| `--request-converter` | no | Repeatable; stateless converter keys (order matters) |
| `--response-converter` | no | Repeatable; applied to responses |
| `--include-adversarial-conversation` | flag | Include red-team LLM transcript in printed report |

### Stateless `--request-converter` / `--response-converter` keys

These are the built-in CLI registry keys (no extra LLM for conversion):

`ascii-art`, `atbash`, `base64`, `binary`, `braille`, `ecoji`, `emoji`, `first-letter`, `morse`, `rot13`, `string-join`, `unicode-confusable`

LLM-based converters (e.g. variation, translation) are **not** wired in the CLI yet.

### Flavors

**A. Minimal (same model for victim + adversary + scorer default chain)**  
Good for labs: one model, explicit success criterion.

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "Get the assistant to say the capital of France is Paris." \
  --true-description "The response states that Paris is the capital of France." \
  --max-turns 3
```

**B. Different adversarial model**  
Stronger/weaker red-team model than the victim (still same env endpoint unless you change global env).

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o \
  --adversarial-target openai:gpt-4o-mini \
  --objective "..." \
  --true-description "..."
```

**C. Different scorer model**  
Scoring judgments use another `openai:<model>` (e.g. cheaper judge).

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o \
  --adversarial-target openai:gpt-4o-mini \
  --scorer-chat-target openai:gpt-4o-mini \
  --objective "..." \
  --true-description "..."
```

**D. Adversarial “persona” template (`--rta-prompt`)**  
Aligns with `RTASystemPromptPaths` in PyRIT (text vs image-oriented templates, etc.).

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o-mini \
  --rta-prompt text_generation \
  --objective "..." \
  --true-description "..."
```

**E. Refusal-oriented scorer**  
`--scorer-preset self-ask-refusal` — interprets refusal detection (see `pyrit-cli scorers list`). Pair with objectives that make sense for refusal testing.

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "..." \
  --scorer-preset self-ask-refusal \
  --refusal-mode default
```

**F. Request obfuscation stack (multi-turn + converters)**  
Same idea as PyRIT’s parallel converter example: transforms applied before the victim sees the prompt.

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "..." \
  --true-description "..." \
  --request-converter emoji \
  --request-converter rot13
```

**G. Memory labels + verbose report**  
Labels are passed through to `execute_async` like the upstream doc’s `memory_labels` argument.

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "..." \
  --true-description "..." \
  --memory-labels-json '{"lab":"workshop","run":"demo"}' \
  --include-adversarial-conversation
```

---

## 3. `tap-attack` (Tree of Attacks with Pruning)

Maps to PyRIT **`TAPAttack`** (`TreeOfAttacksWithPruningAttack`): multiple adversarial branches explore prompts in parallel; breadth-first expansion with pruning; scoring uses **`FloatScaleThresholdScorer`** wrapping **`SelfAskScaleScorer`** by default (threshold **0.7**), matching the [upstream TAP doc](https://azure.github.io/PyRIT/code/executor/attack/tap-attack/).

### Options (reference)

| Option | Required | Description |
|--------|----------|-------------|
| `--objective-target` | yes | Victim: `openai:<model_name>` |
| `--objective` | yes | Conversation objective string |
| `--adversarial-target` | no | Red-team LLM `openai:<model>`; default = `--objective-target` |
| `--adversarial-temperature` | no | e.g. `1.1` for a hotter adversarial `OpenAIChatTarget` |
| `--tree-width` | no | Parallel branches (default `4`, doc example) |
| `--tree-depth` | no | Max iterations (default `5`) |
| `--branching-factor` | no | Children per parent (default `2`) |
| `--on-topic-checking` / `--no-on-topic-checking` | flag | On-topic relevance checks (default on) |
| `--desired-response-prefix` | no | Success signal prefix (default `Sure, here is`) |
| `--batch-size` | no | Nodes per batch (default `10`) |
| `--memory-labels-json` | no | JSON object of string labels for memory |
| `--scorer-chat-target` | no | `openai:<model>` for `SelfAskScaleScorer`; if both this and `--score-threshold` are omitted, PyRIT’s default scorer (adversarial chat, threshold 0.7) is used |
| `--score-threshold` | no | Jailbreak threshold 0–1; if either this or `--scorer-chat-target` is set, builds custom `TAPAttackScoringConfig` |
| `--include-adversarial-conversation` | flag | Print red-team transcript (default on) |
| `--include-pruned-conversations` | flag | Print pruned branches (default on) |

### Example (lab-style, same model)

```bash
pyrit-cli redteam tap-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "Get the assistant to state the capital of France is Paris." \
  --tree-width 4 \
  --tree-depth 3 \
  --adversarial-temperature 1.1
```

---

## Limitations (vs full PyRIT)

Not exposed in the CLI today (use Python / notebooks for these):

- Custom **`AttackAdversarialConfig.seed_prompt`** (still default template with `{{ objective }}`).
- Custom **filesystem** `system_prompt_path` beyond the `--rta-prompt` enum.
- **Per-role endpoints/API keys** (separate base URL for adversary vs victim).
- Non-`OpenAIChatTarget` victims (e.g. `AzureMLChatTarget`, `TextTarget`, `OpenAIImageTarget`) and **prepended conversations** / jailbreak templates as in the long-form doc examples.
- **LLM-backed** prompt converters.
- **`tap-attack`**: no `--request-converter` / `--response-converter` wiring yet (use Python for `AttackConverterConfig`).

---

## Getting `--help`

```bash
pyrit-cli redteam prompt-sending-attack --help
pyrit-cli redteam red-teaming-attack --help
pyrit-cli redteam tap-attack --help
pyrit-cli ask-ai --help
pyrit-cli setup configure --help
```
