### PyRIT Docker Setup Guide

> **Quick Setup:** Use the automated installer:
> ```bash
> ~/labs/AISecWorkshops/labs/setup/scripts/tools/install-pyrit.sh
> ```
> This clones the repo, builds the Docker image, creates `~/.pyrit/` with your API key pre-populated from `~/.secrets/`, and generates `start_service.sh` / `stop_service.sh`.

---

**Manual Setup (step-by-step)**

**Step 1: Get the PyRIT source**

If you cloned **AISecWorkshops** with submodules, PyRIT is at `labs/setup/pyrit/PyRIT` and **pyrit_cli** at `labs/setup/pyrit/pyrit_cli`:

```bash
# from repo root (after git clone)
make submodules-init
cd labs/setup/pyrit/PyRIT
```

Or clone PyRIT standalone:

```bash
git clone https://github.com/jitendra-eai/PyRIT.git
cd PyRIT
```

Work from the **PyRIT repository root** (`PyRIT/` or `labs/setup/pyrit/PyRIT`). Do not `cd docker/` before the devcontainer build in Step 2.

**Step 2: Build the Base Devcontainer Image**
Because of how the context is structured, you must build the base image from the root of the repository to prevent the `path ".devcontainer" not found` error.

```bash
docker build -f .devcontainer/Dockerfile -t pyrit-devcontainer .devcontainer

```

**Step 3: Configure Your Environment (.env and .env.local)**
PyRIT securely mounts your local `~/.pyrit/` directory to pass credentials into the containers. Set up the folder and create your environment files:

```bash
mkdir -p ~/.pyrit
touch ~/.pyrit/.env ~/.pyrit/.env.local

```

Choose **one** of the following configurations depending on your backend:

* **Option A: Standard OpenAI Configuration**
If you are using standard OpenAI, you only need to populate the base `.env` file.
*Add to `~/.pyrit/.env`:*
```text
OPENAI_API_KEY="sk-proj-your-openai-key-here"

```


* **Option B: Groq (OpenAI-Compatible) Configuration**
Use this to route PyRIT's default OpenAI calls through Groq for ultra-fast generation. Set your base platform variables in `.env`, and then use `.env.local` to override PyRIT's default target mapping.
*1. Add to `~/.pyrit/.env`:*
```text
PLATFORM_OPENAI_CHAT_ENDPOINT="https://api.groq.com/openai/v1"
PLATFORM_OPENAI_CHAT_API_KEY="gsk_eU11D06**"
PLATFORM_OPENAI_CHAT_GPT4O_MODEL="openai/gpt-oss-120b"

```


*2. Add to `~/.pyrit/.env.local`:*
```text
# This will override the .env value for your default OpenAIChatTarget
OPENAI_CHAT_ENDPOINT=${PLATFORM_OPENAI_CHAT_ENDPOINT}
OPENAI_CHAT_KEY=${PLATFORM_OPENAI_CHAT_API_KEY}
OPENAI_CHAT_MODEL="openai/gpt-oss-120b"

```



**Step 4: Start the Containers with Profiles**
To avoid the `no service selected` error, explicitly tell Docker Compose which profiles to start, and point it to the YAML file in the `docker` subdirectory while remaining in the repository root:

```bash
docker compose -f docker/docker-compose.yaml --profile jupyter --profile gui up -d

```

*(Optional: Verify everything started successfully and is healthy by checking the logs)*:

```bash
docker compose -f docker/docker-compose.yaml logs -f

```

**Step 5: Access PyRIT**
Your local environment is now fully running and authenticated with your overrides in place! You can access the interfaces in your browser:

* **PyRIT GUI:** http://localhost:8000
* **Jupyter Notebooks:** http://localhost:8888

---

## Workshop CLI (pyrit_cli)

The **pyrit_cli** package is a git submodule at `labs/setup/pyrit/pyrit_cli`. From the **AISecWorkshops repository root**, run **`make submodules-init`** so this directory is populated (empty folder means submodules were not checked out). To pull newer **pyrit_cli** or **PyRIT** commits from their remotes, run **`make submodules-update`** from the root.

Install **pyrit-cli** from this submodule (always run **`make submodules-init`** from the AISecWorkshops root first). Use **`[hf]`** for Hugging Face dataset objectives (`--dataset hf:…`).

**pip**

```bash
cd labs/setup/pyrit/pyrit_cli
pip install -e ".[hf]"
```

**uv** — tool on your PATH

```bash
cd labs/setup/pyrit/pyrit_cli
uv tool install --editable ".[hf]"
```

**uv** — local `.venv` + editable install

```bash
cd labs/setup/pyrit/pyrit_cli
uv venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
uv pip install -e ".[hf]"
# or: uv sync --extra hf
```

**Poetry** — activate your Poetry-managed environment, then from `labs/setup/pyrit/pyrit_cli` run `pip install -e ".[hf]"` (the project uses Hatch; pip into the venv is the supported path).

Then:

```bash
pyrit-cli setup configure
```

**Docs (read in order for workshops):**

- [pyrit_cli/docs/workshop-track.md](./pyrit_cli/docs/workshop-track.md) — linear path: install → credentials → discover → red team → ask-ai
- [pyrit_cli/src/pyrit_cli/HELP.md](./pyrit_cli/src/pyrit_cli/HELP.md) — every flag and environment variable (`groq:`, `ollama:`, `openai:`, HTTP victim, TAP, …)
- [pyrit_cli/README.md](./pyrit_cli/README.md) — short overview and copy-paste examples

Environment variables follow the same contract as **Step 3** above: `mkdir -p ~/.pyrit` and credentials in `~/.pyrit/.env` / `~/.pyrit/.env.local`. For **Groq** targets (`groq:<model>`), set **`GROQ_API_KEY`**. If you use **`openai:<model>`** against a non-OpenAI host (e.g. Groq via OpenAI-compatible URLs from the wizard), the model id must exist on that host (see HELP “Setup” and “Environment variables”).

---



