# OpenCode Setup — Groq and Ollama

[OpenCode](https://opencode.ai) is a terminal coding agent (TUI) that talks to 75+ LLM
providers. This guide wires it up to the two providers used in the workshop, and shows
**both authentication mechanisms** for each — pick whichever fits your box.

Verified against `opencode 1.18.23` and `ollama 0.30.10`.

## At a glance

| Provider | Mechanism | How you authenticate | Where the credential lives | Best for |
|---|---|---|---|---|
| **Groq** | A1 | `/connect` inside OpenCode | `~/.local/share/opencode/auth.json` | Laptops, interactive use |
| **Groq** | A2 | `export GROQ_API_KEY=...` | Your shell env / `~/.bashrc` | VMs, CI, scripted labs |
| **Ollama (local)** | — | none needed | — | Offline / air-gapped labs |
| **Ollama Cloud** | B1 | `ollama signin` (browser) | `~/.ollama` (managed by Ollama) | Desktop with a browser |
| **Ollama Cloud** | B2 | `export OLLAMA_API_KEY=...` | Your shell env / `~/.bashrc` | Headless VMs, CI, direct API calls |

Mechanisms are **not** mutually exclusive — you can configure Groq and Ollama at the
same time and switch models inside the TUI with `/models` (see [§5](#5-using-groq-and-ollama-together)).

Optional extra: [§7](#7-optional--dump-the-raw-llm-requests-and-responses) shows how to
capture the raw JSON requests and responses OpenCode sends to the model — the single
most useful view for the agent red-teaming labs.

---

## 1. Install OpenCode

Pick one method:

```bash
# Recommended: install script (installs to ~/.opencode/bin)
curl -fsSL https://opencode.ai/install | bash

# or with npm
npm install -g opencode-ai

# or with Homebrew (macOS / Linuxbrew)
brew install sst/tap/opencode
```

Make sure the binary is on your `PATH` (the install script adds `~/.opencode/bin`):

```bash
export PATH="$HOME/.opencode/bin:$PATH"   # add to ~/.bashrc or ~/.zshrc
opencode --version
```

Upgrade later with `opencode upgrade`.

---

## 2. Groq

### 2.0 Get the key

1. Sign in at <https://console.groq.com>.
2. Go to **API Keys → Create API Key**.
3. Copy the key (starts with `gsk_...`). It is shown only once.

### Mechanism A1 — `/connect` (interactive, stored by OpenCode)

Start OpenCode and run the connect command:

```bash
opencode
```

```
/connect
```

Search for **Groq**, press Enter, paste the API key. Credentials are written to
`~/.local/share/opencode/auth.json`.

Shell equivalent, outside the TUI:

```bash
opencode auth login       # alias of: opencode providers login
opencode auth list        # show which providers have stored credentials
```

Use this when the machine is yours and you want the key to persist across shells
without living in a dotfile.

### Mechanism A2 — `GROQ_API_KEY` environment variable

```bash
export GROQ_API_KEY="gsk_your_key_here"

# persist it
echo 'export GROQ_API_KEY="gsk_your_key_here"' >> ~/.bashrc
```

OpenCode reads `GROQ_API_KEY` automatically — no `/connect` needed. Use this on lab
VMs, in CI, or anywhere you provision the box from a script.

> ⚠️ Never commit the key. Keep it out of Git, screenshots, and shared VM snapshots.

**Precedence:** OpenCode documents that **config-file options take precedence over
environment variables** — so an `apiKey` in `opencode.json` overrides `GROQ_API_KEY`.
If a stored `/connect` credential and an environment variable disagree and you are not
sure which is in play, clear the stored one and retry:

```bash
opencode auth logout groq     # then restart OpenCode
```

### 2.1 List and pick a Groq model

```bash
opencode models groq
```

Typical output:

```
groq/llama-3.3-70b-versatile
groq/llama-3.1-8b-instant
groq/openai/gpt-oss-120b
groq/openai/gpt-oss-20b
groq/qwen/qwen3.6-27b
groq/groq/compound
...
```

Start OpenCode pinned to a model, or switch inside the TUI with `/models`:

```bash
opencode --model groq/llama-3.3-70b-versatile
```

One-shot (non-interactive) run:

```bash
opencode run --model groq/openai/gpt-oss-120b "Summarise the security risks in ./app.py"
```

---

## 3. Ollama

Ollama gives you two things: **local models** (free, offline, running on your own
CPU/GPU) and **Ollama Cloud models** (`:cloud` tags — large models run on Ollama's
servers, so a laptop with no GPU can drive them). Only the cloud models need auth.

### 3.1 Install Ollama

**Linux:**

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

The script installs to `/usr/local`, creates the `ollama` user, and registers + starts
a systemd service. The API then listens on `http://127.0.0.1:11434`.

**macOS / Windows:** download the app from <https://ollama.com/download>.

**Verify:**

```bash
ollama --version
systemctl status ollama --no-pager        # Linux service check
curl -s http://localhost:11434/api/tags   # should return JSON
```

If the daemon is not running (e.g. a container without systemd), start it manually in
another terminal:

```bash
ollama serve
```

See [SetupOllama.md](../ollama/SetupOllama.md) for the full local-model walkthrough.

### 3.2 Local models — no authentication required

```bash
ollama pull qwen3:1.7b
ollama run qwen3:1.7b        # quick sanity chat, /bye to exit
ollama list                  # what you have locally
```

Skip to [§4](#4-wiring-ollama-into-opencode) if you only need local models.

### Mechanism B1 — `ollama signin` (browser sign-in)

Links your ollama.com account to the CLI. Ollama then manages the credential for you,
so `ollama pull <model>:cloud`, `ollama run <model>:cloud`, and
`ollama launch opencode --model <model>:cloud` all just work:

```bash
ollama signin      # opens a browser to authorise this machine
ollama signout     # disconnect later
```

Use this on a desktop where a browser is available. Nothing to export, nothing to
rotate by hand.

### Mechanism B2 — `OLLAMA_API_KEY` (explicit key)

Required for headless VMs with no browser, for CI, and for any tool or `curl` call
that expects a bearer token.

1. Sign in at <https://ollama.com/signin>.
2. Go to **Settings → Keys** (<https://ollama.com/settings/keys>) → **Add API key**.
3. Copy the key and export it:

```bash
export OLLAMA_API_KEY="your_api_key_here"

# persist it
echo 'export OLLAMA_API_KEY="your_api_key_here"' >> ~/.bashrc
```

Test the key directly against the cloud API:

```bash
curl -s https://ollama.com/api/chat \
  -H "Authorization: Bearer $OLLAMA_API_KEY" \
  -d '{
    "model": "gpt-oss:120b",
    "messages": [{"role": "user", "content": "reply with the single word: ok"}],
    "stream": false
  }' | head -c 400
```

> ⚠️ Treat `OLLAMA_API_KEY` like any other secret — not in Git, not in VM snapshots,
> not on screen during a demo.

**B1 or B2?** Either is sufficient on its own. B1 is the fastest path on a desktop;
B2 is the only path on a headless box and is also what you need for the manual
OpenCode provider config in [§4.3](#43-manual-config-local-and-cloud-side-by-side).
Setting both is harmless.

### 3.3 Find and pull a cloud model

Cloud tags change often — list the live catalogue rather than trusting a hardcoded set:

```bash
curl -s https://ollama.com/api/tags | python3 -m json.tool | grep '"name"'
```

At the time of writing that returns models such as `glm-5.3-flash`, `glm-5.2`,
`kimi-k3`, `deepseek-v4-pro:preview`, `qwen3.5:397b`, `gpt-oss:120b`, `gpt-oss:20b`.
Web catalogue: <https://ollama.com/search?c=cloud>.

Cloud models still need their manifest pulled locally before any client can select
them. Append the `:cloud` tag:

```bash
ollama pull glm-5.3-flash:cloud
ollama list                       # cloud entries show size "-"
```

To disable cloud features entirely on a locked-down lab box:

```bash
export OLLAMA_NO_CLOUD=1
```

---

## 4. Wiring Ollama into OpenCode

Three routes. Route 4.1 is the quickest; 4.2 and 4.3 give you explicit control.

### 4.1 `ollama launch opencode` (auto-configures for you)

Ollama ships an OpenCode integration that writes the provider config itself:

```bash
# interactive menu of integrations
ollama launch

# launch OpenCode directly
ollama launch opencode

# pinned to a local model
ollama launch opencode --model qwen3:1.7b

# pinned to a cloud model (works with mechanism B1 or B2)
ollama launch opencode --model glm-5.3-flash:cloud
```

`ollama launch --help` lists every supported integration (`claude`, `codex`,
`opencode`, `cline`, `qwen`, `vscode`, …). The generated config lives in
`~/.ollama/config.json` under `integrations`.

### 4.2 `/connect` → Ollama Cloud (OpenCode's built-in provider)

Uses mechanism **B2** — it asks for the API key from [§3](#mechanism-b2--ollama_api_key-explicit-key):

1. Start `opencode`, run `/connect`, search **Ollama Cloud**, paste the API key.
2. `ollama pull <model>:cloud` so the manifest exists locally.
3. `/models` to select it.

Credentials land in `~/.local/share/opencode/auth.json`, same as Groq mechanism A1.

### 4.3 Manual config — local and cloud side by side

Create `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": {
        "qwen3:1.7b":  { "name": "Qwen3 1.7B" },
        "gpt-oss:20b": { "name": "GPT-OSS 20B" }
      }
    },
    "ollama-cloud": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama Cloud",
      "options": {
        "baseURL": "https://ollama.com/v1",
        "apiKey": "{env:OLLAMA_API_KEY}"
      },
      "models": {
        "glm-5.3-flash": { "name": "GLM 5.3 Flash" },
        "gpt-oss:120b":  { "name": "GPT-OSS 120B" }
      }
    }
  }
}
```

- The provider ID (`ollama`, `ollama-cloud`) is what you type in `--model`.
- `npm: "@ai-sdk/openai-compatible"` is used because Ollama exposes an OpenAI-style
  API — the `baseURL` **must** end in `/v1`.
- `{env:OLLAMA_API_KEY}` (mechanism B2) keeps the key out of the config file.
  `{file:~/.secrets/ollama-key}` is also supported if you prefer a secrets file.
- Local `models` keys must match tags from `ollama list`.

```bash
opencode --model ollama/qwen3:1.7b
opencode --model ollama-cloud/glm-5.3-flash
```

---

## 5. Using Groq and Ollama together

Nothing conflicts — configure both and switch per task. A combined
`~/.config/opencode/opencode.json` with Groq keyed from the environment
(mechanism A2) plus local and cloud Ollama:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "groq/llama-3.3-70b-versatile",
  "provider": {
    "groq": {
      "options": { "apiKey": "{env:GROQ_API_KEY}" }
    },
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "qwen3:1.7b": { "name": "Qwen3 1.7B" } }
    },
    "ollama-cloud": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama Cloud",
      "options": {
        "baseURL": "https://ollama.com/v1",
        "apiKey": "{env:OLLAMA_API_KEY}"
      },
      "models": { "glm-5.3-flash": { "name": "GLM 5.3 Flash" } }
    }
  }
}
```

`"model"` sets the default at startup; `/models` switches mid-session. If you
authenticated with `/connect` (A1/B1-style) you can drop the `apiKey` lines entirely —
the stored credential is picked up automatically.

Provision the whole thing on a fresh lab VM in one block:

```bash
# OpenCode
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"

# Groq (mechanism A2)
export GROQ_API_KEY="gsk_your_key_here"

# Ollama + cloud key (mechanism B2)
curl -fsSL https://ollama.com/install.sh | sh
export OLLAMA_API_KEY="your_api_key_here"
ollama pull qwen3:1.7b
ollama pull glm-5.3-flash:cloud

# sanity
opencode run --model groq/llama-3.1-8b-instant "reply with the single word: ok"
```

---

## 6. Verify the setup

```bash
opencode auth list                                # providers with stored credentials
opencode models                                   # every model OpenCode can reach
opencode models groq                              # Groq only
ollama list                                       # local + pulled cloud models
curl -s http://localhost:11434/api/tags | head    # local Ollama daemon is alive
curl -s https://ollama.com/api/tags | head        # cloud catalogue is reachable
echo "${GROQ_API_KEY:0:4}... ${OLLAMA_API_KEY:0:4}..."   # keys are exported
```

Smoke test each path:

```bash
opencode run --model groq/llama-3.1-8b-instant  "reply with the single word: ok"
opencode run --model ollama/qwen3:1.7b          "reply with the single word: ok"
opencode run --model ollama-cloud/glm-5.3-flash "reply with the single word: ok"
```

---

## 7. Optional — dump the raw LLM requests and responses

**Optional.** Nothing else in the workshop depends on this. Turn it on when you want to
see exactly what a coding agent puts on the wire: the full system prompt, every tool
definition, the tool results fed back in, and the model's raw reply. That transcript
*is* the attack surface for the agent and prompt-injection labs — reading it once
teaches more than any diagram.

OpenCode has **no built-in setting** that dumps request/response bodies (see
[§7.5](#75-what-does-not-work) for the three places people expect to find them and
don't). The community plugin [`@ljw1004/opencode-trace`](https://github.com/ljw1004/opencode-trace)
fills the gap: it patches `fetch`, so it records the true wire bodies rather than a
reconstruction.

Verified against `opencode 1.18.23` / `opencode-trace 0.1.4`.

### 7.1 Three ways to enable it

Pick one — they are alternatives, not steps.

**Route A — `opencode plugin` (recommended: no hand-edited JSON)**

```bash
# global — applies to every project on this machine
opencode plugin @ljw1004/opencode-trace --global

# or project-local — writes <project>/.opencode/opencode.json
cd /path/to/your/lab && opencode plugin @ljw1004/opencode-trace
```

The command fetches the package, detects the entrypoint, and writes the config for
you. It prints the scope it chose (`global` or `local`) and the exact file it touched.
Add `--force` to replace an already-installed version.

**Route B — edit a config file by hand**

Global, `~/.config/opencode/config.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["@ljw1004/opencode-trace"]
}
```

Project-scoped, `<project>/.opencode/opencode.json` — same `plugin` key. Use this to
keep tracing on for the lab repo and off everywhere else. A project config is enough
on its own; the global config does not need the plugin as well.

**Route C — vendor the plugin file (no config edit, no network at run time)**

OpenCode auto-loads any `.ts` dropped into `.opencode/plugin/` (`.opencode/plugins/`
also works). Copy the plugin's two files in and it loads with no `plugin` key anywhere:

```bash
mkdir -p .opencode/plugin
src=~/.cache/opencode/packages/@ljw1004/opencode-trace@latest/node_modules/@ljw1004/opencode-trace
cp "$src/index.ts" .opencode/plugin/trace.ts
cp "$src/viewer.js" .opencode/plugin/
```

This is the route for **air-gapped VMs** and for students who want to edit the plugin
and watch their changes take effect. Two caveats: you must have fetched the package
once on a connected machine to have those files, and the vendored copy gets loaded as
two module instances (TUI + server), so **every request and response is written
twice**. Deduplicate on read if it bothers you:

```bash
./trace-to-jsonl.sh <file>.html | jq -sc 'unique_by([._id,._kind])[]'
```

### 7.2 Confirm it is loaded

```bash
opencode debug config | python3 -c "import sys,json; print(json.load(sys.stdin).get('plugin'))"
# -> ['@ljw1004/opencode-trace']
```

Run this from inside the project directory — that is what makes a project-scoped
config (Route A local / Route B project) show up. Route C loads from disk and so does
**not** appear in `plugin`; prove it works by generating a trace instead.

### 7.3 Generate and read a trace

```bash
opencode run --model groq/llama-3.1-8b-instant "reply with the single word: ok"
ls -lt ~/opencode-trace/
```

One HTML file per session lands in `~/opencode-trace/`, named
`<date> <time> <first prompt>.html`. The path is hardcoded in the plugin — there is no
env var or config option to move it.

Open the file in a browser for the collapsible viewer. Each file is *also* the raw
data: the JSONL is appended after an unterminated `<!--` comment at the tail, so the
browser never renders it. Extract it with the helper in this directory:

```bash
./trace-to-jsonl.sh ~/opencode-trace/*.html > trace.jsonl

# what was exchanged, one line per call
jq -c '{_id,_kind,_purpose,_url}' trace.jsonl

# the full system prompt OpenCode sends
jq -r 'select(._kind=="request") | .messages[] | select(.role=="system") | .content' trace.jsonl

# every tool the agent was offered
jq -r 'select(._kind=="request") | .tools[]?.function.name' trace.jsonl
```

Each record carries `_id` (pairs a request with its response), `_kind`
(`request` / `response` / `error`), `_purpose` (`[meta]` marks OpenCode's own internal
calls, such as title generation), `_url`, and `_ts`.

### 7.4 Exercises worth doing with a trace open

- Diff the system prompt across providers — `--model groq/...` vs `--model ollama/...`.
- Count the tokens OpenCode spends on tool definitions before you type anything.
- Plant an injected instruction in a file, ask the agent to read it, and find the
  moment it enters the message history as a tool result.
- Compare `_purpose: "[meta]"` calls against the real ones: the agent talks to the
  model more often than the UI suggests.

### 7.5 What does not work

Three commonly cited approaches that will **not** give you request/response bodies on
1.18.x — check them off so you stop looking:

| Approach | Reality |
|---|---|
| `opencode --log-level DEBUG --print-logs` | `~/.local/share/opencode/log/opencode.log` records events and timings. No prompt or response bodies. |
| Reading `~/.local/share/opencode/storage/*.json` | That directory no longer exists. Session state moved to SQLite: `~/.local/share/opencode/opencode.db`. |
| `opencode export <sessionID>` | Real command, useful output — but it exports the *session object* (messages, tool calls, rendered text), not the HTTP bodies. |

### 7.6 Handling and hygiene

> ⚠️ A trace contains the complete conversation: system prompt, file contents the agent
> read, command output, and anything you pasted. On these labs that can include target
> URLs and secrets. Treat `~/opencode-trace/` as sensitive — do not commit it, do not
> ship it in a VM snapshot, and clear it before screen-sharing.

```bash
rm -rf ~/opencode-trace/*                       # clear traces
echo '.opencode/plugin/' >> .gitignore          # if you vendored via Route C
```

To turn tracing off: `opencode plugin` has no uninstall, so remove the `plugin` entry
from whichever config you edited, or delete the vendored files. `opencode --pure`
starts a single session with all external plugins disabled.

One upgrade gotcha, from the plugin's own README: the default install pins
`@latest`, which OpenCode does not refresh when upstream publishes. Force it with:

```bash
rm -rf ~/.cache/opencode/packages/@ljw1004/opencode-trace@latest
```

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `opencode: command not found` | Add `~/.opencode/bin` to `PATH`, then restart the shell. |
| Groq model missing from `/models` | Key not connected — run `/connect` (A1) or export `GROQ_API_KEY` (A2), then restart OpenCode. |
| `401 / invalid_api_key` from Groq | Key revoked or truncated on paste. Regenerate at the Groq console and re-apply A1 or A2. |
| Groq `429 rate_limit_exceeded` | Free-tier TPM/RPM limit. Wait, or switch to a smaller model (`llama-3.1-8b-instant`). |
| Env var seems ignored | An `apiKey` in `opencode.json` overrides it, and a stored `/connect` credential may also be in use. Remove the config `apiKey` and/or run `opencode auth logout <provider>`, then retry. |
| Ollama models absent from OpenCode | Daemon not running (`ollama serve` / `systemctl status ollama`) or wrong `baseURL` — it must end in `/v1`. |
| Cloud model errors with "not found" | Authenticate (B1 `ollama signin` **or** B2 `OLLAMA_API_KEY`), then `ollama pull <model>:cloud` before selecting it. |
| `401 Unauthorized` from `ollama.com` | `OLLAMA_API_KEY` missing, expired, or revoked. Create a fresh one at <https://ollama.com/settings/keys> and re-export it. |
| Cloud models unavailable even when signed in | `OLLAMA_NO_CLOUD=1` is set in the environment or service unit. Unset it and restart `ollama`. |
| `ollama pull` fails behind a proxy | Export `HTTPS_PROXY`/`HTTP_PROXY` for both your shell and the systemd unit (`systemctl edit ollama`). |
| Tool calls silently fail on a local model | Context window too small. Raise `num_ctx` / `OLLAMA_CONTEXT_LENGTH` to 16k–32k, or use a model with solid tool-calling support. |
| Small local models loop or ignore instructions | Expected — 0.5B–2B models are weak agents. Use them for demos only; run real tasks on Groq or a `:cloud` model. |
| No files appear in `~/opencode-trace/` (§7) | Plugin not loaded. Run `opencode debug config` **from the project directory** and check the `plugin` list; restart OpenCode after editing any config. |
| Every trace record appears twice (§7) | You used Route C (vendored plugin) — the module loads once for the TUI and once for the server. Harmless; dedupe with `jq -sc 'unique_by([._id,._kind])[]'`. |
| Trace HTML looks empty in the browser (§7) | The raw JSONL sits after an unterminated `<!--` at the tail, so it does not render. Use `trace-to-jsonl.sh` to read it. |

---

## 9. Workshop notes

- **Groq** is the default for lab exercises that need speed and reliable tool calling.
- **Ollama local** is the offline / air-gapped path and the one used for jailbreak and
  safety-alignment labs where an uncensored local model is the target.
- **Ollama Cloud** (`:cloud` tags) bridges the two: no GPU needed, but traffic leaves
  the VM — do not point it at sensitive lab data.
- On shared or recorded sessions prefer **A2 / B2** (environment variables) so no key
  is typed on camera, and clear them with `unset GROQ_API_KEY OLLAMA_API_KEY` afterwards.
- **Tracing ([§7](#7-optional--dump-the-raw-llm-requests-and-responses)) is optional but
  high value.** Enable it before the agent and MCP red-teaming labs so students can see
  the injected payload arrive in the message history rather than take it on trust. Clear
  `~/opencode-trace/` afterwards — the files hold whole conversations.
