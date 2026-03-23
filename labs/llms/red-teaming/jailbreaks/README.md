# Lab: LLM Jailbreaks

Hands-on assignments exploring LLM safety alignment, its limitations, and techniques to bypass it. You'll progress from understanding *why* models refuse harmful requests to systematically testing techniques that can break through those defenses.

**Time:** ~5 hours (all assignments)  
**Difficulty:** Beginner → Advanced  
**Models:** Ollama (local), Groq (cloud), OpenAI, Gemini

---

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Ollama running | `ollama list` |
| `qwen3:0.6b` pulled | `ollama run qwen3:0.6b` (then `/bye`) |
| Groq API key | `echo $GROQ_API_KEY` |
| `jq` installed | `jq --version` |
| Docker installed (for Assignments 4, 7, 9) | `docker --version` |
| **Optional: pyrit-cli** — submodule checked out | From AISecWorkshops root: `make submodules-init`; then `test -f labs/setup/pyrit/pyrit_cli/pyproject.toml` |
| **Optional: pyrit-cli** — install | From `labs/setup/pyrit/pyrit_cli`: `pip install -e ".[hf]"`, or `uv tool install --editable ".[hf]"`, or `uv pip install -e ".[hf]"` in a venv; Poetry users: activate env then same `pip install -e ".[hf]"` ([workshop README](../../../../README.md#pyrit-cli-optional-terminal-tool)) |

---

## Assignments

| # | Assignment | Time | Difficulty | What You'll Learn |
|---|-----------|------|------------|-------------------|
| 1 | [Exploring Safety Alignment of Qwen](./safety_alignment.md) | ~40 min | Beginner → Intermediate | Why LLMs refuse; 9 escalating techniques against qwen3:0.6b; chain-of-thought defense analysis |
| 2 | [Uncensored Models](./uncensored_models.md) | ~20 min | Beginner | What happens when alignment is removed; abliteration; jailbroken SmolLM |
| 3 | [Model Risks & Harmful Prompt Datasets](./model_risks_and_datasets.md) | ~25 min | Beginner | 14 harm categories; MIT AI Risk Repository; BeaverTails, AdvBench, AIR-Bench datasets |
| 4 | [Benchmarking Model Safety with PyRIT](./benchmarking_safety.md) | ~40 min | Intermediate | PyRIT setup; benchmark qwen3-32b against BeaverTails; ASR metrics; AIR-Bench evaluation |
| 5 | [Basic Jailbreak Techniques](./basic_jailbreak_techniques.md) | ~30 min | Intermediate | DAN, persona injection, hypothetical framing, instruction override, grandma exploit |
| 6 | [Encoding & Obfuscation](./encoding_obfuscation.md) | ~25 min | Intermediate | Base64, ROT13, leetspeak, character splitting, payload splitting |
| 7 | [PyRIT Prompt Converters](./pyrit_prompt_converters.md) | ~30 min | Intermediate | 30+ PyRIT converters; encoding, obfuscation, token smuggling; LLM-based translation, persuasion, math obfuscation |
| 8 | [Multi-Turn & Social Engineering](./multi_turn_social_engineering.md) | ~25 min | Advanced | Context building, trust establishment, emotional manipulation, role escalation |
| 9 | [Automated Red Teaming — TAP](./automated_red_teaming_tap.md) | ~35 min | Advanced | PyRIT TAPAttack; automated multi-turn tree search; cross-model comparison |
| 10 | [System Prompt Extraction](./system_prompt_extraction.md) | ~20 min | Advanced | Extract hidden instructions, secrets, and configuration from AI systems |

---

## Progression

```
Assignment 1:   UNDERSTAND + ATTACK  →  Safety alignment theory + 9 techniques on Qwen
Assignment 2:   COMPARE              →  Aligned vs. uncensored vs. jailbroken models
Assignment 3:   CLASSIFY             →  14 harm categories, risk taxonomies, benchmark datasets
Assignment 4:   BENCHMARK            →  Automated safety evaluation with PyRIT + BeaverTails/AIR-Bench
Assignment 5:   ATTACK               →  Classic single-turn jailbreak techniques
Assignment 6:   OBFUSCATE            →  Encoding to bypass input filters
Assignment 7:   CONVERT              →  PyRIT prompt converters (encoding, obfuscation, LLM-based)
Assignment 8:   ESCALATE             →  Multi-turn social engineering
Assignment 9:   AUTOMATE             →  AI-vs-AI red teaming with TAP (Tree of Attacks)
Assignment 10:  EXTRACT              →  System prompt & secrets extraction
```

**pyrit-cli (optional) — mirrors Assignments 1–4, 7, 9**

| Assignment | CLI focus |
|------------|-----------|
| **1** | `redteam prompt-sending-attack` with `--objective` — try `ollama:qwen3:0.6b`, `groq:…`, `openai:…` for the same prompts |
| **2** | Same command; swap `--target` (aligned vs jailbroken / uncensored Ollama models) |
| **3** | `datasets list` / `datasets inspect` (`pyrit:` and `hf:`), `jailbreak-templates list` — explore only |
| **4** | `prompt-sending-attack --dataset hf:…` batch run (see assignment; notebook still needed for full ASR) |
| **7** | `converters run` (stateless); LLM converters stay in Jupyter |
| **9** | `redteam tap-attack` — see assignment for Groq example |

Assignments **1–3** do not require Docker if you use only the CLI path for those steps.

---

### Optional: pyrit-cli track

Use **[pyrit-cli](https://github.com/emulateai-dev/pyrit_cli)** from `labs/setup/pyrit/pyrit_cli` when you want a **terminal** workflow (no Jupyter) for early assignments, or to complement Docker notebooks. After **`make submodules-init`** at the workshop repo root, install with `pip install -e ".[hf]"` and follow **[workshop-track.md](../../../setup/pyrit/pyrit_cli/docs/workshop-track.md)** and **[HELP.md](../../../setup/pyrit/pyrit_cli/src/pyrit_cli/HELP.md)**. Individual assignments below link concrete commands.

---

## Reference Prompts

The file `../prompts/example_prompts_via_metaprompts.txt` contains **900+ adversarial prompts** across categories:

- Hate speech, harassment, bullying
- Threats, violence, self-harm
- Criminal planning, fraud, scams
- Malware, hacking, privacy violations
- Dangerous substances, weapons
- Misinformation, fake news
- Discrimination, bias
- Sexual content

Use these as test inputs throughout the assignments.

---

**Back to:** [LLM Red Teaming Overview](../README.md)
