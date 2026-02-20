# Folly Setup Scripts

Scripts to install, start, and stop the Folly prompt injection challenge framework.

---

## Prerequisites

| Requirement | Check |
|-------------|-------|
| `uv` installed | `uv --version` |
| `git` installed | `git --version` |
| API key configured | `cat ~/.secrets/OPENAI_API_KEY.txt` or `cat ~/.secrets/GROQ_API_KEY.txt` |

---

## Scripts

### `install.sh` — Clone and Install

Clones Folly from GitHub and installs it as a `uv` tool (editable mode). If already cloned, pulls the latest changes.

```bash
./install.sh
```

This installs three commands: `folly-api`, `folly-ui`, `folly-cli`.

---

### `start.sh` — Launch API + UI

Starts both the API backend (port 5000) and web UI (port 5001) in the background.

```bash
# Basic challenges (default) with OpenAI
./start.sh

# Advanced challenges
./start.sh advanced

# Use Groq instead of OpenAI
FOLLY_PROVIDER=groq ./start.sh

# Advanced challenges on Groq with a specific model
FOLLY_PROVIDER=groq FOLLY_MODEL=meta-llama/llama-4-scout-17b-16e-instruct ./start.sh advanced

# Custom challenge config file
./start.sh path/to/custom_challenges.json
```

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `FOLLY_PROVIDER` | `openai` | LLM provider (`openai` or `groq`) |
| `FOLLY_MODEL` | `gpt-4` (openai) / `qwen/qwen3-32b` (groq) | Model name |
| `LABS_DIR` | `~/labs` | Directory where Folly is cloned |

---

### `stop.sh` — Stop API + UI

Stops both the API and UI background processes.

```bash
./stop.sh
```

Falls back to killing processes on ports 5000/5001 if PID files are missing.

---

## Quick Start

```bash
# 1. Install
./install.sh

# 2. Start (basic challenges, OpenAI)
./start.sh

# 3. Open browser to http://localhost:5001

# 4. When done
./stop.sh
```

---

**Back to:** [Folly Lab](../../agents/red-teaming/folly/README.md)
