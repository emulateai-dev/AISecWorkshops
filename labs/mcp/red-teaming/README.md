# MCP Red Teaming Labs

These labs focus on exploiting the **Model Context Protocol (MCP)** — the open standard for connecting AI assistants to external tools and data sources.

---

## Labs

| Lab | Tool | Challenges | Status |
|-----|------|------------|--------|
| [Damn Vulnerable MCP Server](./dv_mcp_labs/readme.md) | DVMS | 10 | ✅ Available |

`dv_mcp_labs` already covers tool poisoning, rug-pull attacks, and tool-name shadowing — see challenges [4](./dv_mcp_labs/challenges/mcp_challenge_4.md) (Rug Pull / Tool Poisoning) and [5](./dv_mcp_labs/challenges/mcp_challenge_5.md) (Tool Shadowing — a malicious tool with a similar name sitting alongside a legitimate one on the *same* server) specifically, plus injection, SSRF, auth, and permission-scope challenges across the rest of the set. Note challenge 5 is tool-level shadowing, not the *server*-level impersonation described below (a rogue server spoofing a trusted one) — that specific attack isn't covered by a challenge yet.

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
- Familiarity with the [LLM Red Teaming labs](../../llms/red-teaming/) (recommended)
