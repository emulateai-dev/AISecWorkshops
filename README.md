# AI Security Workshops

Hands-on workshop labs for offensive AI security — red teaming LLMs, agents, and MCP integrations.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## Repository setup (PyRIT and pyrit_cli submodules)

This repo includes **[PyRIT](https://github.com/jitendra-eai/PyRIT)** as a git submodule at `labs/setup/pyrit/PyRIT` and **[pyrit_cli](https://github.com/emulateai-dev/pyrit_cli)** at `labs/setup/pyrit/pyrit_cli`. Each submodule is its **own Git repository** pinned to a commit in this parent repo. Updating or pulling **AISecWorkshops** alone does not refresh submodule contents until you run **`make submodules-update`** (or `git submodule update --remote --merge`) intentionally.

**Recommended order:** (1) clone with submodules or run **`make submodules-init`** from the repo root so both directories are populated, (2) when you want newer PyRIT or pyrit_cli from their remotes, run **`make submodules-update`**, (3) install **pyrit-cli** from the submodule path if you use the terminal labs (below).

After cloning, initialize submodules (or clone with submodules in one step):

```bash
git clone --recurse-submodules https://github.com/emulateai-dev/AISecWorkshops.git
cd AISecWorkshops
# If you cloned without --recurse-submodules:
make submodules-init
```

To pull the latest `main` for each submodule that tracks a branch (merge remote tracking branch):

```bash
make submodules-update
```

### pyrit-cli (optional terminal tool)

From the repo root after submodules are initialized, install **pyrit-cli** using any of the options below. The **`[hf]`** extra pulls in Hugging Face **datasets** (needed for jailbreak benchmark labs that use `--dataset hf:…`).

**pip** (default)

```bash
cd labs/setup/pyrit/pyrit_cli
pip install -e ".[hf]"
```

**uv** — global tool ([install uv](https://docs.astral.sh/uv/getting-started/installation/)), similar to pipx:

```bash
cd labs/setup/pyrit/pyrit_cli
uv tool install --editable ".[hf]"
```

Reinstall after pulling submodule updates: `uv tool install --editable --force ".[hf]"` from the same directory. Uninstall: `uv tool uninstall pyrit-cli`.

**uv** — virtualenv in the submodule (good for development):

```bash
cd labs/setup/pyrit/pyrit_cli
uv venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
uv pip install -e ".[hf]"
```

Or, using the submodule lockfile: `uv sync --extra hf` (same directory; installs into `.venv` if present).

**Poetry** — **pyrit-cli** uses Hatch, not a Poetry layout. Activate the virtualenv you use for workshops (for example `poetry shell` from **your** lab `pyproject.toml` directory), **then**:

```bash
cd labs/setup/pyrit/pyrit_cli
pip install -e ".[hf]"
```

The editable install must run from `labs/setup/pyrit/pyrit_cli` so pip resolves the package; the interpreter comes from your Poetry-managed (or other) venv.

**After install** (any method):

```bash
pyrit-cli setup configure   # interactive wizard; writes ~/.pyrit/.env and .env.local
pyrit-cli setup             # masked status
```

**Documentation** (inside the submodule, linked from the workshop):

- [pyrit_cli/README.md](./labs/setup/pyrit/pyrit_cli/README.md) — install and quick examples
- [pyrit_cli/docs/workshop-track.md](./labs/setup/pyrit/pyrit_cli/docs/workshop-track.md) — linear path: setup → discover → red team → ask-ai
- [pyrit_cli/src/pyrit_cli/HELP.md](./labs/setup/pyrit/pyrit_cli/src/pyrit_cli/HELP.md) — full CLI flags and environment variables

You can also run `pyrit-cli ask-ai "…"` (loads HELP into the helper); **verify** any suggested command before running.

See also: [PyRIT setup guide](./labs/setup/pyrit/README.md).

---

## Workshop Structure

```
AISecWorkshops/
└── labs/
    ├── setup/
    │   ├── pyrit/PyRIT/                   # PyRIT (git submodule) — run: make submodules-init
    │   ├── pyrit/pyrit_cli/               # pyrit_cli (git submodule)
    │   └── vm/                            # Lab environment setup (VM, tools, API keys)
    ├── llms/
    │   └── red-teaming/
    │       ├── garak/                     # LLM vulnerability scanning with NVIDIA Garak
    │       │   ├── 01_explore_garak_probes.md
    │       │   ├── 02_benchmark_groq_model.md
    │       │   ├── 03_benchmark_hf_model.md
    │       │   ├── advanced/
    │       │   │   └── 04_advanced_jailbreak_techniques.md
    │       │   └── samples/               # Sample scan reports and hitlogs
    │       └── jailbreaks/                # Jailbreak lab — Jupyter (PyRIT Docker) and/or pyrit-cli
    │           └── README.md
    ├── agents/
    │   └── red-teaming/
    │       ├── folly/                     # Prompt injection challenges with Folly
    │       ├── edr/                       # Enterprise Deep Research agent red teaming
    │       │   └── challenges/            # 7 challenges: RAG poisoning, Text2SQL, injection
    │       ├── open-ai-cs-agent/          # Airline multi-agent system red teaming
    │       │   └── challenges/            # 10 challenges: BOLA, social engineering, jailbreak
    │       ├── ai-red-teaming-labs/       # Microsoft AI Red Teaming Playground Labs
    │       │   └── challenges/            # 12 challenges: exfiltration, Crescendo, injection, safety bypass
    │       └── dtx-demo-agents/           # Target sandbox: chat/RAG/tool/text2sql demo apps
    └── mcp/
        └── red-teaming/
            └── dv_mcp_labs/               # Damn Vulnerable MCP Server challenges
                └── challenges/            # 10 challenges: injection, BOLA, SSRF
```

---

## Labs

### LLM Red Teaming

Probe large language models for security vulnerabilities using automated scanning tools.

| # | Exercise | Target | Time | Description |
|---|----------|--------|------|-------------|
| 1 | [Explore Garak Probes](./labs/llms/red-teaming/garak/01_explore_garak_probes.md) | `test.Blank` | ~10 min | Understand Garak's probe architecture, inspect attack prompts |
| 2 | [Benchmark Groq Model](./labs/llms/red-teaming/garak/02_benchmark_groq_model.md) | `qwen/qwen3-32b` | ~30 min | Run DAN jailbreak probes against a cloud LLM, review reports |
| 3 | [Benchmark HuggingFace Model](./labs/llms/red-teaming/garak/03_benchmark_hf_model.md) | `smollm:135m` | ~2h (CPU) | Scan a local model, compare to cloud, interpret findings |
| 4 | [Advanced Jailbreak Techniques](./labs/llms/red-teaming/garak/advanced/04_advanced_jailbreak_techniques.md) | Various | ~20 min | TAP, GCG, and Atkgen — automated attack generation |
| — | [LLM Jailbreaks](./labs/llms/red-teaming/jailbreaks/README.md) | Ollama / Groq / OpenAI | ~5 h (full track) | Alignment, datasets, PyRIT benchmarks, converters, TAP; optional **pyrit-cli** terminal track |

### Agent Red Teaming

Attacking and evaluating autonomous AI agents — prompt injection, system prompt extraction, goal hijacking, BOLA, and social engineering.

| # | Exercise | Tool | Challenges | Time | Description |
|---|----------|------|-----------|------|-------------|
| 1 | [Prompt Injection Challenges](./labs/agents/red-teaming/folly/README.md) | Folly | 15+ | ~30 min | Interactive prompt injection and system prompt extraction via web UI |
| 2 | [Enterprise Deep Research (EDR)](./labs/agents/red-teaming/edr/readme.md) | EDR Agent | 7 | ~45 min | RAG poisoning, indirect prompt injection, Text-to-SQL abuse, hallucination |
| 3 | [Airline Customer Support Agent](./labs/agents/red-teaming/open-ai-cs-agent/readme.md) | OpenAI Agents SDK | 10 | ~60 min | Guardrail bypass, BOLA, social engineering, multi-turn PII attacks |
| 4 | [AI Red Teaming Playground Labs](./labs/agents/red-teaming/ai-red-teaming-labs/readme.md) | Microsoft AI Red Teaming Playground | 12 | ~90 min | Credential exfiltration, metaprompt secret extraction, Crescendo multi-turn escalation, indirect prompt injection, safety-filter bypass |
| 5 | [DTX Demo Agents](./labs/agents/red-teaming/dtx-demo-agents/readme.md) | dtxguard demo stack | — (sandbox) | ~30 min | Target sandbox — chat, RAG, tool-use, and text2sql demo apps behind a prompt-guard proxy |

### MCP Red Teaming

Exploiting Model Context Protocol integrations — tool poisoning, server impersonation, rug pull attacks.

| # | Exercise | Project | Challenges | Time | Description |
|---|----------|---------|------------|------|-------------|
| 1 | [Damn Vulnerable MCP Server](./labs/mcp/red-teaming/dv_mcp_labs/readme.md) | DVMS | 10 | ~60 min | Exploiting insecure tool/resource implementations in MCP |

---

## Lab Environment Setup

The labs are designed to run in a dedicated pre-configured environment. Follow these steps to get started:

### 1. Download & Import the DTX Lab VM

The **DTX Lab VM** (Kalki.ova) comes with all tools, local models, and lab code pre-installed.

* **Hardware Requirements:** 16GB RAM (Min 8GB), 250GB Disk, 4+ vCPU.
* **Download:** [Kalki.ova (HuggingFace)](https://huggingface.co/datasets/detoxioai/dtx-ai-sec-lab/blob/main/kalki.ova)
* **Setup Guide:** Follow the **[Full VM Setup Guide](./labs/setup/vm/README.md)** for complete VM setup, VirtualBox configuration, networking, and troubleshooting details.
* **Default VM Credentials:** Username `dtx` and Password `dtx`.

### 2. Initial Configuration (Inside the VM)

Once the VM is running, log in with the default credentials `dtx : dtx` and perform the following:

**A. Add API Keys**
```bash
mkdir -p ~/.secrets/
echo 'your-openai-key' > ~/.secrets/OPENAI_API_KEY.txt
echo 'your-groq-key' > ~/.secrets/GROQ_API_KEY.txt
```

**B. Run Final Setup**
```bash
cd $HOME/labs/AISecWorkshops/labs/setup/vm
sudo ./Tool_Setup.sh
```

### 3. Verify the Environment

```bash
garak --version          # LLM vulnerability scanner
ollama list              # Local model runtime
echo "Groq key: ${GROQ_API_KEY:+Set}"
```

After setup, you should see a success message similar to:

`✅ Post-setup complete for dtx`

Reference screenshot: [Tool setup success output](./labs/setup/vm/tool-setup-success.png)

### 4. Validate Labs After Installation

Run the validation script to verify tools, services, ports, and connectivity:

> Note: This validation can take a couple of minutes to complete.

```bash
cd $HOME
./validate_installation.sh
```

If the script is not in your home directory, run:

```bash
cd $HOME/labs/AISecWorkshops/labs/setup/scripts
./validate_installation.sh
```

Expected output starts like:

`🔍 DTX Validation Log - <date>`

`🌍 External Network Info`

`🌐 External IP: <your-ip>`

On success, you should also see:

`✅ DTX Validation complete.`

### Upgrade Environment

Use this when you want to refresh tools/config from the latest repo version:

```bash
cd $HOME
git clone https://github.com/emulateai-dev/AISecWorkshops.git
sudo ./AISecWorkshops/labs/setup/vm/upgrade_env.sh
```

### Troubleshooting (`uv` cache issues)

If `Tool_Setup.sh` fails due to stale `uv` artifacts, clean cache and rerun:

```bash
rm -rf ~/.cache/uv
cd $HOME/labs/AISecWorkshops/labs/setup/vm
sudo ./Tool_Setup.sh
```

### 5. Start the Labs

Begin with the [Explore Garak Probes](./labs/llms/red-teaming/garak/01_explore_garak_probes.md) exercise — it requires no API keys and is the best place to start.

---

## Tools Used

| Tool | Purpose | Installed via |
|------|---------|---------------|
| [Garak](https://github.com/NVIDIA/garak) | LLM vulnerability scanning | `uv tool install garak` |
| [Ollama](https://ollama.com/) | Local model inference | System install |
| [Folly](https://github.com/detoxio-ai/Folly) | Prompt injection challenges | `uv tool install --editable .` |
| [DTX](https://github.com/detoxio-ai) | AI security testing | `uv tool install "dtx[torch]"` |
| [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) | Multi-agent framework (CS Agent lab) | Python package install |
| [PyRIT](https://github.com/Azure/PyRIT) | Prompt attack and risk identification testing | Docker devcontainer build |
| [pyrit-cli](https://github.com/emulateai-dev/pyrit_cli) (submodule) | Terminal wrapper for setup, dataset inspect, single-turn / multi-turn / TAP attacks | After `make submodules-init`: `pip install -e ".[hf]"` or `uv tool install --editable ".[hf]"` from `labs/setup/pyrit/pyrit_cli` (see [pyrit-cli](#pyrit-cli-optional-terminal-tool) above) |
| [Hugging Face CLI](https://huggingface.co/docs/huggingface_hub/main/en/guides/cli) | Model and dataset access from terminal | `uv tool install "huggingface_hub[cli,torch]"` |
| [LLM CLI](https://github.com/simonw/llm) | Command-line LLM interaction and key management | `uv tool install llm` |
| [Metasploit Framework](https://github.com/rapid7/metasploit-framework) | Exploitation framework for security labs | `msfinstall` |
| [Burp Suite Community](https://portswigger.net/burp/communitydownload) | Web application security testing | Community installer |

---

## References

- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [garak: A Framework for Security Probing LLMs](https://arxiv.org/html/2406.11036v1) — Derczynski et al., 2024
- [NIST Adversarial Machine Learning Taxonomy](https://csrc.nist.gov/pubs/ai/100/2/e2023/final)
- [MITRE ATLAS](https://atlas.mitre.org/) — Adversarial Threat Landscape for AI Systems
- [Indirect Prompt Injection](https://arxiv.org/abs/2302.12173) — Greshake et al., 2023
- [OWASP API Security Top 10 — BOLA](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)
