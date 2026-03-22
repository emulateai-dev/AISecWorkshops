#!/usr/bin/env bash
# ============================================================
#  install-folly.sh
#  Installer for Folly – LLM Prompt Injection Challenge Framework
#
#  Installs:
#    • user1342/Folly repo
#    • Python 3.7+ virtualenv + pip install -e .
#    • Ollama (optional, for local model provider)
#    • Helper scripts: start_service.sh / stop_service.sh
#
#  Providers supported (via start_service.sh):
#    openai  → https://api.openai.com/v1
#    groq    → https://api.groq.com/openai/v1
#    ollama  → http://localhost:11434/v1  (requires Ollama installed)
#
#  Supports: Ubuntu / Debian-based Linux (tested on 22.04+)
#  Usage:    bash install-folly.sh
#
#  Override via environment variables before running:
#    BASE_DIR=/custom/path bash install-folly.sh
#    INSTALL_OLLAMA=false bash install-folly.sh
# ============================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[→]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }

echo ""
echo "============================================================"
echo "   Folly – Prompt Injection Challenge Framework  Installer"
echo "   Source: user1342/Folly"
echo "============================================================"
echo ""

# ── Configuration (override via env vars) ─────────────────────
BASE_DIR="${BASE_DIR:-$HOME/labs/agents/red-teaming/folly}"
REPO_URL="${REPO_URL:-https://github.com/user1342/Folly.git}"
CLONE_DIR="${CLONE_DIR:-Folly}"
API_PORT="${API_PORT:-5000}"
UI_PORT="${UI_PORT:-5001}"
INSTALL_OLLAMA="${INSTALL_OLLAMA:-true}"
OLLAMA_DEFAULT_MODEL="${OLLAMA_DEFAULT_MODEL:-llama3.1}"

LAB_DIR="${BASE_DIR}/${CLONE_DIR}"
PID_DIR="${XDG_RUNTIME_DIR:-/tmp}/folly"

echo "  BASE_DIR      = ${BASE_DIR}"
echo "  REPO_URL      = ${REPO_URL}"
echo "  CLONE_DIR     = ${CLONE_DIR}"
echo "  API_PORT      = ${API_PORT}"
echo "  UI_PORT       = ${UI_PORT}"
echo "  INSTALL_OLLAMA= ${INSTALL_OLLAMA}"
echo ""

# ── 1. Preflight checks ───────────────────────────────────────
info "Running preflight checks..."

need() {
  command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed. Please install it first."
}

need git
need python3
need pip3

# Validate Python version >= 3.7
PY_MAJ=$(python3 -c 'import sys; print(sys.version_info.major)')
PY_MIN=$(python3 -c 'import sys; print(sys.version_info.minor)')
if [[ "${PY_MAJ}" -lt 3 || ( "${PY_MAJ}" -eq 3 && "${PY_MIN}" -lt 7 ) ]]; then
  error "Python 3.7+ is required. Found: ${PY_MAJ}.${PY_MIN}."
fi
success "Python ${PY_MAJ}.${PY_MIN} found."
success "Preflight checks passed."

# ── 2. Create base directory ──────────────────────────────────
info "Ensuring base directory exists: ${BASE_DIR}"
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"
success "Base directory ready."

# ── 3. Clone / update the repository ─────────────────────────
info "Checking repository: ${CLONE_DIR}"
if [[ -d "${LAB_DIR}/.git" ]]; then
  info "Repository already exists. Pulling latest changes..."
  git -C "${LAB_DIR}" pull --ff-only || warn "Could not pull latest – continuing with existing version."
  success "Repository up-to-date: ${LAB_DIR}"
else
  info "Cloning repository from ${REPO_URL} ..."
  git clone "${REPO_URL}" "${CLONE_DIR}"
  success "Cloned into: ${LAB_DIR}"
fi

cd "${LAB_DIR}"

# ── 4. Python virtual environment ────────────────────────────
info "Setting up Python virtual environment in ${LAB_DIR}/venv ..."
if [[ ! -d "${LAB_DIR}/venv" ]]; then
  python3 -m venv "${LAB_DIR}/venv"
  success "Virtual environment created."
