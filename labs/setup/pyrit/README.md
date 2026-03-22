### PyRIT Docker Setup Guide

> **Quick Setup:** Use the automated installer:
> ```bash
> ~/labs/AISecWorkshops/labs/setup/scripts/tools/install-pyrit.sh
> ```
> This clones the repo, builds the Docker image, creates `~/.pyrit/` with your API key pre-populated from `~/.secrets/`, and generates `start_service.sh` / `stop_service.sh`.

---

**Manual Setup (step-by-step)**

**Step 1: Get the PyRIT source**

If you cloned **AISecWorkshops** with submodules, PyRIT is already at `labs/setup/pyrit/PyRIT`:

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

## Workshop Gradio (AISec)

Separate from upstream `pyrit/ui`, the **aisec-gradio** package lives at `labs/setup/pyrit/aisec_gradio/`. It provides a **Setup** tab (writes `~/.pyrit/.env` + `.env.local` for native OpenAI or OpenAI-compatible backends) and a **Red Team** tab with a **section tree** (Datasets, Prompt Targets, Converters, Executors), per-assignment summaries (see [Loading built-in datasets](https://azure.github.io/PyRIT/code/datasets/loading-datasets/)), sample code, coach chat, and **Run for me** for local PyRIT samples.

### Local install

From `labs/setup/pyrit` (with PyRIT submodule at `./PyRIT`):

```bash
pip install -e ./PyRIT
pip install -e ./aisec_gradio
```

### Environment

Same contract as **Step 3** above: `mkdir -p ~/.pyrit` and credentials in `.env` / `.env.local`. Optional override for the config directory: `PYRIT_ENV_DIR`.

For **native OpenAI**, the Setup tab saves `OPENAI_API_KEY` in `.env` and also writes `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_KEY`, and `OPENAI_CHAT_MODEL` into `.env.local` so PyRIT’s `OpenAIChatTarget` resolves keys (PyRIT expects `OPENAI_CHAT_*`, not `OPENAI_API_KEY` alone).

### Launch

```bash
cd labs/setup/pyrit
python -m aisec_gradio
# or: aisec-gradio
```

Defaults: `http://0.0.0.0:7860` (override with `GRADIO_SERVER_NAME`, `GRADIO_SERVER_PORT`).

From the repo root you can also run: `make pyrit-gradio` (starts the app; requires the same `pip install -e` steps).

### Docker

Build context must be **`labs/setup/pyrit`** (contains both `PyRIT/` and `aisec_gradio/`):

```bash
cd labs/setup/pyrit
docker build -f Dockerfile.aisec -t aisec-gradio .
docker run --rm -p 7860:7860 \
  -v ~/.pyrit:/root/.pyrit \
  -e AISEC_WORKSHOP_ROOT=/workshop \
  -v /path/to/AISecWorkshops:/workshop \
  aisec-gradio
```

Adjust host paths and user as needed. The container expects API keys only via the mounted `~/.pyrit` volume (or equivalent env files).

---



