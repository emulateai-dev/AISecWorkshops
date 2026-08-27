# AI Security Workshops

Hands-on workshop labs for offensive AI security — red teaming LLMs, agents, and MCP integrations.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## Introduction

AI systems fail in ways traditional application security testing does not catch. A model
that passes every unit test can still be talked out of its guardrails, an agent with
legitimate tool access can be steered into exfiltrating data, and an MCP server that looks
like a harmless integration can poison every downstream tool call. These are not bugs in
the classic sense — there is no stack trace, no crash, and often no log line — which is
why they need a testing discipline of their own.

**AI Security Workshops** is that discipline, taught hands-on. You attack real, running
targets — local and hosted LLMs, autonomous agents, and MCP integrations — using the same
tooling that professional AI red teams use: **Garak**, **PyRIT**, **Folly**, and a set of
deliberately vulnerable applications. Every lab is a working system you break, observe, and
then reason about.

The labs run inside a pre-configured **DTX Lab VM**, so no time is lost on dependency
management. Bring a laptop that can spare 16 GB of RAM and a willingness to read model
output carefully.

## Objectives

By the end of the workshop track you should be able to:

| # | Objective |
|---|-----------|
| 1 | **Model the threat surface** of an LLM application — prompt, context, tools, retrieval, and output sinks — and identify where trust boundaries actually sit |
| 2 | **Run automated vulnerability scans** against hosted and local models with Garak, and read the resulting reports and hitlogs critically |
| 3 | **Craft and chain jailbreaks** — direct, encoded, multi-turn, and automated (TAP/GCG) — and explain why a given alignment defence failed |
| 4 | **Benchmark safety alignment** across models using standard datasets, so "this model is safer" becomes a number rather than an opinion |
| 5 | **Exploit autonomous agents** via direct and indirect prompt injection, system prompt extraction, goal hijacking, BOLA, and multi-turn social engineering |
| 6 | **Attack RAG and tool-use pipelines** — poisoned documents, Text-to-SQL abuse, and unsafe tool invocation |
| 7 | **Exploit MCP integrations** — tool poisoning, server impersonation, and rug-pull attacks |
| 8 | **Operate the tooling independently** — Garak, PyRIT / `pyrit-cli`, Ollama, and OpenCode — against targets of your own after the workshop ends |
| 9 | **Report findings** in a form an engineering team can act on: reproducible attack, observed impact, and a concrete mitigation |

### Who this is for

Security engineers, penetration testers, red teamers, ML engineers, and developers
shipping LLM features. No machine learning background is required — you need comfort with
a Linux terminal, Python, and HTTP. Everything model-specific is introduced in the labs.

---

## Workshop Structure

```
AISecWorkshops/
└── labs/
    ├── setup/
    │   ├── pyrit/PyRIT/                   # PyRIT (git submodule) — run: make submodules-init
    │   ├── pyrit/pyrit_cli/               # pyrit_cli (git submodule)
    │   ├── ollama/                        # Ollama install, local models, GGUF, cloud (:cloud) models
    │   ├── opencode/                      # OpenCode coding agent — Groq API key + Ollama (signin or key)
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

## Lab Setup

Complete this before starting the labs below. The fastest path is the **DTX Lab VM**,
which ships with every tool, model, and lab already installed — see
[Lab Environment Setup](#lab-environment-setup) for the full VM walkthrough.

### Step 1 — Get the repository (with submodules)

PyRIT and `pyrit_cli` are git submodules; a plain `git clone` leaves those directories
empty.

```bash
git clone --recurse-submodules https://github.com/emulateai-dev/AISecWorkshops.git
cd AISecWorkshops

# if you already cloned without --recurse-submodules:
make submodules-init

# later, to pull newer PyRIT / pyrit_cli from their remotes:
make submodules-update
```

### Step 2 — Set up the tools you need

Each lab track names its prerequisites. Install only what that track needs.

| Tool | What it gives you | Setup guide |
|------|-------------------|-------------|
| **DTX Lab VM** | Pre-built environment with everything below already installed | [setup/vm/](./labs/setup/vm/README.md) |
| **Ollama** | Local models for offline labs, plus `:cloud` models with no GPU | [setup/ollama/SetupOllama.md](./labs/setup/ollama/SetupOllama.md) · [GGUF models](./labs/setup/ollama/running_gguf_models.md) · [DeepSeek](./labs/setup/ollama/running_deepseek_ollama.md) |
| **OpenCode** | Terminal coding agent, wired to Groq (API key) and Ollama (signin or key) | [setup/opencode/](./labs/setup/opencode/README.md) |
| **PyRIT + `pyrit-cli`** | Microsoft's red-teaming framework — jailbreak, benchmark, and TAP labs | [setup/pyrit/](./labs/setup/pyrit/README.md) |
| **Folly** | Prompt-injection challenge server for the agent track | [setup/folly/](./labs/setup/folly/README.md) |
| **EDR agent** | Enterprise Deep Research target — RAG poisoning and Text2SQL labs | [setup/edr/](./labs/setup/edr/README.md) |
| **PentAGI** | Autonomous pentest agent used as a target and as tooling | [setup/pentagi/](./labs/setup/pentagi/readme.md) |
| **Vulhub** | Vulnerable-service stack for agent-driven exploitation labs | [setup/vulhub/](./labs/setup/vulhub/readme.md) |

**Garak** is installed by the VM tool script (`labs/setup/vm/Tool_Setup.sh`); on your own
box, `pipx install garak` or `uv tool install garak`.

### Step 3 — Configure API keys

Several labs call hosted models. Export the keys for the providers you plan to use:

```bash
export GROQ_API_KEY="gsk_..."          # Garak cloud scans, OpenCode, jailbreak labs
export OPENAI_API_KEY="sk-..."         # optional — agent labs
export OLLAMA_API_KEY="..."            # optional — Ollama Cloud (:cloud) models
export HF_TOKEN="hf_..."               # optional — gated HuggingFace models
```

Persist them in `~/.bashrc` or `~/.secrets/`. For `pyrit-cli`, the interactive wizard
writes them for you:

```bash
pyrit-cli setup configure   # writes ~/.pyrit/.env and .env.local
pyrit-cli setup             # masked status check
```

> ⚠️ Keys are secrets. Keep them out of Git, screenshots, and shared VM snapshots.

### Step 4 — Verify

```bash
labs/setup/scripts/validate_installation.sh   # checks tools, models, and lab services
garak --version
ollama list
opencode --version
pyrit-cli setup
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
echo 'your-hf-token'  > ~/.secrets/HF_TOKEN.txt
```

> **Do not skip `HF_TOKEN`** (get one at <https://huggingface.co/settings/tokens>, a **read** token is enough). Without it, model/dataset downloads — including the ~4.9GB vulnerable-llama model `Pre_Installation.sh` fetches — run anonymously and HuggingFace rate-limits those heavily; a download that should take a few minutes can take hours.

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
| [pyrit-cli](https://github.com/emulateai-dev/pyrit_cli) (submodule) | Terminal wrapper for setup, dataset inspect, single-turn / multi-turn / TAP attacks | After `make submodules-init`: `pip install -e "."` or `uv tool install --editable "."` from `labs/setup/pyrit/pyrit_cli` (see [PyRIT setup guide](./labs/setup/pyrit/README.md#workshop-cli-pyrit_cli)) |
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
