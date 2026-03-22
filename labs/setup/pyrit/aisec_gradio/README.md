# aisec-gradio

Workshop Gradio app: **Setup** (`~/.pyrit` env files) and **Red Team** (section tree: Datasets, Prompt Targets, Converters, Executors), coach chat, sample code, and **Run for me** (local PyRIT runners).

Built-in **Datasets** content follows [Loading built-in datasets](https://azure.github.io/PyRIT/code/datasets/loading-datasets/) (PyRIT docs).

## Install

**Python:** use **3.10–3.13** (PyPI [`pyrit`](https://pypi.org/project/pyrit/) declares `>=3.10,<3.14`, matching [Azure/PyRIT](https://github.com/Azure/PyRIT) releases).

From `labs/setup/pyrit`:

```bash
pip install -e ./aisec_gradio
```

This pulls **PyRIT from PyPI** as a dependency. To hack on the **git submodule** at `./PyRIT` instead, install that first so it takes precedence:

```bash
pip install -e ./PyRIT
pip install -e ./aisec_gradio
```

**Poetry:** from this directory, `poetry install` uses the same constraints (`requires-python = ">=3.10,<3.14"` in `pyproject.toml`). For sandbox unit tests: `poetry install --extras dev` then `poetry run pytest`.

## Run

```bash
python -m aisec_gradio
```

Or: `aisec-gradio`

Defaults: `http://0.0.0.0:7860` (`GRADIO_SERVER_NAME`, `GRADIO_SERVER_PORT`).

## Red Team coach (LangGraph)

The **Red Team** chat uses a **LangGraph** ReAct agent with tools:

- **`execute_python`** — runs Python in a **subprocess** with `sys.executable` (never `exec`/`eval` in the Gradio process). Working directory is a fresh temp folder per run.
- **`run_workshop_runner`** — same as **Run for me** for the current assignment.
- **`fetch_dataset_seed_preview_tool`** — sample seeds from built-in PyRIT dataset names (may hit Hugging Face cache / network).

Assignment text and linked **reference files** are injected into the system prompt so the coach can quote lab copy accurately.

### Sandbox environment variables

| Variable | Meaning |
|----------|---------|
| `AISEC_SANDBOX` | Set to `1` inside child processes (informational). |
| `AISEC_SANDBOX_ALLOW_NETWORK` | `0` (default) or `1` — subprocess may allow outbound HTTP when `1` (per-assignment `sandbox_policy` in the registry can enable HF/API use). |
| `AISEC_SANDBOX_MAX_CODE_CHARS` | Max length of submitted code (default `200000`). |

**Safety:** running arbitrary code is risky if the machine is shared or the environment is misconfigured. Prefer local-only workshops, a dedicated user, or container isolation. Stronger isolation (Docker/Firejail) is a possible follow-up; see `SandboxRunner` in `agent/sandbox.py` for a documented extension point.

## Docker

From `labs/setup/pyrit`:

```bash
docker build -f Dockerfile.aisec -t aisec-gradio .
docker run --rm -p 7860:7860 -v ~/.pyrit:/root/.pyrit \
  -e AISEC_WORKSHOP_ROOT=/workshop -v /path/to/AISecWorkshops:/workshop aisec-gradio
```

See [../README.md](../README.md) (Workshop Gradio section) for full notes.
