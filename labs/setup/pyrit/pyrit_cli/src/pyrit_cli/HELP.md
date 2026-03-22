# pyrit-cli HELP

Reference for **setup**, **ask-ai**, and **red-team** commands. Install and repo overview: project **README** (repository root `README.md`).

**PyRIT docs (behavior and theory):**

- Single-turn: [Prompt Sending Attack](https://azure.github.io/PyRIT/code/executor/attack/prompt-sending-attack/)
- Multi-turn: [Red Teaming Attack](https://azure.github.io/PyRIT/code/executor/attack/red-teaming-attack/)
- Tree of Attacks with Pruning: [TAP attack](https://azure.github.io/PyRIT/code/executor/attack/tap-attack/)
- Targets overview (incl. Responses API vs chat): [OpenAI Responses Target](https://azure.github.io/PyRIT/code/targets/openai-responses-target/)

Use only on targets and data you are authorized to test.

---

## Setup (`pyrit-cli setup`)

| Command | Purpose |
|---------|---------|
| `pyrit-cli setup` | Print masked status for `~/.pyrit/.env` and `.env.local` (or `PYRIT_ENV_DIR`). |
| `pyrit-cli setup guide` | Short summary of Option A (native OpenAI) vs Option B (OpenAI-compatible platform vars). |
| `pyrit-cli setup configure` | **Interactive wizard**: choose **OpenAI (api.openai.com)** or **OpenAI-compatible** (e.g. Groq), enter API key (hidden prompt), model, and for compatible backends the base URL. Writes `~/.pyrit/.env` and `.env.local` the same way as the aisec-gradio Setup tab. |

After configuring, `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_KEY`, and `OPENAI_CHAT_MODEL` in `.env.local` are what PyRIT’s **`OpenAIChatTarget`** uses for **`openai:`** targets. Provider-specific targets (`groq:`, `ollama:`, etc.) use **additional** env vars documented below.

---

## `ask-ai` (natural language → shell command)

```bash
pyrit-cli ask-ai "Describe what you want to run"
```

Loads **this** HELP text and calls an OpenAI-compatible **`/v1/chat/completions`** API. The model is instructed to:

- List **required environment variables** (with `export VAR=...` examples or “add to `~/.pyrit/.env`”) **whenever** a suggestion uses `groq:`, `ollama:`, `lmstudio:`, `compat:`, or mixed providers — not only `openai:`.
- For **broad or generic** questions (e.g. “how do I test PyRIT?”, “what can I run?”), answer with **several clearly labeled variants** (e.g. single-turn vs multi-turn vs TAP, or different targets), each with prerequisites + command.

**Not** a substitute for reading `--help`; verify suggestions before running.

**Credential resolution (for the ask-ai API call itself, in order):** loads `~/.pyrit/.env` then `.env.local`; then `--api-key`, else `OPENAI_API_KEY`, else `OPENAI_CHAT_KEY` (values starting with `${` are skipped as unresolved).

**Base URL (ask-ai helper only):** `--base-url`, else `OPENAI_CHAT_ENDPOINT`, else `https://api.openai.com/v1`.

| Option | Description |
|--------|-------------|
| `QUERY` (positional) | What you want to do with pyrit-cli. |
| `--model` | Chat model for the helper call (default `gpt-4o-mini` or `OPENAI_CHAT_MODEL`). |
| `--api-key` | Override API key for this call only. |
| `--base-url` | Override API base URL for this call only. |

---

## Environment variables reference (targets)

`pyrit-cli setup configure` sets **`OPENAI_CHAT_*`** for **`openai:`** targets. It does **not** set provider-specific variables below — you must add them yourself (shell `export`, or entries in `~/.pyrit/.env` / `.env.local`).

| If you use | Required | Optional | Notes |
|------------|----------|----------|--------|
| `openai:<model>` | `OPENAI_CHAT_KEY`, `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_MODEL` (or use **setup configure**) | — | Usually loaded from `~/.pyrit`. |
| `groq:<model>` | **`GROQ_API_KEY`** | `GROQ_OPENAI_BASE_URL` | Default base `https://api.groq.com/openai/v1`. Without `GROQ_API_KEY`, Groq targets fail at runtime. |
| `ollama:<model>` | (none for typical local Ollama) | `OLLAMA_HOST`, `OLLAMA_API_KEY` | Default host `127.0.0.1:11434`; endpoint becomes `http://…/v1`. |
| `lmstudio:<model>` | (none if defaults work) | `LMSTUDIO_OPENAI_BASE_URL`, `LMSTUDIO_API_KEY` | Default `http://127.0.0.1:1234/v1`. |
| `compat:<model>` | **`PYRIT_CLI_COMPAT_ENDPOINT`** | `PYRIT_CLI_COMPAT_API_KEY` | Generic OpenAI-compatible server. |

**Example (Groq one-liner before red-team commands):**

```bash
export GROQ_API_KEY="gsk_..."   # from console.groq.com — not the same as OPENAI_CHAT_KEY
pyrit-cli redteam prompt-sending-attack --target groq:llama-3.3-70b-versatile --objective "Reply: OK"
```

---

## Shared concepts

### Target syntax (`<provider>:<model>`)

Red-team commands use PyRIT **`OpenAIChatTarget`** against the **chat completions** OpenAI-compatible HTTP API. The CLI does **not** expose **`OpenAIResponseTarget`** (Responses API); that path is library-only for now.

The **first** `:` separates **provider** from **model**. The model part may contain more colons or slashes (e.g. `groq:openai/gpt-oss-120b`, or `groq:openai:some-id` → model string `openai:some-id`).

| Prefix | Meaning | Env vars |
|--------|---------|----------|
| `openai:` | Workshop default | `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_KEY`, `OPENAI_CHAT_MODEL` in `~/.pyrit` (see **setup** above). |
| `groq:` | Groq | **`GROQ_API_KEY`** (required — **not** set by `setup configure` for OpenAI-only). Optional **`GROQ_OPENAI_BASE_URL`** (default `https://api.groq.com/openai/v1`). |
| `ollama:` | Local Ollama | **`OLLAMA_HOST`** (default `127.0.0.1:11434`, or a full `http(s)://` URL). Optional **`OLLAMA_API_KEY`**. API path `/v1` is appended when missing. |
| `lmstudio:` | LM Studio local | **`LMSTUDIO_OPENAI_BASE_URL`** (default `http://127.0.0.1:1234/v1`). Optional **`LMSTUDIO_API_KEY`**. Alias: **`lm-studio:`**. |
| `compat:` | Any OpenAI-compatible server | **`PYRIT_CLI_COMPAT_ENDPOINT`** (required, e.g. `https://host/v1`). Optional **`PYRIT_CLI_COMPAT_API_KEY`** (omit for no-auth locals). |

You can **mix providers** across flags (e.g. victim `openai:gpt-4o-mini`, adversary `groq:llama-3.3-70b-versatile`, scorer `openai:gpt-4o-mini`) as long as each provider’s credentials are set.

Run **`pyrit-cli targets list`** for the canonical list and notes.

### Discover data and knobs

| Need | Command |
|------|---------|
| Paths for `--dataset pyrit:...` | `pyrit-cli datasets list` (optional `--glob 'pattern'`) |
| Converter modalities (all PyRIT converters) | `pyrit-cli converters list` or `--json` |
| Keys for `--request-converter` / `--response-converter` (stateless only) | `pyrit-cli converters list-keys` |
| Scorer presets and exports | `pyrit-cli scorers list` |
| Target patterns (`openai:`, `groq:`, …) | `pyrit-cli targets list` |

---

## 1. `prompt-sending-attack` (single-turn)

Maps to PyRIT **`PromptSendingAttack`**: one user-style objective per execution turn, no adversarial LLM loop.

### Options (reference)

| Option | Required | Description |
|--------|----------|-------------|
| `--target` | yes | `<provider>:<model>` (see **Target syntax**). |
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

**B. Local Ollama (same command shape; set `OLLAMA_HOST` if needed)**

```bash
pyrit-cli redteam prompt-sending-attack \
  --target ollama:llama3.2 \
  --objective "Reply with exactly: OK"
```

**C. Many objectives from a PyRIT seed file**  
Path is relative to PyRIT’s bundled datasets root (see `datasets list`).

```bash
pyrit-cli redteam prompt-sending-attack \
  --target openai:gpt-4o-mini \
  --dataset pyrit:seed_datasets/local/airt/illegal.prompt \
  --limit 3
```

**D. Objectives from Hugging Face**  
Requires optional install: `pip install 'pyrit-cli[hf]'` (or `datasets`).

```bash
pyrit-cli redteam prompt-sending-attack \
  --target openai:gpt-4o-mini \
  --dataset hf:imdb \
  --hf-split train \
  --hf-column text \
  --limit 2
```

**E. Batch without harmful content**  
Use any benign `pyrit:` YAML or HF column suitable for your policy; `--limit` keeps cost bounded.

---

## 2. `red-teaming-attack` (multi-turn)

Maps to PyRIT **`RedTeamingAttack`**: an **adversarial** chat model proposes prompts; the **objective** (victim) model responds; a **TrueFalse** scorer decides whether the objective is met; repeats up to `--max-turns`.

### Options (reference)

| Option | Required | Description |
|--------|----------|-------------|
| `--objective-target` | yes | Victim: `<provider>:<model>` |
| `--objective` | yes | High-level attack goal string |
| `--adversarial-target` | no | Adversarial LLM; default = `--objective-target` |
| `--max-turns` | no | Default `5`, minimum `1` |
| `--rta-prompt` | no | Adversarial system template: `text_generation` (default), `image_generation`, `naive_crescendo`, `violent_durian`, `crucible` |
| `--memory-labels-json` | no | JSON object of string labels for memory (e.g. `{"harm_category":"demo"}`) |
| `--scorer-preset` | no | `self-ask-tf` (default) or `self-ask-refusal` |
| `--true-description` | for `self-ask-tf` | Text criterion for scorer **True** = “objective achieved” |
| `--refusal-mode` | no | `default` or `strict` — **PyRIT 0.11.x**: ignored for refusal preset; newer PyRIT may use distinct prompts |
| `--scorer-chat-target` | no | Scorer LLM `<provider>:<model>`; default = adversarial target spec |
| `--request-converter` | no | Repeatable; stateless converter keys (order matters) |
| `--response-converter` | no | Repeatable; applied to responses |
| `--include-adversarial-conversation` | flag | Include red-team LLM transcript in printed report |

### Stateless `--request-converter` / `--response-converter` keys

These are the built-in CLI registry keys (no extra LLM for conversion):

`ascii-art`, `atbash`, `base64`, `binary`, `braille`, `ecoji`, `emoji`, `first-letter`, `morse`, `rot13`, `string-join`, `unicode-confusable`

LLM-based converters (e.g. variation, translation) are **not** wired in the CLI yet.

### Flavors

**A. Minimal (same provider/model chain)**  
Good for labs: one target spec for victim + adversary + default scorer chain, explicit success criterion.

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "Get the assistant to say the capital of France is Paris." \
  --true-description "The response states that Paris is the capital of France." \
  --max-turns 3
```

**B. Different adversarial model or provider**  
Use a different `--adversarial-target` spec (another `openai:` model, or e.g. `groq:…` with `GROQ_API_KEY` set). The victim still uses `--objective-target`.

```bash
export GROQ_API_KEY=...   # required for groq:
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o \
  --adversarial-target groq:llama-3.3-70b-versatile \
  --objective "..." \
  --true-description "..."
```

**C. Different scorer target**  
Scoring LLM can be a third `<provider>:<model>` (e.g. cheaper OpenAI model while victim/adversary use Groq).

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target openai:gpt-4o \
  --adversarial-target groq:llama-3.3-70b-versatile \
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

All target flags use the same **`<provider>:<model>`** syntax as **red-teaming-attack**.

### Options (reference)

| Option | Required | Description |
|--------|----------|-------------|
| `--objective-target` | yes | Victim: `<provider>:<model>` |
| `--objective` | yes | Conversation objective string |
| `--adversarial-target` | no | Red-team LLM; default = `--objective-target` |
| `--adversarial-temperature` | no | e.g. `1.1` for a hotter adversarial `OpenAIChatTarget` |
| `--tree-width` | no | Parallel branches (default `4`, doc example) |
| `--tree-depth` | no | Max iterations (default `5`) |
| `--branching-factor` | no | Children per parent (default `2`) |
| `--on-topic-checking` / `--no-on-topic-checking` | flag | On-topic relevance checks (default on) |
| `--desired-response-prefix` | no | Success signal prefix (default `Sure, here is`) |
| `--batch-size` | no | Nodes per batch (default `10`) |
| `--memory-labels-json` | no | JSON object of string labels for memory |
| `--scorer-chat-target` | no | `SelfAskScaleScorer` chat `<provider>:<model>`; if both this and `--score-threshold` are omitted, PyRIT’s default scorer (adversarial chat, threshold 0.7) is used |
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

- **`OpenAIResponseTarget`** and the [Responses API](https://azure.github.io/PyRIT/code/targets/openai-responses-target/) workflow (reasoning traces, web search tools, etc.).
- Custom **`AttackAdversarialConfig.seed_prompt`** (still default template with `{{ objective }}`).
- Custom **filesystem** `system_prompt_path` beyond the `--rta-prompt` enum.
- Extra OpenAI-compatible hosts **beyond** `compat:` + env (no arbitrary per-flag URL without `compat` or code changes).
- Non-`OpenAIChatTarget` victims (e.g. `AzureMLChatTarget`, `TextTarget`, `OpenAIImageTarget`) and **prepended conversations** / jailbreak templates as in the long-form doc examples.
- **LLM-backed** prompt converters.
- **`tap-attack`**: no `--request-converter` / `--response-converter` wiring yet (use Python for `AttackConverterConfig`).

---

## Getting `--help`

```bash
pyrit-cli setup --help
pyrit-cli setup configure --help
pyrit-cli redteam --help
pyrit-cli redteam prompt-sending-attack --help
pyrit-cli redteam red-teaming-attack --help
pyrit-cli redteam tap-attack --help
pyrit-cli ask-ai --help
pyrit-cli targets list
pyrit-cli converters list-keys
```
