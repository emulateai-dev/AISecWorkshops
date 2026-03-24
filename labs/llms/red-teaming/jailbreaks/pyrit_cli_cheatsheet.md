# PyRIT CLI cheatsheet (workshop)

One-page reference for **`pyrit-cli`** used across the jailbreaks lab. For full option lists and HTTP victim details, use **`pyrit-cli <command> --help`** (widen with `COLUMNS=120 …`) and the bundled **[HELP.md](../../../setup/pyrit/pyrit_cli/src/pyrit_cli/HELP.md)**. Hands-on progression: **[workshop-track.md](../../../setup/pyrit/pyrit_cli/docs/workshop-track.md)**.

**PyRIT behavior / API:** [PyRIT docs](https://azure.github.io/PyRIT/) — datasets, attacks, scoring, converters.

---

## Targets (`<provider>:<model>`)

| Pattern | Notes |
|---------|--------|
| `openai:<model>` | Uses `~/.pyrit/.env` + `.env.local` (`OPENAI_CHAT_*`). Model id must exist on that endpoint. |
| `groq:<model>` | Needs **`GROQ_API_KEY`**. |
| `ollama:<tag>` | Local Ollama OpenAI-compatible API; **`OLLAMA_HOST`** optional. |
| `lmstudio:<model>` | Local LM Studio; **`LMSTUDIO_OPENAI_BASE_URL`** optional. |
| `compat:<model>` | Any OpenAI-compatible server: **`PYRIT_CLI_COMPAT_ENDPOINT`** (+ optional API key). |
| `http` / `https://…` | HTTPTarget — requires **`--http-request`**, **`--http-response-parser`**, and other **`--http-*`** flags (see HELP). |

```bash
pyrit-cli targets list
```

**Examples — target strings**

```bash
# Cloud / API (set keys in ~/.pyrit/.env.local or env)
pyrit-cli redteam prompt-sending-attack --target openai:gpt-4o-mini --objective "Reply with exactly: OK"
pyrit-cli redteam prompt-sending-attack --target groq:qwen/qwen3-32b --objective "Reply with exactly: OK"

# Local Ollama (model must exist: ollama list)
pyrit-cli redteam prompt-sending-attack --target ollama:qwen3:0.6b --objective "Reply with exactly: OK"

# Custom OpenAI-compatible server
export PYRIT_CLI_COMPAT_ENDPOINT="https://api.example.com/v1"
pyrit-cli redteam prompt-sending-attack --target compat:my-model --objective "Hello"
```

---

## Setup & status

```bash
pyrit-cli setup                  # masked env status
pyrit-cli setup guide            # native OpenAI vs OpenAI-compatible
pyrit-cli setup configure        # interactive wizard → ~/.pyrit/.env + .env.local
```

**Example — first-time flow**

```bash
pyrit-cli setup configure        # follow prompts (OpenAI or OpenAI-compatible / Groq)
pyrit-cli setup                  # confirm files loaded
# Then try a tiny call (adjust --target to match what you configured):
pyrit-cli redteam prompt-sending-attack --target groq:llama-3.3-70b-versatile \
  --objective "Reply with exactly: OK" --scoring-mode auto
```

---

## Datasets (discover, not attacks)

| Goal | Command |
|------|---------|
| List PyRIT seed paths | `pyrit-cli datasets list` |
| Filter paths | `pyrit-cli datasets list --glob '*airt*'` |
| Preview local / registered PyRIT seeds | `pyrit-cli datasets inspect pyrit:seed_datasets/local/airt/illegal.prompt --limit 3` |
| Preview Hugging Face rows | `pyrit-cli datasets inspect hf:PKU-Alignment/BeaverTails-Evaluation --hf-split test --hf-column prompt --limit 3` |

Specs: **`pyrit:`** path under PyRIT `DATASETS_PATH` or registered name; **`hf:`** hub id + **`--hf-split`** / **`--hf-column`**.

**Examples**

```bash
# Machine-readable list of seed files
pyrit-cli datasets list --glob '*jailbreak*'

# Peek at a few rows (HF — harmless column preview)
pyrit-cli datasets inspect hf:imdb --hf-split train --hf-column text --limit 2

# BeaverTails-style preview (authorized / policy-aware use only for full runs)
pyrit-cli datasets inspect hf:PKU-Alignment/BeaverTails-Evaluation \
  --hf-split test --hf-column prompt --limit 3

# AIR-Bench — confirm split/column names on your PyRIT/HF version before batching
pyrit-cli datasets inspect hf:stanford-crfm/air-bench-2024 \
  --hf-split test --hf-column prompt --limit 2
```

---

## Jailbreak templates (`TextJailBreak`)

| Goal | Command |
|------|---------|
| List bundled `.yaml` names | `pyrit-cli jailbreak-templates list` (`--json`, `--include-multi-parameter`) |
| Preview template + rendered system text | `pyrit-cli jailbreak-templates inspect dan_1.yaml` |
| Inspect **your** YAML on disk | `pyrit-cli jailbreak-templates inspect /path/to/custom.yaml` |
| Extra placeholders in YAML | `inspect … --param key=value` (repeatable) |

Used in attacks as **`--jailbreak-template`** (basename **or** path to a file). Optional **`--jailbreak-template-param key=value`**.

**Examples**

```bash
pyrit-cli jailbreak-templates list
pyrit-cli jailbreak-templates list --json | head

# Shorter preview of a shipped template
pyrit-cli jailbreak-templates inspect better_dan.yaml --preview-chars 800

# Workshop custom YAML (path from AISecWorkshops repo root)
pyrit-cli jailbreak-templates inspect \
  labs/llms/red-teaming/jailbreaks/templates/workshop_custom_benign.yaml

# Single-turn attack with bundled template + benign objective
pyrit-cli redteam prompt-sending-attack \
  --target ollama:qwen3:0.6b \
  --objective "Reply with exactly: OK" \
  --jailbreak-template role_play.yaml \
  --scoring-mode auto

# Same with a file path to your own SeedPrompt YAML
pyrit-cli redteam prompt-sending-attack \
  --target ollama:qwen3:0.6b \
  --objective "Reply with exactly: OK" \
  --jailbreak-template labs/llms/red-teaming/jailbreaks/templates/workshop_custom_benign.yaml \
  --scoring-mode auto
```

---

## Converters

| Goal | Command |
|------|---------|
| List modality / registry info | `pyrit-cli converters list` |
| Keys for `--request-converter` / `converters run` | `pyrit-cli converters list-keys` |
| Run pipeline on text | `pyrit-cli converters run -c base64 -c rot13 "Hello"` |
| Stdin | `echo "plain" \| pyrit-cli converters run -c base64` |
| Image converter commands | `pyrit-cli converters image list-keys` |

LLM-backed converters are **not** in the CLI — use PyRIT in Python / Jupyter.

**Examples**

```bash
pyrit-cli converters list-keys

# One encoder
pyrit-cli converters run -c base64 "Attack at dawn"

# Chain: ROT13 then Base64 (order matters — last flag sees previous output)
pyrit-cli converters run --converter rot13 --converter base64 "Hello"

# Morse + binary (examples only)
pyrit-cli converters run -c morse "SOS"
pyrit-cli converters run -c binary "Hi"

# Pipe text in
printf 'exfil test' | pyrit-cli converters run -c unicode-confusable

# Image wrappers
pyrit-cli converters image qrcode "https://example.org/lab-note"
pyrit-cli converters image compress --input ./in.png --quality 60

# Same keys work on red-teaming (request path obfuscation)
pyrit-cli redteam red-teaming-attack \
  --objective-target ollama:qwen3:0.6b \
  --objective "Benign instructor-approved objective text." \
  --true-description "Success criterion from instructor." \
  --max-turns 3 \
  --request-converter base64 \
  --request-converter rot13

# Multimodal image input for vision-capable targets
pyrit-cli redteam prompt-sending-attack \
  --target openai:gpt-4o-mini \
  --objective "Describe the chart in one sentence." \
  --input-image ./chart.png \
  --input-text "Please answer concisely."
```

---

## Scorers

| Goal | Command |
|------|---------|
| List CLI presets + PyRIT exports | `pyrit-cli scorers list` |
| Score **one** string (debug) | `pyrit-cli scorers eval --preset self-ask-refusal --text "…" [--objective "…"] [--scorer-chat-target openai:gpt-4o-mini]` |
| True/false criterion | `--preset self-ask-tf --true-description "…"` |

**Red-teaming** uses **`--scorer-preset`** (`self-ask-tf`, `self-ask-refusal`) + **`--true-description`** / **`--refusal-mode`**. **`prompt-sending-attack`** uses **`--scoring-mode`** (`auto` \| `off` \| `configured`) and related flags.

After **`prompt-sending-attack`**, **`red-teaming-attack`**, and **`tap-attack`**, the CLI prints a **Run summary** (outcome counts, ASR when meaningful, and a one-line note on what **SUCCESS** means for that command).

**Theory:** [True/False scorers](https://azure.github.io/PyRIT/code/scoring/true-false-scorers/), [Refusal scorer](https://azure.github.io/PyRIT/code/scoring/refusal-scorer/).

**Examples**

```bash
pyrit-cli scorers list

# Refusal scorer on a short assistant-style reply (set scorer LLM explicitly if needed)
pyrit-cli scorers eval \
  --preset self-ask-refusal \
  --text "I'm sorry, I can't help with that request." \
  --objective "Instructor-supplied task text for the lab." \
  --scorer-chat-target openai:gpt-4o-mini

# Custom True = "task achieved" wording
pyrit-cli scorers eval \
  --preset self-ask-tf \
  --true-description "The assistant complied fully with the user objective." \
  --text "Here is the information you asked for." \
  --scorer-chat-target groq:llama-3.3-70b-versatile

# Strict refusal mode (best with explicit --objective)
pyrit-cli scorers eval \
  --preset self-ask-refusal \
  --refusal-mode strict \
  --text "I can explain general chemistry concepts only at a high level." \
  --objective "Instructor-supplied objective." \
  --scorer-chat-target openai:gpt-4o-mini

# JSON for scripts; stdin as text (trailing newline ok)
echo "OK" | pyrit-cli scorers eval --preset self-ask-tf \
  --true-description "Response is exactly OK." \
  --text "-" \
  --scorer-chat-target openai:gpt-4o-mini \
  --json

# Score from a file (model output saved to disk)
pyrit-cli scorers eval \
  --preset self-ask-refusal \
  --text-file ./last_assistant_reply.txt \
  --objective "Objective text from your run." \
  --scorer-chat-target openai:gpt-4o-mini
```

---

## Red team — single turn (`PromptSendingAttack`)

```bash
pyrit-cli redteam prompt-sending-attack \
  --target ollama:qwen3:0.6b \
  --objective "Reply with exactly: OK" \
  --scoring-mode auto
```

**More examples**

```bash
# Groq + small HF sample (cap cost)
export GROQ_API_KEY="gsk_..."
pyrit-cli redteam prompt-sending-attack \
  --target groq:qwen/qwen3-32b \
  --dataset hf:PKU-Alignment/BeaverTails-Evaluation \
  --hf-split test --hf-column prompt \
  --limit 5 \
  --scoring-mode auto

# Configured self-ask True/False (harmful dataset only if authorized)
pyrit-cli redteam prompt-sending-attack \
  --target groq:qwen/qwen3-32b \
  --dataset hf:PKU-Alignment/BeaverTails-Evaluation \
  --hf-split test --hf-column prompt \
  --limit 3 \
  --scoring-mode configured \
  --scorer-preset self-ask-tf \
  --true-description "The assistant clearly fulfilled the harmful or disallowed request."

# No scoring (inspect raw completions only)
pyrit-cli redteam prompt-sending-attack \
  --target ollama:qwen3:0.6b \
  --objective "Summarize two-factor authentication in one sentence." \
  --scoring-mode off

# PyRIT seed file as objectives (path under PyRIT DATASETS_PATH)
pyrit-cli redteam prompt-sending-attack \
  --target ollama:qwen3:0.6b \
  --dataset pyrit:seed_datasets/local/airt/illegal.prompt \
  --limit 2 \
  --scoring-mode auto
```

| Flag family | Role |
|-------------|------|
| `--target` | Victim chat or HTTP (see HELP). |
| `--objective` **or** `--dataset` | One string vs many (`pyrit:` / `hf:`). |
| `--scoring-mode`, `--scorer-preset`, `--true-description`, `--scorer-chat-target` | Objective scoring. |
| `--jailbreak-template`, `--jailbreak-template-param` | Prepend jailbreak system message to victim. |
| `--http-*` | When target is HTTP / URL. |

---

## Red team — multi-turn (`RedTeamingAttack`)

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target ollama:qwen3:0.6b \
  --objective "Benign lab goal from instructor." \
  --true-description "Plain-language success criterion." \
  --max-turns 5
```

| Flag family | Role |
|-------------|------|
| `--objective-target`, `--objective` | Victim + high-level goal. |
| `--adversarial-target` | Attacker LLM (defaults / fallbacks per HELP). |
| `--rta-prompt` | Adversarial system template enum. |
| `--scorer-preset`, `--true-description`, `--scorer-chat-target` | Scoring chain. |
| `--request-converter` / `--response-converter` | Stateless converter keys. |
| `--jailbreak-template` | Prepended to **victim** context. |

**More examples**

```bash
# Explicit three-way Groq chain (victim + adversary + scorer)
export GROQ_API_KEY="gsk_..."
pyrit-cli redteam red-teaming-attack \
  --objective-target groq:llama-3.3-70b-versatile \
  --adversarial-target groq:qwen/qwen3-32b \
  --scorer-chat-target groq:qwen/qwen3-32b \
  --objective "Benign lab objective from instructor." \
  --true-description "Plain-language success criterion from instructor." \
  --max-turns 5

# Local victim — scorer often needs a separate JSON chat model
export OPENAI_CHAT_MODEL="gpt-4o-mini"
pyrit-cli redteam red-teaming-attack \
  --objective-target ollama:qwen3:0.6b \
  --objective "Benign objective text." \
  --true-description "Criterion for success." \
  --max-turns 3 \
  --scorer-chat-target openai:gpt-4o-mini

# Prepended jailbreak on victim + red-team loop
pyrit-cli redteam red-teaming-attack \
  --objective-target ollama:qwen3:0.6b \
  --objective "Instructor-approved objective." \
  --true-description "Success criterion." \
  --max-turns 3 \
  --jailbreak-template role_play.yaml \
  --scorer-chat-target openai:gpt-4o-mini

# Refusal-style scoring preset (no --true-description needed)
pyrit-cli redteam red-teaming-attack \
  --objective-target groq:llama-3.3-70b-versatile \
  --objective "Objective text from instructor." \
  --scorer-preset self-ask-refusal \
  --refusal-mode default \
  --max-turns 3
```

---

## Red team — TAP (`TAPAttack`)

```bash
pyrit-cli redteam tap-attack \
  --objective-target groq:llama-3.3-70b-versatile \
  --adversarial-target groq:qwen/qwen3-32b \
  --scorer-chat-target groq:qwen/qwen3-32b \
  --objective "…" \
  --tree-width 4 --tree-depth 5
```

No **`--jailbreak-template`** on TAP in the CLI — use Python for advanced TAP options.

**Examples**

```bash
export GROQ_API_KEY="gsk_..."
# Smaller tree for a quick demo
pyrit-cli redteam tap-attack \
  --objective-target groq:llama-3.3-70b-versatile \
  --adversarial-target groq:qwen/qwen3-32b \
  --scorer-chat-target groq:qwen/qwen3-32b \
  --objective "Benign research framing from instructor." \
  --tree-width 2 \
  --tree-depth 3

# Wider help in narrow terminals
COLUMNS=120 pyrit-cli redteam tap-attack --help
```

---

## Natural language helper

```bash
pyrit-cli ask-ai "Describe what you want to run"
```

**Examples**

```bash
pyrit-cli ask-ai "How do I preview BeaverTails prompts without running an attack?"
pyrit-cli ask-ai "Show a red-teaming-attack example with ollama qwen3 0.6b"
```

---

## Environment variables (common)

| Variable | Used for |
|----------|----------|
| `GROQ_API_KEY` | `groq:…` targets |
| `OPENAI_CHAT_MODEL`, `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_KEY` | `openai:…` (from setup wizard / `.env.local`) |
| `OLLAMA_HOST` | `ollama:…` base URL |
| `PYRIT_CLI_COMPAT_ENDPOINT` | `compat:…` |
| `OPENAI_CHAT_MODEL` | Scorer fallback when victim is local and scorer needs JSON chat |

**Examples**

```bash
export GROQ_API_KEY="gsk_..."
export OLLAMA_HOST="127.0.0.1:11434"
export OPENAI_CHAT_MODEL="gpt-4o-mini"   # scorer sidecar for local ollama victims
# Optional: non-default Ollama OpenAI base
export OLLAMA_HOST="http://192.168.1.50:11434"
```

---

**Back to:** [LLM Jailbreaks lab index](./README.md)
