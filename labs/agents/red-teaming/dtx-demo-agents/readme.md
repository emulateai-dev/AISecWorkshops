# DTX Demo Agents — Target Sandbox

A small Docker Compose sandbox of target GenAI apps — a chat demo, a RAG demo, a tool-use agent demo, and a text2sql agent demo — sitting behind a jailbreak/prompt-guard proxy (`detoxio/dtxguard`). Use it to practice the attack techniques covered elsewhere in this workshop (RAG poisoning ideas from [EDR](../edr/readme.md), tool/text2sql abuse ideas from EDR's Text2SQL challenge, prompt injection ideas from [Folly](../folly/README.md)) against a second, differently-built target.

> **Legal note:** All tools and techniques in these labs are for authorized testing only. Use them only on systems you own or have explicit permission to test.

> **Note:** this is a **target sandbox**, not a scored challenge set like EDR or DVMCP — there are no numbered writeups here. It previously lived in a separate repo ([detoxio-ai/ai-red-teaming-training](https://github.com/detoxio-ai/ai-red-teaming-training)) that AISecWorkshops evolved from; it's vendored directly here now so setup doesn't need to clone that entire older repo just for this one compose stack.

---

## 🚀 Setup Instructions

> **Prerequisites:** Make sure you have completed the [VM Setup](../../../setup/vm/README.md) and have the required API keys configured.

1. **Install / start the stack**

   ```bash
   INSTALL_SCRIPTS=$HOME/labs/AISecWorkshops/labs/setup/scripts/tools/
   $INSTALL_SCRIPTS/install-dtx-demo-agents.sh
   ```

   This creates `.env` from `.env.template`, injects your `OPENAI_API_KEY`, and brings the stack up.

2. **Or run manually**

   ```bash
   cd $HOME/labs/AISecWorkshops/labs/agents/red-teaming/dtx-demo-agents
   cp .env.template .env   # edit .env first if you need non-default values
   docker compose up -d
   ```

3. **Check what's running**

   ```bash
   docker compose ps
   ```

4. **Stop the stack**

   ```bash
   docker compose down
   ```

---

## Services Overview

| Service | Description | Default URL |
|---|---|---|
| **pg** (prompt guard) | Jailbreak/prompt-safety filtering service the demo apps route through | `http://localhost:18001` |
| **demo** | Chat app UI | `http://localhost:17860` |
| **demo_rag** | RAG app UI | `http://localhost:17861` |
| **demo_tool_agents** | Tool-use agent UI | `http://localhost:17862` |
| **demo_text2sql_agents** | Text2SQL agent UI | `http://localhost:17863` |
| **ollama** | Local model runtime used by this stack | `http://localhost:11436` |

**Isolation note:** this stack's `ollama` service uses its own named Docker volume (`dtx_demo_ollama_data`), not the host's `~/.ollama`. That's deliberate — the host already runs its own Ollama service (from `Pre_Installation.sh`), and two independent Ollama daemons writing to the same model directory concurrently is a real corruption risk, not just a naming clash. Don't change this back to a `$HOME/.ollama` bind mount.

To run Ollama commands against this stack's own instance specifically:

```bash
docker compose exec ollama ollama list
```

---

## 🔗 Related Labs

- [Enterprise Deep Research (EDR)](../edr/readme.md) — structured, scored RAG-poisoning / Text2SQL / prompt-injection challenges
- [Prompt Injection Challenges (Folly)](../folly/README.md) — interactive prompt injection via web UI
- [OpenAI Customer Support Agent Red Teaming](../open-ai-cs-agent/readme.md) — attack a multi-agent customer service system
