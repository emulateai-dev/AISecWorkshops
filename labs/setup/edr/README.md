# EDR Setup Scripts

Scripts to install, start, and stop the Salesforce Enterprise Deep Research (EDR) API.

---

> **Note:** Important Update Notice
> If you are facing issues running the scripts or they feel outdated, make sure you have the latest code from the workshop repository:
> ```bash
> cd ~/AISecWorkshops
> git stash
> git pull origin/main
> ```

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

Clones the EDR repository from `SalesforceAIResearch/enterprise-deep-research`. Sets up a Python virtual environment, installs dependencies, builds the Node.js frontend, configures environment variables, generating the `.env` file along with the `start_service.sh` and `stop_service.sh` companion scripts.

```bash
~/labs/AISecWorkshops/labs/setup/scripts/tools/install-edr.sh
```

By default, the framework is installed to `~/labs/agents/red-teaming/edr` (configurable via `BASE_DIR`).

---

### `start_service.sh` — Launch EDR API Server

Starts the EDR API server on port 8000 using `uvicorn`. This script is automatically generated inside the installation directory (`~/labs/agents/red-teaming/edr` by default).

```bash
cd ~/labs/agents/red-teaming/edr
./start_service.sh
```

| Environment Variable (in `.env`) | Default | Description |
|---------------------|---------|-------------|
| `LLM_PROVIDER` | `openai` | LLM provider (e.g., `openai`, `anthropic`, `groq`) |
| `LLM_MODEL` | `gpt-4o` | Model name |
| `API_PORT` | `8000` | Port for the API server |

---

### `stop_service.sh` — Stop EDR API Server

Stops the EDR API server background process by sending a `SIGTERM` to the matched `uvicorn app:app` instance. This script is generated inside the installation directory.

```bash
cd ~/labs/agents/red-teaming/edr
./stop_service.sh
```

---

## Quick Start

```bash
# 1. Install and configure
../scripts/tools/install-edr.sh

# 2. Review and update your API keys if needed
nano ~/labs/agents/red-teaming/edr/.env

# 3. Start the API server
~/labs/agents/red-teaming/edr/start_service.sh

# 4. Access the API & Docs
# API:      http://localhost:8000
# API docs: http://localhost:8000/docs

# 5. When done
~/labs/agents/red-teaming/edr/stop_service.sh
```

---

## FAQ

**Q: I am facing issues with the `venv` or `pip` directory or Python dependencies not loading correctly.**
A: If you encounter issues related to the virtual environment, you can remove the existing `venv` folder and run the install script again. Run the following:

```bash
# 1. Remove the broken virtual environment
rm -rf ~/labs/agents/red-teaming/edr/enterprise-deep-research/venv

# 2. Run the install script again
AISecWorkshops/labs/setup/scripts/tools/install-edr.sh
```

**Q: I get `Npm WARN EBADENGINE` or `Cannot find module 'node:path'` when the script tries to build the frontend.**
A: This happens because your version of Node.js is too old to support modern JavaScript packages (which require Node 18 or 20). You'll need to upgrade Node.js on your system to complete the build successfully. You can upgrade using `nvm` (Node Version Manager):

```bash
# Install Node 20 with nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# Run the installer again
AISecWorkshops/labs/setup/scripts/tools/install-edr.sh
```

---

**Back to:** [EDR Lab](../../agents/red-teaming/edr/readme.md)
