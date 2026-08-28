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
| 4 | [Extend Garak: Bias Testing](./llms/red-teaming/garak/04_extend_garak_bias_testing.md) | Garak | Custom probe + LLM judge | ~20 min |
| 5 | [Advanced Jailbreak Techniques](./llms/red-teaming/garak/advanced/05_advanced_jailbreak_techniques.md) | Garak | Various | ~20 min |

[Full lab overview](./llms/red-teaming/garak/) with Garak introduction, architecture, and background.

---

### Agent Red Teaming

Attacking and evaluating autonomous AI agents — prompt injection, system prompt extraction, goal hijacking, BOLA, social engineering.

| # | Exercise | Tool | Challenges | Target | Time |
|---|----------|------|-----------|--------|------|
| 1 | [Prompt Injection Challenges](./agents/red-teaming/folly/README.md) | Folly | 15+ | GPT-4 / Qwen | ~30 min |
| 2 | [Enterprise Deep Research (EDR)](./agents/red-teaming/edr/readme.md) | EDR Agent | 7 | RAG + SQL Agent | ~45 min |
| 3 | [Airline Customer Support Agent](./agents/red-teaming/open-ai-cs-agent/readme.md) | OpenAI Agents SDK | 10 | Multi-Agent System | ~60 min |

[Full lab overview](./agents/red-teaming/) with agent attack surface background and recommended learning path.

---

### MCP Red Teaming

Exploiting Model Context Protocol integrations — tool poisoning, server impersonation, rug pull attacks.

| # | Exercise | Tool | Challenges | Time |
|---|----------|------|-----------|------|
| 1 | [Damn Vulnerable MCP Server (DVMS)](./mcp/red-teaming/dv_mcp_labs/readme.md) | Docker + Ollama | 10 | ~2h |

[Full lab overview](./mcp/red-teaming/) with MCP attack surface background.

---

## Environment Setup

All labs assume you are running inside the **DTX Lab VM**.

| Step | Guide |
|------|-------|
| VM setup & tool installation | [setup/vm/](./setup/vm/README.md) |
| API key configuration | See [project README](../README.md#getting-started) |
| Coding agent (OpenCode + Groq / DeepInfra / Ollama) | [setup/opencode/](./setup/opencode/README.md) |

### Quick Verify

```bash
garak --version
ollama list
echo "Groq key set: ${GROQ_API_KEY:+yes}"
```

Start with [Exercise 1](./llms/red-teaming/garak/01_explore_garak_probes.md) — no API keys required.
