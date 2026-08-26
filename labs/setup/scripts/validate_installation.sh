#!/usr/bin/env bash
set -euo pipefail

# === Parse arguments ===
LOG_FILE=""
DEBUG=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    --debug)
      DEBUG=1
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 [--log /path/to/logfile] [--debug]"
      exit 1
      ;;
  esac
done

[[ $DEBUG -eq 1 ]] && set -x

# === Default log file ===
if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="$HOME/dtx-validate.log"
fi

# === Logging helper ===
log() {
  echo "$1"
  echo "$1" >> "$LOG_FILE"
}

# === Start log ===
log "🔍 DTX Validation Log - $(date)"
log "=================================="

# === Helper Functions ===
# Every ❌ below increments FAILED so the run ends with a real verdict
# instead of always printing "complete". WARNED tracks non-fatal gaps
# (e.g. an API key you have not pasted in yet).
FAILED=0
WARNED=0

check_tool() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" &>/dev/null; then
    local version
    version="$($cmd --version 2>&1 | head -n 1 || echo 'Unknown version')"
    log "✅ $name is installed: $version"
  else
    log "❌ $name is NOT installed"
    FAILED=$((FAILED+1))
  fi
}

# Interpreters can come from apt OR from uv's standalone builds, so check
# both before declaring one missing (Ubuntu 25.04 has no python3.10/3.12).
check_python() {
  local ver="$1"
  if command -v "python${ver}" &>/dev/null; then
    log "✅ python${ver} (apt)"
  elif uv python find "${ver}" &>/dev/null; then
    log "✅ python${ver} (uv)"
  else
    log "❌ python${ver} is NOT available"
    FAILED=$((FAILED+1))
  fi
}

check_service() {
  local name="$1"
  if systemctl is-active --quiet "$name"; then
    log "✅ service '$name' is active"
  else
    log "❌ service '$name' is NOT active"
    FAILED=$((FAILED+1))
  fi
}

check_model() {
  local label="$1" pattern="$2"
  if grep -q "$pattern" <<<"$OLLAMA_MODEL_LIST"; then
    log "✅ ollama model: $label"
  else
    log "❌ ollama model MISSING: $label"
    FAILED=$((FAILED+1))
  fi
}

check_url() {
  local name="$1"
  local url="$2"
  log "🌐 $name [$url]..."
  for i in {1..5}; do
    if curl -sk --head --fail "$url" >/dev/null; then
      log "✅ $name reachable at $url"
      return 0
    else
      sleep 10
    fi
  done
  log "❌ $name not reachable after 5 tries ($url)"
  return 1
}

# === External IP ===
log ""
log "🌍 External Network Info"
EXTERNAL_IP=$(curl -s ifconfig.io || echo "Unavailable")
log "🌐 External IP: $EXTERNAL_IP"

# === Secrets ===
log ""
log "🔐 Validating API keys..."
# A file that exists but is EMPTY is the common failure — the setup scripts
# create placeholders, and an empty one exports nothing, so the labs fail
# later with an opaque auth error. Check content, not just existence.
for key in OPENAI_API_KEY GROQ_API_KEY HF_TOKEN; do
  if [[ -s "$HOME/.secrets/$key.txt" ]]; then
    log "✅ $key is set"
  elif [[ -f "$HOME/.secrets/$key.txt" ]]; then
    log "⚠️  $key.txt exists but is EMPTY — add it with: echo '<your key>' > \$HOME/.secrets/$key.txt"
    WARNED=$((WARNED+1))
  else
    log "❌ Missing $HOME/.secrets/$key.txt"
    FAILED=$((FAILED+1))
  fi
done
# Optional — only some labs use Anthropic; absence is not a failure.
if [[ -s "$HOME/.secrets/ANTHROPIC_API_KEY.txt" ]]; then
  log "✅ ANTHROPIC_API_KEY is set (optional)"
else
  log "ℹ️  ANTHROPIC_API_KEY not set (optional — only needed by some labs)"
fi

