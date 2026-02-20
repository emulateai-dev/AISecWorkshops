# MCP Red Teaming Labs

These labs focus on exploiting the **Model Context Protocol (MCP)** — the open standard for connecting AI assistants to external tools and data sources.

---

## Labs

| Lab | Tool | Status |
|-----|------|--------|
| _MCP Server Impersonation_ | — | Coming soon |
| _Tool Poisoning Attacks_ | — | Coming soon |
| _Rug Pull via Tool Description Mutation_ | — | Coming soon |

---

## Background

MCP defines how AI clients (Claude, Cursor, custom agents) discover and invoke server-provided tools. The protocol's trust model introduces several attack vectors:

- **Tool poisoning** — a malicious MCP server advertises tools whose descriptions contain hidden prompt injection payloads, manipulating the AI client's behavior
- **Rug pull attacks** — an MCP server changes tool descriptions after initial approval, introducing malicious instructions without user awareness
- **Server impersonation** — spoofing a trusted MCP server to intercept tool calls or inject responses
- **Argument injection** — crafting tool schemas that trick the AI into passing sensitive data (API keys, file contents) as arguments
- **Cross-server exfiltration** — using one MCP server's tools to exfiltrate data obtained via another server's context

---

## Prerequisites

- DTX Lab VM with tools installed
- Familiarity with MCP protocol basics
- Familiarity with the [LLM Red Teaming labs](../llms/red-teaming/) (recommended)
