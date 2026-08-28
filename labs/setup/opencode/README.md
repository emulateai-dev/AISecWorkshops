# OpenCode Setup — Groq, DeepInfra, and Ollama

[OpenCode](https://opencode.ai) is a terminal coding agent (TUI) that talks to 75+ LLM
providers. This guide wires it up to the three providers used in the workshop, and shows
**both authentication mechanisms** for each — pick whichever fits your box.

Verified against `opencode 1.18.23` and `ollama 0.30.10`.

## At a glance

| Provider | Mechanism | How you authenticate | Where the credential lives | Best for |
|---|---|---|---|---|
| **Groq** | A1 | `/connect` inside OpenCode | `~/.local/share/opencode/auth.json` | Laptops, interactive use |
| **Groq** | A2 | `export GROQ_API_KEY=...` | Your shell env / `~/.bashrc` | VMs, CI, scripted labs |
| **DeepInfra** | C1 | `/connect` inside OpenCode | `~/.local/share/opencode/auth.json` | Laptops, interactive use |
| **DeepInfra** | C2 | `export DEEPINFRA_API_KEY=...` | Your shell env / `~/.bashrc` | VMs, CI, scripted labs |
| **Ollama (local)** | — | none needed | — | Offline / air-gapped labs |
| **Ollama Cloud** | B1 | `ollama signin` (browser) | `~/.ollama` (managed by Ollama) | Desktop with a browser |
| **Ollama Cloud** | B2 | `export OLLAMA_API_KEY=...` | Your shell env / `~/.bashrc` | Headless VMs, CI, direct API calls |

Mechanisms are **not** mutually exclusive — you can configure all three at the
same time and switch models inside the TUI with `/models` (see [§6](#6-using-groq-deepinfra-and-ollama-together)).

Optional extra: [§8](#8-optional--dump-the-raw-llm-requests-and-responses) shows how to
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

Output (August 2026):

```
groq/allam-2-7b
groq/groq/compound
groq/groq/compound-mini
groq/openai/gpt-oss-120b
groq/openai/gpt-oss-20b
groq/qwen/qwen3.6-27b
...
```

> ⚠️ **`opencode models` is a static catalogue, not a live check.** It comes from
> [models.dev](https://models.dev) and drifts from what your Groq account can actually
> serve — in both directions. Models it lists can be retired (`llama-3.3-70b-versatile`
> and `llama-3.1-8b-instant` are listed but now return *"does not exist or you do not
> have access to it"*), and models Groq serves can be missing from it
> (`qwen/qwen3.8-27b` is live on Groq but absent from the catalogue, so OpenCode fails
> it with `UnknownError`). Ask Groq directly for ground truth:
>
> ```bash
> curl -s https://api.groq.com/openai/v1/models \
>   -H "Authorization: Bearer $GROQ_API_KEY" | python3 -m json.tool | grep '"id"'
> ```
>
> A model must be in **both** lists to be usable from OpenCode.

**`--model` always takes `provider/model`** — and several Groq IDs carry an org prefix
of their own, so they end up with three segments. `qwen/qwen3.6-27b` alone is not a
valid ID; OpenCode would read `qwen` as the provider name:

```bash
opencode --model groq/qwen/qwen3.6-27b        # ✅  provider + org + model
opencode --model qwen/qwen3.6-27b             # ❌  "qwen" is not a provider
```

The same applies to `groq/openai/gpt-oss-120b` and `groq/meta-llama/...`.

Start OpenCode pinned to a model, or switch inside the TUI with `/models`:

```bash
opencode --model groq/openai/gpt-oss-120b
opencode --model groq/qwen/qwen3.6-27b
```

Verified working from OpenCode at the time of writing: `groq/openai/gpt-oss-120b`,
`groq/openai/gpt-oss-20b`, `groq/qwen/qwen3.6-27b`.

There is **no `--api_base` / `--api-base` flag.** Groq is a built-in provider, so
OpenCode already knows the endpoint. Passing an unknown flag makes OpenCode print its
help screen and exit 1 — if that is all you get back, look for a typo'd flag before
anything else. To genuinely override an endpoint, see the `baseURL` option in
[§6](#6-using-groq-deepinfra-and-ollama-together).

One-shot (non-interactive) run:

```bash
opencode run --model groq/openai/gpt-oss-120b "Summarise the security risks in ./app.py"
```

---

## 3. DeepInfra

DeepInfra is a hosted inference provider with a broad open-weights catalogue —
Qwen, Llama, DeepSeek, Mistral — billed per token. It is the third-party route when
Groq does not carry the model you want and you have no GPU for Ollama. OpenCode ships
it as a **built-in provider**, so there is no base URL to configure.

### 3.0 Get the key

1. Sign in at <https://deepinfra.com>.
2. Go to **Dashboard → API Keys** (<https://deepinfra.com/dash/api_keys>) → **New API key**.
3. Copy the key.

### Mechanism C1 — `/connect` (interactive, stored by OpenCode)

```bash
opencode
```

```
/connect
```

Search for **Deep Infra** (two words), press Enter, paste the key. Stored in
`~/.local/share/opencode/auth.json`, the same place as Groq A1 and Ollama Cloud.
Shell equivalent: `opencode auth login`.

### Mechanism C2 — `DEEPINFRA_API_KEY` environment variable

```bash
export DEEPINFRA_API_KEY="your_deepinfra_key"

# persist it
echo 'export DEEPINFRA_API_KEY="your_deepinfra_key"' >> ~/.bashrc
```

Exporting the variable is enough on its own — the provider registers with no config
file and no `/connect`. Verify:

```bash
opencode models deepinfra | head
```

If the provider is missing entirely, the key is not exported in *this* shell.

> ⚠️ Same rule as every other key in this workshop: not in Git, not in a VM snapshot,
> not on screen during a demo. Prefer C2 on recorded sessions.

### 3.1 Pick a model — mind the three-segment ID

DeepInfra model names already contain an organisation prefix (`Qwen/`, `meta-llama/`,
`deepseek-ai/`). OpenCode prepends the provider on top, so a DeepInfra ID has **three**
segments and is **case-sensitive**:

```
deepinfra / Qwen / Qwen3.8-27B
└ provider  └ org  └ model
```

```bash
opencode models deepinfra | grep -i qwen3.8
```

```
deepinfra/Qwen/Qwen3.8-2.4T-A95B
deepinfra/Qwen/Qwen3.8-27B
deepinfra/Qwen/Qwen3.8-Max
```

Start OpenCode on it:

```bash
export DEEPINFRA_API_KEY="your_deepinfra_key"
opencode --model deepinfra/Qwen/Qwen3.8-27B
```

One-shot, non-interactive:

```bash
opencode run --model deepinfra/Qwen/Qwen3.8-27B "Summarise the security risks in ./app.py"
```

`Qwen3.8-27B` is a sensible default for the agent labs: 262K context, 32K output, and
**both** tool calling and reasoning — unlike the small local Ollama models, it can
actually drive a tool loop. Roughly $0.40 per 1M input tokens and $3.00 per 1M output
at the time of writing; check <https://deepinfra.com/models> for current pricing and
the live catalogue.

> The first run downloads the `@ai-sdk/deepinfra` package, so it needs network access
> even if you have the key. Air-gapped VMs should use local Ollama instead.

---

## 4. Ollama

Ollama gives you two things: **local models** (free, offline, running on your own
CPU/GPU) and **Ollama Cloud models** (`:cloud` tags — large models run on Ollama's
servers, so a laptop with no GPU can drive them). Only the cloud models need auth.

### 4.1 Install Ollama

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

### 4.2 Local models — no authentication required

```bash
ollama pull qwen3:1.7b
ollama run qwen3:1.7b        # quick sanity chat, /bye to exit
ollama list                  # what you have locally
```

Skip to [§5](#5-wiring-ollama-into-opencode) if you only need local models.

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
OpenCode provider config in [§5.3](#53-manual-config--local-and-cloud-side-by-side).
Setting both is harmless.

### 4.3 Find and pull a cloud model

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

## 5. Wiring Ollama into OpenCode

Three routes. Route 5.1 is the quickest; 5.2 and 5.3 give you explicit control.

### 5.1 `ollama launch opencode` (auto-configures for you)

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

### 5.2 `/connect` → Ollama Cloud (OpenCode's built-in provider)

Uses mechanism **B2** — it asks for the API key from [§4](#mechanism-b2--ollama_api_key-explicit-key):

1. Start `opencode`, run `/connect`, search **Ollama Cloud**, paste the API key.
2. `ollama pull <model>:cloud` so the manifest exists locally.
3. `/models` to select it.

Credentials land in `~/.local/share/opencode/auth.json`, same as Groq mechanism A1.

### 5.3 Manual config — local and cloud side by side

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

## 6. Using Groq, DeepInfra, and Ollama together

Nothing conflicts — configure all of them and switch per task. A combined
`~/.config/opencode/opencode.json` with Groq and DeepInfra keyed from the environment
(mechanisms A2 and C2) plus local and cloud Ollama:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "groq/openai/gpt-oss-120b",
  "provider": {
    "groq": {
      "options": { "apiKey": "{env:GROQ_API_KEY}" }
    },
    "deepinfra": {
      "options": { "apiKey": "{env:DEEPINFRA_API_KEY}" }
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
authenticated with `/connect` (A1/B1/C1-style) you can drop the `apiKey` lines entirely —
the stored credential is picked up automatically.

Groq and DeepInfra are built-in providers, so they need no `npm` or `baseURL` — the
`apiKey` line alone is enough, and even that is optional when the environment variable
is exported. `baseURL` is the *only* way to override an endpoint (a proxy, a
compatible gateway); there is no command-line flag for it:

```json
"groq": { "options": { "baseURL": "https://api.groq.com/openai/v1" } }
```

Provision the whole thing on a fresh lab VM in one block:

```bash
# OpenCode
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"

# Groq (mechanism A2)
export GROQ_API_KEY="gsk_your_key_here"

# DeepInfra (mechanism C2)
export DEEPINFRA_API_KEY="your_deepinfra_key"

# Ollama + cloud key (mechanism B2)
curl -fsSL https://ollama.com/install.sh | sh
export OLLAMA_API_KEY="your_api_key_here"
ollama pull qwen3:1.7b
ollama pull glm-5.3-flash:cloud

# sanity
opencode run --model groq/openai/gpt-oss-20b       "reply with the single word: ok"
opencode run --model deepinfra/Qwen/Qwen3.8-27B    "reply with the single word: ok"
```

---

## 7. Verify the setup

```bash
opencode auth list                                # providers with stored credentials
opencode models                                   # every model OpenCode can reach
opencode models groq                              # Groq only
opencode models deepinfra                         # DeepInfra only
ollama list                                       # local + pulled cloud models
curl -s http://localhost:11434/api/tags | head    # local Ollama daemon is alive
curl -s https://ollama.com/api/tags | head        # cloud catalogue is reachable

# keys are exported (prefix only — never echo a whole key on a shared screen)
echo "${GROQ_API_KEY:0:4}... ${DEEPINFRA_API_KEY:0:4}... ${OLLAMA_API_KEY:0:4}..."
```

A provider missing from `opencode models` means neither its key nor a stored
credential was found — it is never a model-name problem.

Smoke test each path:

```bash
opencode run --model groq/openai/gpt-oss-20b     "reply with the single word: ok"
opencode run --model groq/qwen/qwen3.6-27b       "reply with the single word: ok"
opencode run --model deepinfra/Qwen/Qwen3.8-27B  "reply with the single word: ok"
opencode run --model ollama/qwen3:1.7b           "reply with the single word: ok"
opencode run --model ollama-cloud/glm-5.3-flash  "reply with the single word: ok"
```

---

## 8. Optional — dump the raw LLM requests and responses

**Optional.** Nothing else in the workshop depends on this. Turn it on when you want to
see exactly what a coding agent puts on the wire: the full system prompt, every tool
definition, the tool results fed back in, and the model's raw reply. That transcript
*is* the attack surface for the agent and prompt-injection labs — reading it once
teaches more than any diagram.

OpenCode has **no built-in setting** that dumps request/response bodies (see
[§8.5](#85-what-does-not-work) for the three places people expect to find them and
don't). The community plugin [`@ljw1004/opencode-trace`](https://github.com/ljw1004/opencode-trace)
fills the gap: it patches `fetch`, so it records the true wire bodies rather than a
reconstruction.

Verified against `opencode 1.18.23` / `opencode-trace 0.1.4`.

### 8.1 Three ways to enable it

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

### 8.2 Confirm it is loaded

```bash
opencode debug config | python3 -c "import sys,json; print(json.load(sys.stdin).get('plugin'))"
# -> ['@ljw1004/opencode-trace']
```

Run this from inside the project directory — that is what makes a project-scoped
config (Route A local / Route B project) show up. Route C loads from disk and so does
**not** appear in `plugin`; prove it works by generating a trace instead.

### 8.3 Generate and read a trace

```bash
opencode run --model groq/openai/gpt-oss-20b "reply with the single word: ok"
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

### 8.4 Exercises worth doing with a trace open

- Diff the system prompt across providers — `--model groq/...` vs `--model ollama/...`.
- Count the tokens OpenCode spends on tool definitions before you type anything.
- Plant an injected instruction in a file, ask the agent to read it, and find the
  moment it enters the message history as a tool result.
- Compare `_purpose: "[meta]"` calls against the real ones: the agent talks to the
  model more often than the UI suggests.

### 8.5 What does not work

Three commonly cited approaches that will **not** give you request/response bodies on
1.18.x — check them off so you stop looking:

| Approach | Reality |
|---|---|
| `opencode --log-level DEBUG --print-logs` | `~/.local/share/opencode/log/opencode.log` records events and timings. No prompt or response bodies. |
| Reading `~/.local/share/opencode/storage/*.json` | That directory no longer exists. Session state moved to SQLite: `~/.local/share/opencode/opencode.db`. |
| `opencode export <sessionID>` | Real command, useful output — but it exports the *session object* (messages, tool calls, rendered text), not the HTTP bodies. |

### 8.6 Handling and hygiene

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

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| `opencode: command not found` | Add `~/.opencode/bin` to `PATH`, then restart the shell. |
| Groq model missing from `/models` | Key not connected — run `/connect` (A1) or export `GROQ_API_KEY` (A2), then restart OpenCode. |
| Groq: `The model X does not exist or you do not have access to it` | The model is in OpenCode's static catalogue but retired by Groq (e.g. the `llama-3.x` IDs). Check the live list with `curl https://api.groq.com/openai/v1/models` and pick from it ([§2.1](#21-list-and-pick-a-groq-model)). |
| Groq: `UnknownError` / `Unexpected server error` on a model Groq does list | The reverse drift — Groq serves it but OpenCode's catalogue has no entry (e.g. `qwen/qwen3.8-27b`). Use a model present in **both** `opencode models groq` and the Groq API list. |
| `401 / invalid_api_key` from Groq | Key revoked or truncated on paste. Regenerate at the Groq console and re-apply A1 or A2. |
| Groq `429 rate_limit_exceeded` | Free-tier TPM/RPM limit. Wait, or switch to a smaller model (`groq/openai/gpt-oss-20b`). |
| OpenCode prints its **help screen** and exits `1` | An unrecognised flag. The arg parser is strict and there is no `--api_base`/`--api-base`; endpoints are set with `baseURL` in config ([§6](#6-using-groq-deepinfra-and-ollama-together)). |
| `provider not found` / model not recognised | `--model` needs `provider/model`. Many IDs carry an org prefix, so the full ID has three segments: `groq/qwen/qwen3.6-27b`, `deepinfra/Qwen/Qwen3.8-27B`. Copy it verbatim from `opencode models`. |
| DeepInfra model rejected as unknown | DeepInfra IDs are **case-sensitive** — `deepinfra/qwen/qwen3.8-27b` fails, `deepinfra/Qwen/Qwen3.8-27B` works. |
| `deepinfra` absent from `opencode models` | `DEEPINFRA_API_KEY` not exported in this shell and no stored credential. Export it (C2) or run `opencode auth login` (C1). |
| First DeepInfra run hangs or fails offline | It downloads `@ai-sdk/deepinfra` on first use. Needs network — on an air-gapped VM use local Ollama. |
| Env var seems ignored | An `apiKey` in `opencode.json` overrides it, and a stored `/connect` credential may also be in use. Remove the config `apiKey` and/or run `opencode auth logout <provider>`, then retry. |
| Ollama models absent from OpenCode | Daemon not running (`ollama serve` / `systemctl status ollama`) or wrong `baseURL` — it must end in `/v1`. |
| Cloud model errors with "not found" | Authenticate (B1 `ollama signin` **or** B2 `OLLAMA_API_KEY`), then `ollama pull <model>:cloud` before selecting it. |
| `401 Unauthorized` from `ollama.com` | `OLLAMA_API_KEY` missing, expired, or revoked. Create a fresh one at <https://ollama.com/settings/keys> and re-export it. |
| Cloud models unavailable even when signed in | `OLLAMA_NO_CLOUD=1` is set in the environment or service unit. Unset it and restart `ollama`. |
| `ollama pull` fails behind a proxy | Export `HTTPS_PROXY`/`HTTP_PROXY` for both your shell and the systemd unit (`systemctl edit ollama`). |
| Tool calls silently fail on a local model | Context window too small. Raise `num_ctx` / `OLLAMA_CONTEXT_LENGTH` to 16k–32k, or use a model with solid tool-calling support. |
| Small local models loop or ignore instructions | Expected — 0.5B–2B models are weak agents. Use them for demos only; run real tasks on Groq or a `:cloud` model. |
| No files appear in `~/opencode-trace/` (§8) | Plugin not loaded. Run `opencode debug config` **from the project directory** and check the `plugin` list; restart OpenCode after editing any config. |
| Every trace record appears twice (§8) | You used Route C (vendored plugin) — the module loads once for the TUI and once for the server. Harmless; dedupe with `jq -sc 'unique_by([._id,._kind])[]'`. |
| Trace HTML looks empty in the browser (§8) | The raw JSONL sits after an unterminated `<!--` at the tail, so it does not render. Use `trace-to-jsonl.sh` to read it. |

---

## 10. Workshop notes

- **Groq** is the default for lab exercises that need speed and reliable tool calling.
- **DeepInfra** is the fallback when Groq does not carry the model you need. It is the
  broadest open-weights catalogue of the three and is billed per token, so keep an eye
  on spend during long agent loops — `opencode stats` shows usage and cost.
- **Ollama local** is the offline / air-gapped path and the one used for jailbreak and
  safety-alignment labs where an uncensored local model is the target.
- **Ollama Cloud** (`:cloud` tags) bridges the two: no GPU needed, but traffic leaves
  the VM — do not point it at sensitive lab data.
- On shared or recorded sessions prefer **A2 / B2 / C2** (environment variables) so no
  key is typed on camera, and clear them afterwards with
  `unset GROQ_API_KEY DEEPINFRA_API_KEY OLLAMA_API_KEY`.
- **Tracing ([§8](#8-optional--dump-the-raw-llm-requests-and-responses)) is optional but
  high value.** Enable it before the agent and MCP red-teaming labs so students can see
  the injected payload arrive in the message history rather than take it on trust. Clear
  `~/opencode-trace/` afterwards — the files hold whole conversations.
