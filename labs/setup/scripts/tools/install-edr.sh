#!/usr/bin/env bash
# ============================================================
#  install-edr.sh
#  Installer for Salesforce Enterprise Deep Research (EDR)
#
#  Installs:
#    • enterprise-deep-research repo (SalesforceAIResearch)
#    • Python 3.10+ virtualenv + pip dependencies
#    • Node.js frontend (ai-research-assistant)
#    • Generates .env from .env.sample (keys left blank for user)
#    • Creates start_service.sh / stop_service.sh helper scripts
#
#  Supports: Ubuntu / Debian-based Linux (tested on 22.04+)
#  Usage:    bash install-edr.sh
#
#  Override via environment variables before running:
#    BASE_DIR=/custom/path bash install-edr.sh
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
echo "   Enterprise Deep Research (EDR) – Installer"
echo "   Source: SalesforceAIResearch/enterprise-deep-research"
echo "============================================================"
echo ""

# ── Configuration (override via env vars) ─────────────────────
BASE_DIR="${BASE_DIR:-$HOME/labs/agents/red-teaming/edr}"
REPO_URL="${REPO_URL:-https://github.com/SalesforceAIResearch/enterprise-deep-research.git}"
CLONE_DIR="${CLONE_DIR:-enterprise-deep-research}"
PYTHON_MIN_MINOR=10
API_PORT="${API_PORT:-8000}"
FRONTEND_DIR="ai-research-assistant"

LAB_DIR="${BASE_DIR}/${CLONE_DIR}"

echo "  BASE_DIR  = ${BASE_DIR}"
echo "  REPO_URL  = ${REPO_URL}"
echo "  CLONE_DIR = ${CLONE_DIR}"
echo "  API_PORT  = ${API_PORT}"
echo ""

# ── 1. Preflight checks ───────────────────────────────────────
info "Running preflight checks..."

need() {
  command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed. Please install it first."
}

need git
need python3
need pip3
need node
need npm

# Validate Python version >= 3.10
PY_MAJ=$(python3 -c 'import sys; print(sys.version_info.major)')
PY_MIN=$(python3 -c 'import sys; print(sys.version_info.minor)')
if [[ "${PY_MAJ}" -lt 3 || ( "${PY_MAJ}" -eq 3 && "${PY_MIN}" -lt "${PYTHON_MIN_MINOR}" ) ]]; then
  error "Python 3.${PYTHON_MIN_MINOR}+ is required. Found: ${PY_MAJ}.${PY_MIN}."
fi
success "Python ${PY_MAJ}.${PY_MIN} found."

# Node.js version info (informational)
NODE_VER=$(node --version 2>/dev/null || echo "unknown")
NPM_VER=$(npm --version 2>/dev/null || echo "unknown")
success "Node.js ${NODE_VER} / npm ${NPM_VER} found."

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

# ── 5. Install Python dependencies ───────────────────────────
info "Installing Python dependencies from requirements.txt ..."
if [[ -f "${LAB_DIR}/requirements.txt" ]]; then
  # ── Python 3.12+ compatibility patch ─────────────────────────────────────
  # pandas==2.2.1, matplotlib==3.8.3, seaborn==0.13.2, scikit-learn==1.6.1
  # are pinned to exact versions that have no pre-built wheels for Python
  # 3.12/3.13 and fail to compile from source on those interpreters.
  # We relax those exact == pins to >= so pip resolves a compatible wheel.
  REQS_FILE="${LAB_DIR}/requirements.txt"
  if [[ "${PY_MIN}" -ge 12 ]]; then
    warn "Python 3.${PY_MIN} detected – relaxing hard-pinned packages that lack 3.12+ wheels."
    REQS_FILE="$(mktemp /tmp/edr-requirements-XXXXXX.txt)"
    sed \
      -e 's/^pandas==\(.*\)/pandas>=\1/' \
      -e 's/^matplotlib==\(.*\)/matplotlib>=\1/' \
      -e 's/^seaborn==\(.*\)/seaborn>=\1/' \
      -e 's/^scikit-learn==\(.*\)/scikit-learn>=\1/' \
      -e 's/^numpy<\(.*\)/numpy>=1.26.0,<\1/' \
      "${LAB_DIR}/requirements.txt" > "${REQS_FILE}"
    info "Patched requirements written to: ${REQS_FILE}"
  fi

  "${LAB_DIR}/venv/bin/pip" install -r "${REQS_FILE}"

  # Remove the temp file if we created one
  if [[ "${REQS_FILE}" != "${LAB_DIR}/requirements.txt" ]]; then
    rm -f "${REQS_FILE}"
  fi
  success "Python dependencies installed."
else
  warn "requirements.txt not found – skipping Python dep install."
fi

