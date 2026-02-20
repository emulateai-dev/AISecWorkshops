# Lab: Prompt Injection Challenges with Folly

Hands-on prompt injection and system prompt extraction challenges using [Folly](https://github.com/detoxio-ai/Folly) — an LLM security testing framework with a web UI and CLI.

**Time:** ~1-2 hours (all challenges)  
**Difficulty:** Beginner to Grandmaster

---

## What is Folly?

Folly is an interactive LLM security testing framework that presents **prompt injection challenges** — scenarios where you attempt to bypass system prompts, extract hidden instructions, or hijack model behavior.

It consists of three components:

| Component | Command | Description |
|-----------|---------|-------------|
| **API** | `folly-api` | Backend that connects to your LLM provider and loads challenge configurations |
| **UI** | `folly-ui` | Web interface for browsing and attempting challenges interactively |
| **CLI** | `folly-cli` | Command-line interface for automated/headless testing |

---

## Prerequisites

| Requirement | Check command |
|-------------|--------------|
| `uv` installed | `uv --version` |
| OpenAI API key set | `echo $OPENAI_API_KEY` |
| Git installed | `git --version` |

```bash
export OPENAI_API_KEY=$(cat ~/.secrets/OPENAI_API_KEY.txt)
```

---

## Setup

### Step 1 — Clone and Install Folly

```bash
cd ~/labs
git clone https://github.com/detoxio-ai/Folly.git
cd Folly
```

Install as a global tool using `uv` (keeps your system Python clean):

```bash
uv tool install --editable .
```

This installs three commands to your path: `folly-api`, `folly-cli`, and `folly-ui`.

Verify:

```bash
folly-api --help
folly-ui --help
folly-cli --help
```

> **Troubleshooting:** If you see `error: externally-managed-environment`, make sure you're using `uv tool install` and not `pip install` directly.

---

### Step 2 — Launch the Backend (API)

The API server acts as the bridge between your LLM and the challenge configurations:

```bash
folly-api https://api.openai.com/v1 \
  --model gpt-4 \
  --api-key $(cat ~/.secrets/OPENAI_API_KEY.txt) \
  example_challenges/prompt_injection_masterclass.json
```

| Argument | Description |
|----------|-------------|
| `https://api.openai.com/v1` | Base URL for your LLM provider |
| `--model gpt-4` | Model to test against |
| `--api-key` | Your API key |
| `example_challenges/...` | Challenge configuration file |

The API will start on `http://localhost:5000`.

> **Tip:** To use Groq instead of OpenAI:
>
> ```bash
> folly-api https://api.groq.com/openai/v1 \
>   --model qwen/qwen3-32b \
>   --api-key $(cat ~/.secrets/GROQ_API_KEY.txt) \
>   example_challenges/prompt_injection_masterclass.json
> ```

---

### Step 3 — Launch the Frontend (UI)

In a new terminal (or tmux pane), start the web interface:

```bash
folly-ui http://localhost:5000
```

The UI opens in your browser at `http://localhost:5001`:

![Folly UI](./folly_ui.png)

The sidebar lists all challenges ordered by difficulty. Select one to begin.

---

## Challenges

There are **15 challenges** across 5 difficulty levels. Each challenge has a hidden secret embedded in the system prompt that you must extract using prompt injection techniques.

See the full [Challenge Walkthrough](./01_challenges.md) for details, hints, and techniques for each challenge.

| # | Challenge | Difficulty | Technique |
|---|-----------|------------|-----------|
| 1 | [System Prompt Extraction](./01_challenges.md#challenge-1-first-steps-system-prompt-extraction) | Beginner | Direct extraction |
| 2 | [Role Reversal](./01_challenges.md#challenge-2-role-reversal) | Beginner | Role-play / persona swap |
| 3 | [Indirect Knowledge Extraction](./01_challenges.md#challenge-3-indirect-knowledge-extraction) | Beginner | Indirect questioning |
| 4 | [Token Boundary Manipulation](./01_challenges.md#challenge-4-token-boundary-manipulation) | Intermediate | Token completion |
| 5 | [Context Confusion](./01_challenges.md#challenge-5-context-confusion) | Intermediate | Context switching |
| 6 | [Markdown Manipulation](./01_challenges.md#challenge-6-markdown-manipulation) | Intermediate | Code/format injection |
| 7 | [Translation Bypass](./01_challenges.md#challenge-7-translation-bypass) | Intermediate | Language switching |
| 8 | [Hypothetical Embedding](./01_challenges.md#challenge-8-hypothetical-embedding) | Intermediate | Hypothetical framing |
| 9 | [Code Execution Illusion](./01_challenges.md#challenge-9-code-execution-illusion) | Intermediate | Fake execution context |
| 10 | [Chain-of-Thought Jailbreak](./01_challenges.md#challenge-10-expert-chain-of-thought-jailbreak) | Expert | Logical reasoning chains |
| 11 | [Multi-Turn Extraction](./01_challenges.md#challenge-11-expert-multi-turn-extraction) | Expert | Gradual multi-turn escalation |
| 12 | [Unicode and Symbol Manipulation](./01_challenges.md#challenge-12-expert-unicode-and-symbol-manipulation) | Expert | Unicode / special characters |
| 13 | [Base64 Security Test](./01_challenges.md#challenge-13-master-base64-security-test) | Master | Encoding/decoding exploitation |
| 14 | [Persona Transition Attack](./01_challenges.md#challenge-14-master-persona-transition-attack) | Master | Multi-persona escalation |
| 15 | [Format String Vulnerability](./01_challenges.md#challenge-15-grandmaster-format-string-vulnerability) | Grandmaster | Template/format exploitation |

---

## Using the CLI (Optional)

For automated testing or headless environments:

```bash
folly-cli --api http://localhost:5000
```

---

## Project Structure

```
Folly/
├── Folly/                      # Core logic
│   ├── api.py                  # Flask API server
│   └── ui_app.py               # Flask UI server
├── example_challenges/         # Pre-made challenge JSON files
│   └── prompt_injection_masterclass.json
├── static/                     # Web UI assets
├── templates/                  # Jinja2 templates
└── pyproject.toml              # Package configuration
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `externally-managed-environment` | Use `uv tool install --editable .` instead of `pip install` |
| `folly-api: command not found` | Ensure `~/.local/bin` is in your `PATH` |
| API connection refused | Make sure `folly-api` is running before starting `folly-ui` |
| OpenAI key errors | Verify `echo $OPENAI_API_KEY` shows your key |

---

## References

- [Folly GitHub](https://github.com/detoxio-ai/Folly)
- [OWASP Top 10 for LLM Applications — Prompt Injection](https://owasp.org/www-project-top-10-for-large-language-model-applications/)

---

**Back to:** [Agent Red Teaming Overview](../README.md)
