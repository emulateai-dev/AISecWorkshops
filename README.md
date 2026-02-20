# AI Security Workshops

Hands-on workshop labs for offensive AI security — red teaming LLMs, agents, and MCP integrations.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## Workshop Structure

```
AISecWorkshops/
└── labs/
    ├── setup/vm/                          # Lab environment setup (VM, tools, API keys)
    ├── llms/
    │   └── red-teaming/
    │       └── garak/                     # LLM vulnerability scanning with NVIDIA Garak
    │           ├── 01_explore_garak_probes.md
    │           ├── 02_benchmark_groq_model.md
    │           ├── 03_benchmark_hf_model.md
    │           ├── advanced/
    │           │   └── 04_advanced_jailbreak_techniques.md
    │           └── samples/               # Sample scan reports and hitlogs
    ├── agents/
    │   └── red-teaming/
    │       └── folly/                     # Prompt injection challenges with Folly
    └── mcp/
        └── red-teaming/                   # MCP red teaming (coming soon)
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

### Agent Red Teaming

Attacking and evaluating autonomous AI agents — prompt injection, system prompt extraction, goal hijacking.

| # | Exercise | Tool | Time | Description |
|---|----------|------|------|-------------|
| 1 | [Prompt Injection Challenges](./labs/agents/red-teaming/folly/) | Folly | ~30 min | Interactive prompt injection and system prompt extraction via web UI |

### MCP Red Teaming

Exploiting Model Context Protocol integrations — tool poisoning, server impersonation, rug pull attacks.

_Labs coming soon._ See [overview](./labs/mcp/red-teaming/).

---

## Getting Started

### 1. Set Up the Lab Environment

Follow the [VM setup guide](./labs/setup/vm/) to get the DTX Lab VM running with all tools pre-installed.

### 2. Configure API Keys

```bash
mkdir -p ~/.secrets/
echo 'your-groq-key' > ~/.secrets/GROQ_API_KEY.txt
echo 'your-openai-key' > ~/.secrets/OPENAI_API_KEY.txt
```

### 3. Verify Tools

```bash
garak --version          # LLM vulnerability scanner
ollama list              # Local model runtime
echo "${GROQ_API_KEY:+Groq key is set}"
```

### 4. Start with Exercise 1

Begin with [Explore Garak Probes](./labs/llms/red-teaming/garak/01_explore_garak_probes.md) — no API keys needed.

---

## Tools Used

| Tool | Purpose | Installed via |
|------|---------|---------------|
| [Garak](https://github.com/NVIDIA/garak) | LLM vulnerability scanning | `uv tool install garak` |
| [Ollama](https://ollama.com/) | Local model inference | System install |
| [Groq](https://groq.com/) | Cloud LLM inference API | API key |
| [Promptfoo](https://www.promptfoo.dev/) | LLM eval & red teaming | `npm install -g promptfoo` |
| [Folly](https://github.com/detoxio-ai/Folly) | Prompt injection challenges | `uv tool install --editable .` |
| [DTX](https://github.com/detoxio-ai) | AI security testing | `uv tool install "dtx[torch]"` |

---

## References

- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [garak: A Framework for Security Probing LLMs](https://arxiv.org/html/2406.11036v1) — Derczynski et al., 2024
- [NIST Adversarial Machine Learning Taxonomy](https://csrc.nist.gov/pubs/ai/100/2/e2023/final)
- [MITRE ATLAS](https://atlas.mitre.org/) — Adversarial Threat Landscape for AI Systems
