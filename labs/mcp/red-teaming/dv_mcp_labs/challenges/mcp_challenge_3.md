## ⚔️ Challenge 3: Excessive Permission Scope (Easy)

This challenge allows you to identify which tool provides overarching file-system access and demonstrate exploitation leading to unauthorized data retrieval.

---

### 🎯 Objective
Gain unauthorized privileges by exploiting a tool with excessive file read/write permissions.

---

### 🧪 Steps

**Method 1: Via MCP Burp Extension**
1. Start MCP Recon on `http://localhost:9003/sse`. You will see the `file_manager` tool and the `public://{filename}` resource.
2. Select `file_manager` and Send to Repeater.
3. Set the payload to read a sensitive file bypassing the public directory constraint:
   ```json
   "arguments": { "action": "read", "path": "/etc/passwd" }
   ```
4. Change the action to `write` and point the path to `/tmp/dvmcp_challenge3/public/hacked.txt` to prove unauthorized write access. Verify this file by sending a `resources/read` payload to `public://hacked.txt`.

**Method 2: Via MCP Client**
1. Command the AI directly to fetch protected files using its overarching tools:
   > "Read the file at `/tmp/dvmcp_challenge3/private/employee_salaries.txt`"

---

### 🎓 For Students
Try to complete the challenge without bruteforcing by retrieving the following configurations using the resources and tools correctly:
1. Use the `get_public_file` resource to retrieve the public files: `welcome.txt` and `public_file.txt`.
2. Use the excessive scope of the `file_manager` tool to retrieve the private file: `employee_salaries.txt`.
3. *Note: List the files under the `tmp/dvmcp_challenge3/public` and `tmp/dvmcp_challenge3/private` folder to solve Challenge 3 without bruteforcing.*

---

### 📌 Expected Outcome
You successfully retrieve private files (e.g., `employee_salaries.txt`) and bypass the restrictive `public://` constraints designed by the framework.

---

### 🧩 Learning Outcome
Recognize the risks of Excessive Permission Scope. Having a single multi-purpose tool with sweeping OS file-system privileges circumvents any framework-level path protections.
