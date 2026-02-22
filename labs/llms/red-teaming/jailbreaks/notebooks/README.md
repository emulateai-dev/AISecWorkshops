# PyRIT Notebooks

Pre-built Jupyter notebooks and Python scripts for the PyRIT-based jailbreak assignments. Upload notebooks to the PyRIT Jupyter server at [http://localhost:8888](http://localhost:8888), or copy-paste code from the `.py` files.

## Notebooks & Scripts

| # | Notebook | Script | Assignment | Target | Attack Strategy |
|---|----------|--------|-----------|--------|----------------|
| 1 | [.ipynb](./01_benchmark_beavertails.ipynb) | [.py](./01_benchmark_beavertails.py) | Assignment 4 | `qwen/qwen3-32b` (Groq) | PromptSendingAttack — BeaverTails + AIR-Bench |
| 2 | [.ipynb](./02_ollama_flip_attack.ipynb) | [.py](./02_ollama_flip_attack.py) | Assignment 4 | `qwen3:0.6b` (local Ollama) | FlipAttack — encoding flip against local model |
| 3 | [.ipynb](./03_tap_red_teaming.ipynb) | [.py](./03_tap_red_teaming.py) | Assignment 8 | `qwen/qwen3-32b` (Groq) | RedTeamingAttack (TAP) — automated multi-turn |

The `.py` files contain the same code as the notebooks in a flat script format for easy copy-paste into a Jupyter cell or terminal.

## Prerequisites

- PyRIT Docker containers running (`docker compose -f docker/docker-compose.yaml --profile jupyter up -d`)
- Groq API key configured in `~/.pyrit/.env.local`
- For notebook 02: Ollama running on the host with `qwen3:0.6b` pulled

## How to Use

**Option A — Upload notebook to Jupyter:**

1. Open [http://localhost:8888](http://localhost:8888)
2. Click **Upload** and select the `.ipynb` file
3. Run cells sequentially

**Option B — Copy-paste from `.py` file:**

1. Open the `.py` file in your editor
2. Copy the code
3. Paste into a new Jupyter notebook cell at `localhost:8888`

**Option C — Copy into the container:**

```bash
docker cp notebooks/01_benchmark_beavertails.ipynb pyrit-jupyter:/home/user/
```

---

**Back to:** [Jailbreaks Lab Index](../README.md)
