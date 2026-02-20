# Agent Red Teaming Labs

These labs focus on attacking and evaluating autonomous AI agents — systems that use LLMs to plan, reason, and take actions in the real world.

---

## Labs

| # | Lab | Tool | Time | Description |
|---|-----|------|------|-------------|
| 1 | [Prompt Injection Challenges](./folly/) | Folly | ~30 min | Interactive prompt injection and system prompt extraction via web UI |
| | _Tool-Use Exploitation_ | — | | Coming soon |
| | _Multi-Step Goal Hijacking_ | — | | Coming soon |

---

## Background

AI agents extend LLM capabilities with tool access — web browsing, code execution, file I/O, database queries, and API calls. This expanded attack surface introduces risks that don't exist with standalone chat models:

- **Indirect prompt injection** — malicious instructions embedded in data the agent retrieves (web pages, emails, documents)
- **Tool-use exploitation** — tricking the agent into calling dangerous tools or passing harmful arguments
- **Goal hijacking** — redirecting the agent's multi-step plan toward an attacker-controlled objective
- **Privilege escalation** — abusing the agent's access permissions to reach systems beyond its intended scope
- **Data exfiltration** — causing the agent to leak sensitive context through its tool calls

---

## Prerequisites

- DTX Lab VM with tools installed
- `OPENAI_API_KEY` or `GROQ_API_KEY` exported
- `uv` installed (for Folly setup)
- Familiarity with the [LLM Red Teaming labs](../../llms/red-teaming/) (recommended)
