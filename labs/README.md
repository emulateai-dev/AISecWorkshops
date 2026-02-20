# AI Security Workshop Labs

Hands-on labs covering offensive and defensive techniques across the AI/ML stack.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## Lab Categories

### LLM Red Teaming

Probe large language models for security vulnerabilities — jailbreaks, prompt injection, encoding bypass, and more.

| # | Exercise | Tool | Target | Time |
|---|----------|------|--------|------|
| 1 | [Explore Garak Probes](./llms/red-teaming/garak/01_explore_garak_probes.md) | Garak | `test.Blank` | ~10 min |
| 2 | [Benchmark Groq Model](./llms/red-teaming/garak/02_benchmark_groq_model.md) | Garak | `qwen/qwen3-32b` | ~30 min |
| 3 | [Benchmark HuggingFace Model](./llms/red-teaming/garak/03_benchmark_hf_model.md) | Garak | `smollm:135m` | ~2h (CPU) |
| 4 | [Advanced Jailbreak Techniques](./llms/red-teaming/garak/advanced/04_advanced_jailbreak_techniques.md) | Garak | Various | ~20 min |

[Full lab overview](./llms/red-teaming/garak/) with Garak introduction, architecture, and background.

### Agent Red Teaming

Attacking and evaluating autonomous AI agents — prompt injection, system prompt extraction, goal hijacking.

| # | Exercise | Tool | Target | Time |
|---|----------|------|--------|------|
| 1 | [Prompt Injection Challenges](./agents/red-teaming/folly/) | Folly | GPT-4 / Qwen | ~30 min |

[Full lab overview](./agents/red-teaming/) with agent attack surface background.

### MCP Red Teaming

Exploiting Model Context Protocol integrations — tool poisoning, server impersonation, rug pull attacks.

_Labs coming soon._ See [overview](./mcp/red-teaming/).

---

## Environment Setup

All labs assume you are running inside the **DTX Lab VM**.

| Step | Guide |
|------|-------|
| VM setup & tool installation | [setup/vm/](./setup/vm/) |
| API key configuration | See [project README](../README.md#getting-started) |

### Quick Verify

```bash
garak --version
ollama list
echo "Groq key set: ${GROQ_API_KEY:+yes}"
```

Start with [Exercise 1](./llms/red-teaming/garak/01_explore_garak_probes.md) — no API keys required.
