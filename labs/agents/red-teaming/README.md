# Agent Red Teaming Labs

These labs focus on attacking and evaluating autonomous AI agents — systems that use LLMs to plan, reason, and take actions in the real world.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## Labs

| # | Lab | Tool | Challenges | Time | Description |
|---|-----|------|-----------|------|-------------|
| 1 | [Prompt Injection Challenges](./folly/README.md) | Folly | 15+ | ~30 min | Interactive prompt injection and system prompt extraction via web UI |
| 2 | [Enterprise Deep Research (EDR)](./edr/readme.md) | EDR Agent | 7 | ~45 min | RAG poisoning, indirect prompt injection, Text2SQL fraud, hallucination |
| 3 | [Airline Customer Support Agent](./open-ai-cs-agent/readme.md) | OpenAI Agents SDK | 10 | ~60 min | Guardrail bypass, BOLA, social engineering, multi-turn PII attacks |
|   | _Tool-Use Exploitation_ | — | — | — | Coming soon |
|   | _Multi-Step Goal Hijacking_ | — | — | — | Coming soon |

---

## Background

AI agents extend LLM capabilities with tool access — web browsing, code execution, file I/O, database queries, and API calls. This expanded attack surface introduces risks that don't exist with standalone chat models:

- **Indirect prompt injection** — malicious instructions embedded in data the agent retrieves (web pages, emails, documents)
- **Tool-use exploitation** — tricking the agent into calling dangerous tools or passing harmful arguments
- **Goal hijacking** — redirecting the agent's multi-step plan toward an attacker-controlled objective
- **Privilege escalation** — abusing the agent's access permissions to reach systems beyond its intended scope
- **Data exfiltration** — causing the agent to leak sensitive context through its tool calls
- **Broken Object Level Authorization (BOLA)** — agents performing state changes on behalf of unverified principals
- **Hallucination exploitation** — inducing agents to fabricate plausible but false outputs via permissive role framing

---

## Attack Surface Map

```
User Prompt ──► [Guardrail] ──► [Triage / Router Agent]
                                         │
                     ┌───────────────────┼───────────────────┐
                     │                   │                   │
               [Specialist         [Tool Calls]       [Sub-Agents]
                Agents]                  │
                     │           ┌───────┴───────┐
                     │      Web Browse     DB Queries
                     │      (Injection?)   (SQL Abuse?)
                     │
               RAG Retrieval
               (Poisoned Docs?)
```

Each junction in this map is an attack surface. The labs in this section target each one systematically.

---

## Prerequisites

- DTX Lab VM with tools installed → [VM Setup Guide](../../setup/vm/README.md)
- `OPENAI_API_KEY` or `GROQ_API_KEY` exported
- `python3` and `pip3` installed
- Familiarity with the [LLM Red Teaming labs](../../llms/red-teaming/) (recommended)

---

## Recommended Learning Path

```
1. Folly (Prompt Injection Basics)
        │
        ▼
2. OpenAI CS Agent (Guardrail Bypass, BOLA, Social Engineering)
        │
        ▼
3. Enterprise Deep Research (RAG Poisoning, Text2SQL, Web Injection)
```

Start with **Folly** to build foundational prompt injection intuition, then progress to the more complex agentic systems.
