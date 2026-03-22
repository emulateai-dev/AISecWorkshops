# Folly Setup Scripts

Scripts to install, start, and stop the Folly prompt injection challenge framework.

---

## Prerequisites

| Requirement | Check |
|-------------|-------|
| `git` installed | `git --version` |
| `python3` (3.7+) installed | `python3 --version` |
| `pip3` installed | `pip3 --version` |
| API key configured | `cat ~/.secrets/OPENAI_API_KEY.txt` or `cat ~/.secrets/GROQ_API_KEY.txt` |

---

## Install

Run the installer from the `AISecWorkshops` repo root:

```bash
~/labs/AISecWorkshops/labs/setup/scripts/tools/install-folly.sh
```

By default, Folly is installed to `~/labs/agents/red-teaming/folly/Folly` with a
Python virtual environment. The installer also generates `start_service.sh` and `stop_service.sh`
in `~/labs/agents/red-teaming/folly/`.


---

## Start

```bash
# Basic challenges (default) with OpenAI
~/labs/agents/red-teaming/folly/start_service.sh

# Advanced challenges
~/labs/agents/red-teaming/folly/start_service.sh advanced

# Use Groq instead of OpenAI
FOLLY_PROVIDER=groq ~/labs/agents/red-teaming/folly/start_service.sh

# Use xAI / Grok
FOLLY_PROVIDER=xai ~/labs/agents/red-teaming/folly/start_service.sh

# Use Ollama (local, no API key required)
FOLLY_PROVIDER=ollama ~/labs/agents/red-teaming/folly/start_service.sh

# Advanced challenges on Groq with a specific model
FOLLY_PROVIDER=groq FOLLY_MODEL=meta-llama/llama-4-scout-17b-16e-instruct \
  ~/labs/agents/red-teaming/folly/start_service.sh advanced

# Custom challenge config file
~/labs/agents/red-teaming/folly/start_service.sh path/to/custom_challenges.json
```

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `FOLLY_PROVIDER` | `openai` | LLM provider: `openai`, `groq`, `ollama`, `xai` |
| `FOLLY_MODEL` | provider default | Override model name |

---

## Stop

```bash
~/labs/agents/red-teaming/folly/stop_service.sh
```

Falls back to killing processes on ports 5000/5001 if PID files are missing.

---

## Quick Start

```bash
# 1. Install
~/labs/AISecWorkshops/labs/setup/scripts/tools/install-folly.sh

# 2. Start (basic challenges, OpenAI)
~/labs/agents/red-teaming/folly/start_service.sh

# 3. Open browser to http://localhost:5001

# 4. When done
~/labs/agents/red-teaming/folly/stop_service.sh
```

---

**Back to:** [Folly Lab](../../agents/red-teaming/folly/README.md)