# ── 5b. Pin langchain-mcp-adapters to 0.1.x (compatible with langchain-core 0.3.x) ──
# langchain-mcp-adapters 0.2.x requires langchain-core>=1.0.0 which does NOT
# exist yet on PyPI — causing "No module named 'langchain_core.messages.content'"
# (that module was never added to 0.3.x; it's a 1.0-era API).
# Pinning to <0.2.0 keeps the 0.1.14 release which works cleanly with 0.3.x.
info "Pinning langchain-mcp-adapters to 0.1.x for langchain-core 0.3.x compatibility ..."
"${LAB_DIR}/venv/bin/pip" install \
  "langchain-core>=0.3.78,<1.0.0" \
  "langchain>=0.3.9,<1.0.0" \
  "langchain-mcp-adapters>=0.0.6,<0.2.0"
success "langchain ecosystem pinned to compatible versions."

# Ensure uvicorn[standard] is present even if missing from requirements
"${LAB_DIR}/venv/bin/pip" install --quiet "uvicorn[standard]" >/dev/null
success "uvicorn[standard] confirmed."

# ── Secret Discovery ─────────────────────────────────────────
get_secret() {
  local key_name="$1"
  local secret_file="$HOME/.secrets/${key_name}.txt"
  if [[ -f "${secret_file}" ]]; then
    # Read first line and trim
    head -n 1 "${secret_file}" | xargs 2>/dev/null || true
  fi
}

info "Checking for existing API keys in ~/.secrets/ ..."
DISCOVERED_OPENAI=$(get_secret "OPENAI_API_KEY")
DISCOVERED_ANTHROPIC=$(get_secret "ANTHROPIC_API_KEY")
DISCOVERED_GROQ=$(get_secret "GROQ_API_KEY")
DISCOVERED_XAI=$(get_secret "XAI_API_KEY")
[[ -z "${DISCOVERED_XAI}" ]] && DISCOVERED_XAI=$(get_secret "GROK_API_KEY")
DISCOVERED_TAVILY=$(get_secret "TAVILY_API_KEY")
DISCOVERED_E2B=$(get_secret "E2B_API_KEY")

# ── 6. Configure .env ─────────────────────────────────────────
info "Configuring environment file (.env) ..."

update_env_key() {
  local key="$1"
  local val="$2"
  [[ -z "${val}" ]] && return
  if grep -q "^${key}=" "${LAB_DIR}/.env"; then
    # Use | as delimiter in case the value contains /
    sed -i "s|^${key}=.*|${key}=${val}|" "${LAB_DIR}/.env"
  else
    echo "${key}=${val}" >> "${LAB_DIR}/.env"
  fi
}

if [[ -f "${LAB_DIR}/.env" ]]; then
  warn ".env already exists – skipping creation. Edit it manually if needed."
else
  if [[ -f "${LAB_DIR}/.env.sample" ]]; then
    cp "${LAB_DIR}/.env.sample" "${LAB_DIR}/.env"
    sed -i 's/\r//' "${LAB_DIR}/.env"
    
    # Inject discovered keys
    update_env_key "OPENAI_API_KEY"   "${DISCOVERED_OPENAI}"
    update_env_key "ANTHROPIC_API_KEY" "${DISCOVERED_ANTHROPIC}"
    update_env_key "GROQ_API_KEY"      "${DISCOVERED_GROQ}"
    update_env_key "XAI_API_KEY"       "${DISCOVERED_XAI}"
    update_env_key "TAVILY_API_KEY"    "${DISCOVERED_TAVILY}"
    update_env_key "E2B_API_KEY"       "${DISCOVERED_E2B}"

    success ".env created from .env.sample and updated with discovered keys."
    echo ""
    warn "┌──────────────────────────────────────────────────────────────┐"
    warn "│  ACTION REQUIRED: Edit ${LAB_DIR}/.env  │"
    warn "│  Fill in your API keys before starting EDR:                  │"
    warn "│    OPENAI_API_KEY  / ANTHROPIC_API_KEY / GROQ_API_KEY        │"
    warn "│    TAVILY_API_KEY  / E2B_API_KEY / LLM_PROVIDER / LLM_MODEL  │"
    warn "└──────────────────────────────────────────────────────────────┘"
    echo ""
  else
    cat > "${LAB_DIR}/.env" <<EOF
# ── LLM Provider (choose one) ──────────────────────────────────
# LLM_PROVIDER=openai
# LLM_MODEL=gpt-4o
#
# LLM_PROVIDER=anthropic
# LLM_MODEL=claude-3-7-sonnet
#
# LLM_PROVIDER=groq
# LLM_MODEL=deepseek-r1-distill-llama-70b

LLM_PROVIDER=openai
LLM_MODEL=gpt-4o