else
  success "Virtual environment already exists."
fi

# Upgrade pip inside venv
"${LAB_DIR}/venv/bin/pip" install --quiet --upgrade pip

# ── 5. Install Folly (editable mode) ─────────────────────────
info "Installing Folly via pip install -e . ..."
if [[ -f "${LAB_DIR}/setup.py" ]]; then
  "${LAB_DIR}/venv/bin/pip" install -e "${LAB_DIR}"
  success "Folly installed in editable mode."
else
  warn "setup.py not found. Falling back to requirements.txt ..."
  if [[ -f "${LAB_DIR}/requirements.txt" ]]; then
    "${LAB_DIR}/venv/bin/pip" install -r "${LAB_DIR}/requirements.txt"
    success "Requirements installed from requirements.txt."
  else
    error "Neither setup.py nor requirements.txt found in ${LAB_DIR}."
  fi
fi

# ── 6. Verify entry-point commands ───────────────────────────
info "Verifying Folly entry-point commands..."
PASS=true
for cmd in folly-api folly-ui folly-cli; do
  BIN="${LAB_DIR}/venv/bin/${cmd}"
  if [[ -x "${BIN}" ]]; then
    success "${cmd} → ${BIN}"
  else
    warn "${cmd} not found in venv/bin — it may still be accessible if venv is activated."
    PASS=false
  fi
done
if ! ${PASS}; then
  warn "Some commands were not found. Activate the venv and retry: source ${LAB_DIR}/venv/bin/activate"
fi

# ── 7. Ollama – install and pull default model ────────────────
if [[ "${INSTALL_OLLAMA}" == "true" ]]; then
  info "Checking Ollama (local LLM runtime) ..."
  if command -v ollama >/dev/null 2>&1; then
    success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
  else
    info "Installing Ollama ..."
    curl -fsSL https://ollama.com/install.sh | sh
    success "Ollama installed."
  fi

  # Ensure Ollama service is running
  info "Ensuring Ollama service is running ..."
  if pgrep -x "ollama" >/dev/null 2>&1; then
    success "Ollama service is already running."
  else
    ollama serve >/dev/null 2>&1 &
    sleep 4
    if pgrep -x "ollama" >/dev/null 2>&1; then
      success "Ollama service started."
    else
      warn "Ollama may not have started. Start it manually with: ollama serve"
    fi
  fi

  # Pull default model
  info "Checking Ollama model '${OLLAMA_DEFAULT_MODEL}' ..."
  if ollama list 2>/dev/null | grep -q "^${OLLAMA_DEFAULT_MODEL}"; then
    success "Model '${OLLAMA_DEFAULT_MODEL}' already available in Ollama."
  else
    info "Pulling '${OLLAMA_DEFAULT_MODEL}' from Ollama... (this may take a few minutes)"
    if ollama pull "${OLLAMA_DEFAULT_MODEL}"; then
      success "Model '${OLLAMA_DEFAULT_MODEL}' pulled."
    else
      warn "Failed to pull '${OLLAMA_DEFAULT_MODEL}'. Pull manually: ollama pull ${OLLAMA_DEFAULT_MODEL}"
    fi
  fi
else
  info "Skipping Ollama install (INSTALL_OLLAMA=false)."
fi

# ── 8. Generate start_service.sh helper ──────────────────────────────
START_SCRIPT="${BASE_DIR}/start_service.sh"
info "Generating start script: ${START_SCRIPT}"
cat > "${START_SCRIPT}" <<EOF
#!/usr/bin/env bash
# start_service.sh – Start Folly API + UI (Prompt Injection Challenge Framework)
# ============================================================
# Usage:
#   ./start_service.sh                    – basic challenges, OpenAI (default)
#   ./start_service.sh advanced           – advanced challenges
#   FOLLY_PROVIDER=groq ./start_service.sh
#   FOLLY_PROVIDER=ollama ./start_service.sh
#   FOLLY_MODEL=llama3.2 FOLLY_PROVIDER=ollama ./start_service.sh advanced
#
# Provider env vars:
#   FOLLY_PROVIDER  openai (default) | groq | ollama
#   FOLLY_MODEL     override default model for the chosen provider
# ============================================================
set -euo pipefail

