# AI Security Workshop Labs

Hands-on labs covering offensive and defensive techniques across the AI/ML stack.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## Lab Categories

| Category | Topic | Lab | Description |
|----------|-------|-----|-------------|
| **LLMs** | [Red Teaming](./llms/red-teaming/) | [Garak](./llms/red-teaming/garak/) | Automated LLM vulnerability scanning with NVIDIA Garak |
| **Agents** | [Red Teaming](./agents/red-teaming/) | _Coming soon_ | Attacking and evaluating autonomous AI agents |
| **MCP** | [Red Teaming](./mcp/red-teaming/) | _Coming soon_ | Exploiting Model Context Protocol integrations |

---

## Prerequisites

All labs assume you are running inside the **DTX Lab VM** (see [setup/vm/](./setup/vm/)).

Minimum requirements:
- Groq API key exported as `GROQ_API_KEY`
- Tools pre-installed via `Tool_Setup.sh` (garak, dtx, promptfoo, etc.)
- Ollama running with local models pulled

---

## Quick Start

```bash
# Verify your environment
echo "Groq key set: ${GROQ_API_KEY:+yes}"
garak --version
ollama list
```

Pick a lab from the table above and follow its README.
