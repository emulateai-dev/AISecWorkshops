# Damn Vulnerable MCP Server (DVMS) — Red Teaming Lab

This lab targets the **Model Context Protocol (MCP)** — a new standard for connecting AI agents to data sources and tools. Participants learn to exploit insecure tool implementations, resource leaks, and protocol-level vulnerabilities in MCP-enabled systems.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

---

## 🧠 What is MCP?

The **Model Context Protocol** allows AI agents to interact with "Servers" that provide:
- **Resources**: Read-only data sources (like files, database rows, or documents).
- **Tools**: Executable functions (like running code, sending emails, or searching the web).
- **Prompts**: Pre-defined templates for interacting with the AI.

The **Damn Vulnerable MCP Server (DVMS)** is a deliberately insecure implementation designed to teach developers and security researchers about the specific risks introduced by this protocol.

---

## 🚀 Setup Instructions

> **Prerequisites:** Make sure you have completed the **[Full VM Setup Guide](../../../setup/vm/README.md)**.
> 
> **Update the Repository:** Before proceeding, ensure your lab files are fully up to date by running `git pull` in the `AISecWorkshops` directory.

1. **Update and Install the DVMS lab**
   ```bash
   ~/labs/AISecWorkshops/labs/setup/scripts/tools/install-dvmcp.sh
   ```

   **Configure local hostname (emulateai-mcp.local):**
   Depending on your operating system, run the following command to map the lab's hostname to your local machine:
   
   - **Windows (PowerShell run as Administrator):**
     ```powershell
     Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 emulateai-mcp.local"
     ```
   
   - **Linux & macOS (Terminal run as root/sudo):**
     ```bash
     echo '127.0.0.1 emulateai-mcp.local' | sudo tee -a /etc/hosts
     ```

2. **Run the application**
   Navigate to each challenge directory and run the server. Most challenges run on different ports (18567-18576).
   ```bash
   $HOME/labs/mcp/start_service.sh
   python3 $HOME/labs/mcp/dv_mcp_labs/fixes/ollama_mcp_client.py
   ```

3. **Access via Burp Suite (Recommended)**
   Use the **MCP Burp Extension** to perform reconnaissance and direct exploitation without an LLM in the loop.
   
   **To install the Burp extension:**
   - Open Burp Suite.
   - Navigate to the **Extensions** tab -> **Installed** sub-tab.
   - Click the **Add** button.
   - Set the **Extension type** to **Java**.
   - Click **Select file ...** and navigate to:
     `$HOME/labs/mcp/red-taming/dv_mcp_labs/mcp-recon-burp-extension.jar`
   - Click **Next** to install and load the extension.

   **Port Forwarding (Cloud Users Only):**
   > **Note:** If you are running the lab in the cloud and want to use Burp Suite on your local machine, you must use SSH to port forward the challenge ports to your localhost. This is required specifically for Burp to connect to the remote MCP servers.
   > 
   > Run this from your local machine, substituting the appropriate port for the challenge you are testing (most challenges use ports 18567-18576):
   > ```bash
   > ssh -L 18567:localhost:18567 dtx@<your_cloud_ip>
   > ```

---

## ⚔️ Challenges Overview

The lab contains 10 escalating challenges covering everything from basic info leaks to full Remote Code Execution (RCE).