LAB_DIR="${LAB_DIR}"
API_PORT="\${API_PORT:-${API_PORT}}"
UI_PORT="\${UI_PORT:-${UI_PORT}}"
PROVIDER="\${FOLLY_PROVIDER:-openai}"
CHALLENGE_SET="\${1:-basic}"
PID_DIR="\${XDG_RUNTIME_DIR:-/tmp}/folly"

echo ""
echo "============================================================"
echo "   Folly – Start"
echo "============================================================"
echo ""

# --- Pre-flight ---
FOLLY_API="\${LAB_DIR}/venv/bin/folly-api"
FOLLY_UI="\${LAB_DIR}/venv/bin/folly-ui"
[[ -x "\${FOLLY_API}" ]] || { echo "❌ folly-api not found at \${FOLLY_API}. Run the install script first."; exit 1; }
[[ -x "\${FOLLY_UI}"  ]] || { echo "❌ folly-ui  not found at \${FOLLY_UI}. Run the install script first."; }

# Guard: already running?
if [[ -d "\${PID_DIR}" ]] && { [[ -f "\${PID_DIR}/api.pid" ]] || [[ -f "\${PID_DIR}/ui.pid" ]]; }; then
  echo "⚠️  Folly may already be running. Run ./stop_service.sh first, or check:"
  echo "    API PID: \$(cat "\${PID_DIR}/api.pid" 2>/dev/null || echo 'none')"
  echo "    UI  PID: \$(cat "\${PID_DIR}/ui.pid"  2>/dev/null || echo 'none')"
  exit 1
fi

# --- Resolve challenge config ---
case "\${CHALLENGE_SET}" in
  basic)
    CONFIG_FILE="\${LAB_DIR}/example_challenges/prompt_injection_masterclass.json"
    ;;
  advanced|advance)
    CONFIG_FILE="\${LAB_DIR}/example_challenges/advanced_injection_challenges.json"
    ;;
  *)
    if [[ -f "\${CHALLENGE_SET}" ]]; then
      CONFIG_FILE="\${CHALLENGE_SET}"
    elif [[ -f "\${LAB_DIR}/example_challenges/\${CHALLENGE_SET}" ]]; then
      CONFIG_FILE="\${LAB_DIR}/example_challenges/\${CHALLENGE_SET}"
    else
      echo "❌ Unknown challenge set: \${CHALLENGE_SET}"
      echo "   Use: basic, advanced, or a path to a JSON file."
      exit 1
    fi
    ;;
esac

# --- Resolve provider / API URL / model / key ---
case "\${PROVIDER}" in
  openai)
    API_URL="https://api.openai.com/v1"
    MODEL="\${FOLLY_MODEL:-gpt-4}"
    if [[ -n "\${OPENAI_API_KEY:-}" ]]; then
      API_KEY="\${OPENAI_API_KEY}"
    elif [[ -f "\$HOME/.secrets/OPENAI_API_KEY.txt" ]]; then
      API_KEY="\$(cat "\$HOME/.secrets/OPENAI_API_KEY.txt")"
    else
      echo "❌ OPENAI_API_KEY not set and ~/.secrets/OPENAI_API_KEY.txt not found."
      exit 1
    fi
    ;;
  groq)
    API_URL="https://api.groq.com/openai/v1"
    MODEL="\${FOLLY_MODEL:-llama-3.3-70b-versatile}"
    if [[ -n "\${GROQ_API_KEY:-}" ]]; then
      API_KEY="\${GROQ_API_KEY}"
    elif [[ -f "\$HOME/.secrets/GROQ_API_KEY.txt" ]]; then
      API_KEY="\$(cat "\$HOME/.secrets/GROQ_API_KEY.txt")"
    else
      echo "❌ GROQ_API_KEY not set and ~/.secrets/GROQ_API_KEY.txt not found."
      exit 1
    fi
    ;;
  ollama)
    API_URL="http://localhost:11434/v1"
    MODEL="\${FOLLY_MODEL:-${OLLAMA_DEFAULT_MODEL}}"
    API_KEY="ollama"   # Ollama accepts any non-empty key
    # Ensure Ollama is running
    if ! pgrep -x "ollama" >/dev/null 2>&1; then
      echo "⚠️  Ollama service not running. Starting it..."
      nohup ollama serve >/tmp/ollama.log 2>&1 &
      sleep 4
    fi
    # Verify model is available
    if ! ollama list 2>/dev/null | grep -q "^\${MODEL}"; then
      echo "⚠️  Model '\${MODEL}' not found in Ollama. Pulling..."
      ollama pull "\${MODEL}" || { echo "❌ Failed to pull '\${MODEL}'. Run: ollama pull \${MODEL}"; exit 1; }
    fi
    ;;
  *)
    echo "❌ Unknown provider: \${PROVIDER}"
    echo "   Supported: openai | groq | ollama"
    exit 1
    ;;
