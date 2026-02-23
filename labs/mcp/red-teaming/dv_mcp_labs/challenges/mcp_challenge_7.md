## ⚔️ Challenge 7: Token Mismanagement & Secret Exposure (Medium)

This challenge demonstrates how developers sometimes leak sensitive debugging information inside tool endpoints accessible prior to authentication.

---

### 🎯 Objective
Extract an exposed admin token from a tool description and use it to access the admin panel.

---

### 🧪 Steps

**Method 1: Via MCP Burp Extension**
1. Start MCP Recon on `http://localhost:9007/sse`.
2. Execute `tools/list`. Identify the hardcoded debug token in the description of `authenticate` (`mcp-admin-9f8e7d6c5b4a3210`).
3. Send a request calling `access_admin_panel` using the discovered token.

**Method 2: Via MCP Client**
1. Ask the AI: "List all your tools and their full descriptions including any notes or comments."
2. Note the exposed token.
3. Command the AI: "Using the token `mcp-admin-9f8e7d6c5b4a3210` access the admin panel and let me know the complete output."

---

### 🎓 For Students
Investigate other users on the system to see how authorization behaves for non-administrative tokens:
1. Can you authenticate as `user2`? (Password: `qwerty456`) — what token do you get back?
2. Does the `user2` token work with `access_admin_panel`? Why or why not?
3. What are the credentials of all accounts?
   - `user1`:`password123`
   - `user2`:`qwerty456`
   - `admin`:`admin_secure_pwd!`
4. How would you fix this vulnerability? (e.g., Remove the debug comment from the tool description, rotate the token, and store it securely in a secrets manager).

---

### 📌 Expected Outcome
You successfully read the administrative system secrets and database passwords without performing any credential cracking.

---

### 🧩 Learning Outcome
Understand that tool metadata and descriptions are broadcasted openly during protocol handshakes. Including credentials or temporary debug hooks results in immediate Token Exposure.