| # | Challenge | Vulnerability | Difficulty |
|---|-----------|---------------|------------|
| 1 | [Insufficient Authentication](#challenge-1) | Broken Access Control | 🟢 Easy |
| 2 | [Command Injection](#challenge-2) | Insecure OS Execution | 🟢 Easy |
| 3 | [Excessive Permission Scope](#challenge-3) | Over-privileged Tools | 🟢 Easy |
| 4 | [Rug Pull Attack](#challenge-4) | Dynamic Tool Poisoning | 🟡 Medium |
| 5 | [Tool Shadowing](#challenge-5) | Tool Impersonation | 🟡 Medium |
| 6 | [Indirect Prompt Injection](#challenge-6) | Malicious Doc Processing | 🟡 Medium |
| 7 | [Token Mismanagement](#challenge-7) | Secret Exposure in Metadata | 🟡 Medium |
| 8 | [Eval() RCE](#challenge-8) | Python Code Injection | 🔴 Hard |
| 9 | [Context Injection](#challenge-9) | Session Isolation Failure | 🔴 Hard |
| 10 | [Multi-Vector Chain](#challenge-10) | Vulnerability Chaining | 🔴 Hard |

---

## 📁 Lab Files

```
dv_mcp_labs/
├── readme.md                    # This file
└── challenges/
    ├── mcp_challenge_1.md       # Insufficient Auth & Authz
    ├── mcp_challenge_2.md       # Command Injection & Execution
    ├── mcp_challenge_3.md       # Excessive Permission Scope
    ├── mcp_challenge_4.md       # Rug Pull / Tool Poisoning
    ├── mcp_challenge_5.md       # Tool Shadowing / Impersonation
    ├── mcp_challenge_6.md       # Indirect Prompt Injection
    ├── mcp_challenge_7.md       # Token Mismanagement / Secret Exposure
    ├── mcp_challenge_8.md       # Command Injection via Eval()
    ├── mcp_challenge_9.md       # Context Injection & Over-Sharing
    └── mcp_challenge_10.md      # Multi-Vector Attack Chain
```

---

## 📖 Challenge Summaries

### [Challenge 1: Insufficient Auth & Authz](./challenges/mcp_challenge_1.md)
The server fails to hide sensitive resources like `internal://credentials` from the capability list. Unauthenticated clients can list and read these resources directly.

### [Challenge 2: Command Injection & Execution](./challenges/mcp_challenge_2.md)
A naive `execute_command` tool implementation allows attackers to inject secondary OS commands using `&&` or `|`, leading to system compromise.

### [Challenge 3: Excessive Permission Scope](./challenges/mcp_challenge_3.md)
A multi-purpose `file_manager` tool with sweeping system-level permissions allows for bypassing restrictive framework-level path protections.

### [Challenge 4: Rug Pull Attack / Tool Poisoning](./challenges/mcp_challenge_4.md)
A tool dynamically changes its own description after establishing trust, embedding malicious instructions that the AI then follows blindly.

### [Challenge 5: Tool Shadowing / Impersonation](./challenges/mcp_challenge_5.md)
Exploiting naming collisions where a malicious tool with a similar name (`get_user_roles` vs `get_user_role`) tricks the AI into escalating permissions.

### [Challenge 6: Indirect Prompt Injection](./challenges/mcp_challenge_6.md)
Processing a document containing hidden `[INTERNAL COMPLIANCE NOTE]` instructions that hijack the AI's objective to leak internal memos.

### [Challenge 7: Token Mismanagement & Secret Exposure](./challenges/mcp_challenge_7.md)
Sensitive hardcoded debug tokens are leaked inside tool descriptions broadcasted openly during the protocol handshake.

### [Challenge 8: Command Injection via Eval()](./challenges/mcp_challenge_8.md)
A math evaluator tool that uses Python's `eval()` function without sandboxing, allowing for arbitrary Python code execution (RCE).

### [Challenge 9: Context Injection & Over-Sharing](./challenges/mcp_challenge_9.md)
A failure in session isolation allows one user to read private notes belonging to other users or the system administrator by manipulating tool arguments.

### [Challenge 10: Multi-Vector Attack Chain](./challenges/mcp_challenge_10.md)
A complex chain where you must extract a master password, read secrets via path traversal, authenticate to get a JWT, and finally trigger RCE to dump tokens.

---

## 🧩 Key Learning Outcomes

1. **Protocol Reconnaissance** — Understanding how `resources/list` and `tools/list` expose the attack surface.
2. **Insecure Tool Design** — Why tools must never have shell-level access or un-sandboxed code evaluation.
3. **The Importance of Immutability** — Why tool/resource metadata must be static to prevent Rug Pull attacks.
4. **Namespace Management** — How to prevent shadowing and typo-squatting within an AI's tool registry.
5. **Secure Input Handling** — Sanitizing text inputs to prevent Indirect Prompt Injection in multi-modal agents.
6. **Session & Context Isolation** — Implementing strict cryptographic boundaries between user data and AI tool execution environments.

---

## 🔗 Related Labs

- [Enterprise Deep Research (EDR)](../../../agents/red-teaming/edr/readme.md) — Attack a RAG-based agent system.
- [OpenAI CS Agent](../../../agents/red-teaming/open-ai-cs-agent/readme.md) — Exploiting multi-agent orchestration.
- [Prompt Injection (Folly)](../../../agents/red-teaming/folly/README.md) — Interactive injection challenges.