esac

mkdir -p "\${PID_DIR}"

echo "  Provider:   \${PROVIDER}"
echo "  API URL:    \${API_URL}"
echo "  Model:      \${MODEL}"
echo "  Challenges: \${CONFIG_FILE}"
echo "  API port:   \${API_PORT}"
echo "  UI  port:   \${UI_PORT}"
echo ""

# --- Start API (background) ---
echo "🚀 Starting Folly API on http://localhost:\${API_PORT} ..."
cd "\${LAB_DIR}"
nohup "\${FOLLY_API}" "\${API_URL}" \\
  --model "\${MODEL}" \\
  --api-key "\${API_KEY}" \\
  --port "\${API_PORT}" \\
  "\${CONFIG_FILE}" \\
  > "\${PID_DIR}/api.log" 2>&1 &
API_PID=\$!
echo "\${API_PID}" > "\${PID_DIR}/api.pid"
echo "   API PID: \${API_PID}  (log: \${PID_DIR}/api.log)"

# --- Wait for API to be ready ---
echo -n "   Waiting for API..."
for i in \$(seq 1 30); do
  if curl -s "http://localhost:\${API_PORT}" >/dev/null 2>&1; then
    echo " ready!"
    break
  fi
  if ! kill -0 "\${API_PID}" 2>/dev/null; then
    echo " failed!"
    echo "❌ API process exited. Check: \${PID_DIR}/api.log"
    cat "\${PID_DIR}/api.log" || true
    rm -f "\${PID_DIR}/api.pid"
    exit 1
  fi
  sleep 1
  echo -n "."
done

# --- Start UI (background) ---
echo "🖥️  Starting Folly UI on http://localhost:\${UI_PORT} ..."
nohup "\${FOLLY_UI}" "http://localhost:\${API_PORT}" \\
  > "\${PID_DIR}/ui.log" 2>&1 &
UI_PID=\$!
echo "\${UI_PID}" > "\${PID_DIR}/ui.pid"
echo "   UI  PID: \${UI_PID}  (log: \${PID_DIR}/ui.log)"

echo ""
echo "✅ Folly is running!"
echo ""
echo "   Open in browser → http://localhost:\${UI_PORT}"
echo "   API backend     → http://localhost:\${API_PORT}"
echo ""
echo "   Stop with:  \$(dirname "\$0")/stop_service.sh"
echo ""
EOF
chmod +x "${START_SCRIPT}"
success "Created: ${START_SCRIPT}"

# ── 9. Generate stop_service.sh helper ───────────────────────────────
STOP_SCRIPT="${BASE_DIR}/stop_service.sh"
info "Generating stop script: ${STOP_SCRIPT}"
cat > "${STOP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
# stop_service.sh – Stop Folly API + UI
set -euo pipefail

PID_DIR="${XDG_RUNTIME_DIR:-/tmp}/folly"

echo "=== Folly Stop ==="

STOPPED=false

