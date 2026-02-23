## ⚔️ Challenge 2: Command Injection & Execution (Easy)

This challenge involves exploiting a `tools/call` implementation that insecurely executes operating system commands.

---

### 🎯 Objective
Execute arbitrary system commands (e.g., `id`, `mkdir`) and exploit path traversal vulnerabilities.

---

### 🧪 Steps

**Method 1: Via MCP Burp Extension**
1. Start MCP Recon on `http://localhost:9002/sse`. You will discover tools: `execute_command` and `read_file`.
2. Send `execute_command` to Repeater.
3. Modify the `command` argument to inject a secondary command using `&&`:
   ```json
   "command": "ls && id"
   ```
4. **Path Traversal Exploitation:** In Repeater, run `"command": "pwd && mkdir -p /tmp/safe"` to create a safe directory that bypasses preliminary checks.
5. Send `read_file` to Repeater. Set the filename to traverse out of the folder and read secured files:
   ```json
   "filename": "/tmp/safe/../../../etc/passwd"
   ```

**Method 2: Via MCP Client**
1. Ask the AI client to blindly execute the injected command chain:
   > "Run the command `ls && cat /etc/passwd`"

---

### 🎓 For Students: Exploitation of Path Traversal
1. **Verify the valid directory:** In Repeater (`execute_command`), run: `"command": "ls -ld /tmp/safe"`. You will see "No such file or directory". This explains why `read_file` fails immediately - the validation check `startswith('/tmp/safe/')` passes, but the OS can't open a file in a non-existent folder!
2. **Create the directory (The Fix):** In Repeater (`execute_command`), run: `"command": "pwd && mkdir -p /tmp/safe"`. Result: Command executes. It prints the current directory and creates the folder.
3. **Exploit Path Traversal:** Select `read_file` and Send to Repeater. Set the filename to traverse out of the now-existing folder: `"filename": "/tmp/safe/../../../etc/passwd"`. Click Send.
4. **Success!** The server returns the contents of `/etc/passwd`.

---

### 📌 Expected Outcome
The server takes the injected input and passes it directly to a system shell, exposing the current directory files and the `/etc/passwd` contents.

---

### 🧩 Learning Outcome
Understand that passing user input directly to a system shell without sanitization results in critical Command Injection. Developers must restrict and sanitize shell commands robustly.
