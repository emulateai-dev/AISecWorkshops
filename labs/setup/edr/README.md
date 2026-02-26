# EDR Setup Scripts

Scripts to install, start, and stop the Salesforce Enterprise Deep Research (EDR) API.

---

## Prerequisites

| Requirement | Check |
|-------------|-------|
| `git` installed | `git --version` |
| `python3` 3.10+ | `python3 --version` |
| `node` / `npm` | `node --version` / `npm --version` |
| API keys configured | `ls ~/.secrets/*.txt` |

---

## Scripts

### `install-edr.sh` — Clone, Install, and Configure

Clones the EDR repository from `SalesforceAIResearch/enterprise-deep-research`. Sets up a Python virtual environment, installs dependencies, builds the Node.js frontend, configures environment variables, generating the `.env` file along with the `start.sh` and `stop.sh` companion scripts.

```bash
AISecWorkshops/labs/setup/scripts/tools/install-edr.sh
```

By default, the framework is installed to `~/labs/agents/red-teaming/edr` (configurable via `BASE_DIR`).

---

### `start.sh` — Launch EDR API Server

Starts the EDR API server on port 8000 using `uvicorn`. This script is automatically generated inside the installation directory (`~/labs/agents/red-teaming/edr` by default).

```bash
cd ~/labs/agents/red-teaming/edr
./start.sh
```

| Environment Variable (in `.env`) | Default | Description |
|---------------------|---------|-------------|
| `LLM_PROVIDER` | `openai` | LLM provider (e.g., `openai`, `anthropic`, `groq`) |
| `LLM_MODEL` | `gpt-4o` | Model name |
| `API_PORT` | `8000` | Port for the API server |

---

### `stop.sh` — Stop EDR API Server

Stops the EDR API server background process by sending a `SIGTERM` to the matched `uvicorn app:app` instance. This script is generated inside the installation directory.

```bash
cd ~/labs/agents/red-teaming/edr
./stop.sh
```

---

## Quick Start

```bash
# 1. Install and configure
../scripts/tools/install-edr.sh

# 2. Review and update your API keys if needed
nano ~/labs/agents/red-teaming/edr/.env

# 3. Start the API server
~/labs/agents/red-teaming/edr/start.sh

# 4. Access the API & Docs
# API:      http://localhost:8000
# API docs: http://localhost:8000/docs

# 5. When done
~/labs/agents/red-teaming/edr/stop.sh
```

---

**Back to:** [EDR Lab](../../agents/red-teaming/edr/readme.md)