stop_pid() {
  local label="$1" pid_file="$2"
  if [[ -f "${pid_file}" ]]; then
    PID="$(cat "${pid_file}")"
    if kill -0 "${PID}" 2>/dev/null; then
      echo "🛑 Stopping Folly ${label} (PID ${PID}) ..."
      kill "${PID}"
      sleep 1
      if kill -0 "${PID}" 2>/dev/null; then
        echo "   Sending SIGKILL ..."
        kill -9 "${PID}" 2>/dev/null || true
      fi
      echo "   ✅ ${label} stopped."
    else
      echo "   ℹ️  ${label} (PID ${PID}) was not running."
    fi
    rm -f "${pid_file}"
    STOPPED=true
  fi
}

stop_pid "API" "${PID_DIR}/api.pid"
stop_pid "UI"  "${PID_DIR}/ui.pid"

# Fallback: kill by port if no PID files found
if ! ${STOPPED}; then
  echo "   No PID files found. Checking ports 5000/5001 ..."
  for port in 5000 5001; do
    PORT_PID="$(lsof -ti :"${port}" 2>/dev/null || true)"
    if [[ -n "${PORT_PID}" ]]; then
      echo "   🛑 Killing process on port ${port} (PID ${PORT_PID}) ..."
      kill "${PORT_PID}" 2>/dev/null || true
      STOPPED=true
    fi
  done
fi

if ${STOPPED}; then
  echo ""
  echo "✅ Folly stopped."
else
  echo ""
  echo "ℹ️  No running Folly processes found."
fi

rm -f "${PID_DIR}/api.log" "${PID_DIR}/ui.log" 2>/dev/null || true
rmdir "${PID_DIR}" 2>/dev/null || true
EOF
chmod +x "${STOP_SCRIPT}"
success "Created: ${STOP_SCRIPT}"

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "${GREEN}   Installation Complete!${NC}"
echo "============================================================"
echo ""
echo "  Repository    : ${LAB_DIR}"
echo "  Virtual env   : ${LAB_DIR}/venv"
echo "  Challenges    : ${LAB_DIR}/example_challenges/"
echo ""
echo "  Helper scripts:"
echo "    Start  → ${START_SCRIPT}"
echo "    Stop   → ${STOP_SCRIPT}"
echo ""
echo "  ─── Next steps ───────────────────────────────────────────"
echo ""
echo "  1. Export your API key (if using OpenAI):"
echo "       export OPENAI_API_KEY=your_key"
echo "       # or save to:  ~/.secrets/OPENAI_API_KEY.txt"
echo ""
echo "  2. Start Folly:"
echo ""
echo "       # OpenAI (default)"
echo "       ${START_SCRIPT}"
echo ""
echo "       # Groq"
echo "       FOLLY_PROVIDER=groq ${START_SCRIPT}"
echo ""
echo "       # Ollama (local, no API key needed)"
echo "       FOLLY_PROVIDER=ollama ${START_SCRIPT}"
echo "       FOLLY_PROVIDER=ollama FOLLY_MODEL=llama3.2 ${START_SCRIPT}"
echo ""
echo "       # Advanced challenges"
echo "       ${START_SCRIPT} advanced"
echo "       FOLLY_PROVIDER=ollama ${START_SCRIPT} advanced"
echo ""
echo "  3. Open in browser:"
echo "       http://localhost:${UI_PORT}"
echo ""
echo "  4. Or use the CLI:"
echo "       source ${LAB_DIR}/venv/bin/activate"
echo "       folly-cli http://localhost:${API_PORT}"
echo ""
echo "  ─── Providers & Models ───────────────────────────────────"
echo "    openai  → https://api.openai.com/v1      (gpt-4, gpt-4o)"
echo "    groq    → https://api.groq.com/openai/v1 (llama-3.3-70b-versatile)"
echo "    ollama  → http://localhost:11434/v1       (${OLLAMA_DEFAULT_MODEL}, llama3.2, ...)"
echo ""
echo "  ─── Challenge files ──────────────────────────────────────"
echo "    Basic    → example_challenges/prompt_injection_masterclass.json"
echo "    Advanced → example_challenges/advanced_injection_challenges.json"
echo ""