# ── API Keys ────────────────────────────────────────────────────
OPENAI_API_KEY="${DISCOVERED_OPENAI}"
ANTHROPIC_API_KEY="${DISCOVERED_ANTHROPIC}"
GROQ_API_KEY="${DISCOVERED_GROQ}"
XAI_API_KEY="${DISCOVERED_XAI}"
TAVILY_API_KEY="${DISCOVERED_TAVILY}"
E2B_API_KEY="${DISCOVERED_E2B}"
JINA_API_KEY="$(get_secret "JINA_API_KEY")"
FIRECRAWL_API_KEY="$(get_secret "FIRECRAWL_API_KEY")"
LANGCHAIN_API_KEY="$(get_secret "LANGCHAIN_API_KEY")"
GOOGLE_CLOUD_PROJECT="$(get_secret "GOOGLE_CLOUD_PROJECT")"
SAMBNOVA_API_KEY="$(get_secret "SAMBNOVA_API_KEY")"
SCRAPYBARA_API_KEY="$(get_secret "SCRAPYBARA_API_KEY")"

# ── Research config ─────────────────────────────────────────────
SEARCH_API=tavily
MAX_WEB_RESEARCH_LOOPS=3
FETCH_FULL_PAGE=True

# ── Activity generation ─────────────────────────────────────────
ENABLE_ACTIVITY_GENERATION=true
ACTIVITY_VERBOSITY=medium
EOF
    success "Minimal .env template created."
  fi
fi

# ── 7. Frontend – install npm deps & build ────────────────────
info "Setting up frontend: ${FRONTEND_DIR} ..."
if [[ -d "${LAB_DIR}/${FRONTEND_DIR}" ]]; then
  pushd "${LAB_DIR}/${FRONTEND_DIR}" >/dev/null

  info "Running npm install ..."
  npm install

  info "Building frontend (npm run build) ..."
  npm run build

  popd >/dev/null
  success "Frontend built successfully."
else
  warn "Frontend directory '${FRONTEND_DIR}' not found – skipping npm steps."
  warn "This may mean the repo layout has changed. Check: ${LAB_DIR}"
fi

# ── 8. Generate start_service.sh helper ──────────────────────────────
START_SCRIPT="${BASE_DIR}/start_service.sh"
info "Generating start script: ${START_SCRIPT}"
cat > "${START_SCRIPT}" <<EOF
#!/usr/bin/env bash
# start_service.sh – Start Enterprise Deep Research (EDR) API server
set -euo pipefail

LAB_DIR="${LAB_DIR}"
API_PORT="\${API_PORT:-${API_PORT}}"

echo "🚀 Starting EDR API server on port \${API_PORT} ..."

# Load .env if present
if [[ -f "\${LAB_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source <(sed 's/\r$//' "\${LAB_DIR}/.env")
  set +a
fi

cd "\${LAB_DIR}"
# shellcheck disable=SC1091
source "\${LAB_DIR}/venv/bin/activate"

exec "\${LAB_DIR}/venv/bin/uvicorn" app:app \\
  --host 0.0.0.0 \\
  --port "\${API_PORT}" \\
  --reload
EOF
chmod +x "${START_SCRIPT}"
success "Created: ${START_SCRIPT}"

# ── 9. Generate stop_service.sh helper ───────────────────────────────
STOP_SCRIPT="${BASE_DIR}/stop_service.sh"
info "Generating stop script: ${STOP_SCRIPT}"
cat > "${STOP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
# stop_service.sh – Stop EDR API server
set -euo pipefail

echo "🛑 Stopping EDR (uvicorn) process..."

PIDS=$(pgrep -f "uvicorn app:app" 2>/dev/null || true)
if [[ -n "${PIDS}" ]]; then
  echo "${PIDS}" | xargs kill -TERM
  echo "✅ Sent SIGTERM to PIDs: ${PIDS}"
else
  echo "⚠️  No running uvicorn app:app process found."
fi
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
echo "  Frontend      : ${LAB_DIR}/${FRONTEND_DIR}"
echo "  Config        : ${LAB_DIR}/.env"
echo ""
echo "  Helper scripts:"
echo "    Start  → ${START_SCRIPT}"
echo "    Stop   → ${STOP_SCRIPT}"
echo ""
echo "  ─── Next steps ───────────────────────────────────────────"
echo ""
echo "  1. Edit your API keys:"
echo "       nano ${LAB_DIR}/.env"
echo ""
echo "  2. Start the EDR API server:"
echo "       ${START_SCRIPT}"
echo ""
echo "       Or manually:"
echo "       source ${LAB_DIR}/venv/bin/activate"
echo "       cd ${LAB_DIR}"
echo "       uvicorn app:app --host 0.0.0.0 --port ${API_PORT}"
echo ""
echo "  3. Access the app:"
echo "       API:      http://localhost:${API_PORT}"
echo "       API docs: http://localhost:${API_PORT}/docs"
echo ""
echo "  ─── Key environment variables in .env ────────────────────"
echo "    LLM_PROVIDER   – google / openai / anthropic / groq / sambnova"
echo "    LLM_MODEL      – Model name for the chosen provider"
echo "    OPENAI_API_KEY – Required if using OpenAI"
echo "    GROQ_API_KEY   – Required if using Groq"
echo "    TAVILY_API_KEY – Required for web search (tavily)"
echo "    E2B_API_KEY    – Required for code interpreter sandbox"
echo ""