# === CLI Tools ===
log ""
log "🧰 Validating core tools..."
check_tool "Docker" docker
check_tool "Git" git
check_tool "curl" curl
check_tool "Python (uv)" python3
check_tool "Node.js" node
check_tool "npm" npm
check_tool "Go" go
check_tool "asdf" asdf
check_tool "uv" uv
check_tool "llm CLI" llm
check_tool "Nmap" nmap
check_tool "Metasploit" msfconsole
check_tool "Ollama" ollama
check_tool "Promptfoo" promptfoo
check_tool "Garak" garak
check_tool "DTX" dtx
check_tool "Amass" amass
check_tool "Subfinder" subfinder
check_tool "Nuclei" nuclei
check_tool "AutogenStudio" autogenstudio
check_tool "httpx" httpx
check_tool "jq" jq
check_tool "git-lfs" git-lfs
check_tool "HuggingFace CLI" hf
check_tool "pyrit-cli" pyrit-cli
check_tool "CAI framework" cai

# === Python interpreters ===
log ""
log "🐍 Validating Python interpreters..."
check_python 3.10
check_python 3.12
check_python 3.13

# === Services ===
log ""
log "⚙️  Validating services..."
check_service docker
check_service ollama
check_service nginx

# === Ollama models ===
log ""
log "🧠 Validating Ollama models..."
# One `ollama list` call reused for every check below.
OLLAMA_MODEL_LIST="$(ollama list 2>/dev/null || true)"
if [[ -z "$OLLAMA_MODEL_LIST" ]]; then
  log "❌ Could not list Ollama models (is the daemon running?)"
  FAILED=$((FAILED+1))
else
  check_model "smollm2"                "^smollm2"
  check_model "qwen3:0.6b"             "^qwen3:0.6b"
  check_model "llama-guard3:1b-q3_K_S" "^llama-guard3:1b-q3_K_S"
  check_model "llama3.1"               "^llama3.1"
  check_model "SmolLM-135M-Jailbroken" "SmolLM-135M-Instruct-Jailbroken"
  check_model "jailbroken-llama"       "^jailbroken-llama"
  check_model "vulnerable-llama"       "^vulnerable-llama"
fi

# === Repo submodules ===
log ""
log "📦 Validating repo submodules..."
# A plain `git clone` without --recurse-submodules leaves these empty, which
# breaks the PyRIT labs in a way that looks like a missing tool.
for sub in PyRIT pyrit_cli; do
  SUB_DIR="$HOME/labs/AISecWorkshops/labs/setup/pyrit/$sub"
  if [[ -d "$SUB_DIR" ]] && [[ -n "$(ls -A "$SUB_DIR" 2>/dev/null)" ]]; then
    log "✅ submodule populated: $sub"
  else
    log "❌ submodule EMPTY: $SUB_DIR — run: cd $HOME/labs/AISecWorkshops && git submodule update --init --recursive"
    FAILED=$((FAILED+1))
  fi
done

# === Start Docker Services ===
log ""
log "🚀 Starting Docker labs..."

if cd "$HOME/labs/pentagi"; then
  log "$(docker compose up -d 2>&1)" && log "✅ Pentagi started" || log "❌ Pentagi failed"
else
  log "ℹ️  PentAGI not installed; skipping (optional lab)."
fi

if cd "$HOME/labs/AISecWorkshops/labs/agents/red-teaming/dtx-demo-agents"; then
  log "$(docker compose up -d 2>&1)" && log "✅ DTX Demo Agents started" || log "❌ DTX Demo Agents failed"
else
  log "ℹ️  DTX Demo Agents not installed; skipping (optional lab)."
fi

# === AI Red Teaming Playground Labs ===
if cd "$HOME/labs/agents/AI-Red-Teaming-Playground-Labs" 2>/dev/null; then
  log "🚀 Starting AI Red Teaming Playground Labs..."
  log "$(./start_service.sh 2>&1)" || true
  sleep 5
  check_url "Playground Home (localhost)" "http://localhost:15000" || true
  log "🛑 Stopping Playground..."
  log "$(docker compose -f docker-compose-openai.yaml down 2>&1)" || true
else
  log "ℹ️ Playground not installed; skipping."
fi

# === Start Promptfoo and Autogen Studio ===
log ""
log "🚀 Starting Promptfoo and Autogen Studio (no tmux)..."

promptfoo dev > /dev/null 2>&1 &
PROMPTFOO_PID=$!
sleep 1
if ps -p $PROMPTFOO_PID > /dev/null 2>&1; then
  log "✅ Promptfoo started with PID $PROMPTFOO_PID"
else
  log "❌ Promptfoo failed to start"
fi

autogenstudio ui --port 18081 > /dev/null 2>&1 &
AUTOGEN_PID=$!
sleep 1
if ps -p $AUTOGEN_PID > /dev/null 2>&1; then
  log "✅ Autogen Studio started with PID $AUTOGEN_PID"
else
  log "❌ Autogen Studio failed to start"
fi


log ""
log "🧪 Testing PentestGPT OpenAI API connectivity..."

OPENAI_KEY_FILE="$HOME/.secrets/OPENAI_API_KEY.txt"
if [[ -f "$OPENAI_KEY_FILE" ]]; then
  export OPENAI_API_KEY="$(cat "$OPENAI_KEY_FILE")"
  CONNECTION_OUTPUT="$(pentestgpt-connection 2>&1 || true)"

  if echo "$CONNECTION_OUTPUT" | grep -q "You're connected with OpenAI API"; then
    log "✅ PentestGPT connection successful:"
    echo "$CONNECTION_OUTPUT" | grep -v "CHATGPT_COOKIE" >> "$LOG_FILE"
  else
    log "❌ PentestGPT connection failed:"
    echo "$CONNECTION_OUTPUT" >> "$LOG_FILE"
  fi
else
  log "❌ OPENAI_API_KEY.txt not found, skipping PentestGPT connection test."
fi


sleep 10

# === Port Checks ===
log ""
log "🌐 Checking port accessibility..."

PORTS=(
  "Pentagi|https://localhost:8443"
  "Chatbot Demo|http://localhost:17860"
  "RAG Demo|http://localhost:17861"
  "Tool Agents Demo|http://localhost:17862"
  "Text2SQL Demo|http://localhost:17863"
  "Promptfoo UI|http://localhost:8080"
  "Autogen Studio|http://localhost:18081"
)

for entry in "${PORTS[@]}"; do
  IFS="|" read -r name url <<< "$entry"
  if check_url "$name (localhost)" "$url"; then
    if [[ "$EXTERNAL_IP" != "Unavailable" ]]; then
      external_url="${url/localhost/$EXTERNAL_IP}"
      check_url "$name (external)" "$external_url"
    fi
  else
    log "⚠️ Skipping external check for $name since internal is not reachable."
  fi
done

# === Stop Docker Services ===
log ""
log "🛑 Stopping Docker labs..."

if cd "$HOME/labs/pentagi"; then
  log "$(docker compose down 2>&1)" && log "✅ Pentagi stopped"
fi

if cd "$HOME/labs/AISecWorkshops/labs/agents/red-teaming/dtx-demo-agents"; then
  log "$(docker compose down 2>&1)" && log "✅ DTX Demo Agents stopped"
fi

# === Stop Background UIs ===
log ""
log "🛑 Stopping background web UIs..."

if ps -p $PROMPTFOO_PID > /dev/null 2>&1; then
  kill $PROMPTFOO_PID && log "✅ Promptfoo stopped (PID $PROMPTFOO_PID)"
else
  log "⚠️ Promptfoo process not found."
fi

if ps -p $AUTOGEN_PID > /dev/null 2>&1; then
  kill $AUTOGEN_PID && log "✅ Autogen Studio stopped (PID $AUTOGEN_PID)"
else
  log "⚠️ Autogen Studio process not found."
fi

# === Done ===
log ""
log "=================================="
if [[ "$FAILED" -gt 0 ]]; then
  log "❌ DTX Validation complete — $FAILED check(s) FAILED, $WARNED warning(s)."
  log "   Scroll up for the ❌ lines. Most are fixed by re-running:"
  log "     sudo $HOME/labs/AISecWorkshops/labs/setup/vm/Pre_Installation.sh"
  log "     sudo $HOME/labs/AISecWorkshops/labs/setup/vm/Tool_Setup.sh"
  [[ -n "$LOG_FILE" ]] && log "📄 Log saved to $LOG_FILE"
  exit 1
elif [[ "$WARNED" -gt 0 ]]; then
  log "✅ DTX Validation complete — all checks passed, $WARNED warning(s) (usually unset API keys)."
  [[ -n "$LOG_FILE" ]] && log "📄 Log saved to $LOG_FILE"
else
  log "✅ DTX Validation complete — all checks passed."
  [[ -n "$LOG_FILE" ]] && log "📄 Log saved to $LOG_FILE"
fi
