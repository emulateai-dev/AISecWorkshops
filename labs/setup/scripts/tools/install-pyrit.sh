#!/usr/bin/env bash
# ============================================================
#  install-pyrit.sh
#  Installer for Microsoft PyRIT (Python Risk Identification Toolkit)
#
#  Installs:
#    • jitendra-eai/PyRIT repo
#    • Builds pyrit-devcontainer Docker image
#    • Creates ~/.pyrit/ with .env / .env.local (auto-populated from ~/.secrets/)
#    • Generates start_service.sh / stop_service.sh helper scripts
#
#  Ports:
#    • PyRIT GUI      → http://localhost:8000
#    • Jupyter Notebooks → http://localhost:8888
#
#  Supports: Ubuntu / Debian-based Linux (tested on 22.04+)
#  Usage:    bash install-pyrit.sh
#
#  Override via environment variables before running:
#    BASE_DIR=/custom/path bash install-pyrit.sh
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
echo "   PyRIT – Python Risk Identification Toolkit  Installer"
echo "   Source: jitendra-eai/PyRIT"
echo "============================================================"
echo ""

# ── Configuration (override via env vars) ─────────────────────
BASE_DIR="${BASE_DIR:-$HOME/labs/pyrit}"
REPO_URL="${REPO_URL:-https://github.com/jitendra-eai/PyRIT.git}"
CLONE_DIR="${CLONE_DIR:-PyRIT}"
PYRIT_CONFIG_DIR="$HOME/.pyrit"

LAB_DIR="${BASE_DIR}/${CLONE_DIR}"

echo "  BASE_DIR  = ${BASE_DIR}"
echo "  REPO_URL  = ${REPO_URL}"
echo "  CLONE_DIR = ${CLONE_DIR}"
echo ""

# ── 1. Preflight checks ───────────────────────────────────────
info "Running preflight checks..."

need() {
  command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed. Please install it first."
}

need git
need docker

docker info >/dev/null 2>&1 || error "Docker daemon is not running. Start it with: sudo systemctl start docker"

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

# ── 4. Build devcontainer Docker image ───────────────────────
info "Checking Docker image 'pyrit-devcontainer' ..."
if docker image inspect pyrit-devcontainer >/dev/null 2>&1; then
  success "Docker image 'pyrit-devcontainer' already exists — skipping build."
else
  info "Building Docker image 'pyrit-devcontainer' (this may take several minutes)..."
  docker build \
    -f "${LAB_DIR}/.devcontainer/Dockerfile" \
    -t pyrit-devcontainer \
    "${LAB_DIR}/.devcontainer"
  success "Docker image 'pyrit-devcontainer' built."
fi

# ── 5. Create ~/.pyrit/ config directory ─────────────────────
info "Setting up PyRIT config directory: ${PYRIT_CONFIG_DIR}"
mkdir -p "${PYRIT_CONFIG_DIR}"
touch "${PYRIT_CONFIG_DIR}/.env" "${PYRIT_CONFIG_DIR}/.env.local"
success "Config directory ready: ${PYRIT_CONFIG_DIR}"

# ── 6. Auto-populate .env from ~/.secrets/ ───────────────────
info "Checking for API keys in ~/.secrets/ ..."

get_secret() {
  local file="$HOME/.secrets/${1}.txt"
  [[ -f "${file}" ]] && head -n 1 "${file}" | xargs 2>/dev/null || true
}

OPENAI_KEY="$(get_secret OPENAI_API_KEY)"
GROQ_KEY="$(get_secret GROQ_API_KEY)"

ENV_FILE="${PYRIT_CONFIG_DIR}/.env"

# Only write if file is empty (don't overwrite user's existing config)
if [[ ! -s "${ENV_FILE}" ]]; then
  if [[ -n "${OPENAI_KEY}" ]]; then
    cat > "${ENV_FILE}" <<EOF
OPENAI_API_KEY="${OPENAI_KEY}"
EOF
    success "OPENAI_API_KEY written to ${ENV_FILE}"
  elif [[ -n "${GROQ_KEY}" ]]; then
    cat > "${ENV_FILE}" <<EOF
PLATFORM_OPENAI_CHAT_ENDPOINT="https://api.groq.com/openai/v1"
PLATFORM_OPENAI_CHAT_API_KEY="${GROQ_KEY}"
PLATFORM_OPENAI_CHAT_GPT4O_MODEL="openai/gpt-oss-120b"
EOF
    cat > "${PYRIT_CONFIG_DIR}/.env.local" <<'EOF'
OPENAI_CHAT_ENDPOINT=${PLATFORM_OPENAI_CHAT_ENDPOINT}
OPENAI_CHAT_KEY=${PLATFORM_OPENAI_CHAT_API_KEY}
OPENAI_CHAT_MODEL="openai/gpt-oss-120b"
EOF
    success "Groq configuration written to ${ENV_FILE} and ${PYRIT_CONFIG_DIR}/.env.local"
  else
    warn "No API keys found in ~/.secrets/ — ${ENV_FILE} is empty."
    warn "Edit ${ENV_FILE} and add your key before starting:"
    warn "  OpenAI:  OPENAI_API_KEY=\"sk-...\""
    warn "  Groq:    PLATFORM_OPENAI_CHAT_API_KEY=\"gsk_...\""
  fi
else
  warn "${ENV_FILE} already has content — skipping auto-populate."
fi

# ── 7. Generate start_service.sh ─────────────────────────────
START_SCRIPT="${BASE_DIR}/start_service.sh"
info "Generating start script: ${START_SCRIPT}"
cat > "${START_SCRIPT}" <<EOF
#!/usr/bin/env bash
# start_service.sh – Start PyRIT (GUI + Jupyter) via Docker Compose
set -euo pipefail

LAB_DIR="${LAB_DIR}"

echo "🚀 Starting PyRIT (GUI + Jupyter)..."
cd "\${LAB_DIR}"

docker compose -f docker/docker-compose.yaml --profile jupyter --profile gui up -d

echo ""
echo "✅ PyRIT is running!"
echo "   PyRIT GUI:          http://localhost:8000"
echo "   Jupyter Notebooks:  http://localhost:8888"
echo ""
echo "   Stop with: ${BASE_DIR}/stop_service.sh"
echo ""
EOF
chmod +x "${START_SCRIPT}"
success "Created: ${START_SCRIPT}"

# ── 8. Generate stop_service.sh ──────────────────────────────
STOP_SCRIPT="${BASE_DIR}/stop_service.sh"
info "Generating stop script: ${STOP_SCRIPT}"
cat > "${STOP_SCRIPT}" <<EOF
#!/usr/bin/env bash
# stop_service.sh – Stop PyRIT Docker containers
set -euo pipefail

LAB_DIR="${LAB_DIR}"

echo "🛑 Stopping PyRIT..."
cd "\${LAB_DIR}"
docker compose -f docker/docker-compose.yaml down
echo "✅ PyRIT stopped."
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
echo "  Config dir    : ${PYRIT_CONFIG_DIR}"
echo "  Docker image  : pyrit-devcontainer"
echo ""
echo "  Helper scripts:"
echo "    Start → ${START_SCRIPT}"
echo "    Stop  → ${STOP_SCRIPT}"
echo ""
echo "  ─── Next steps ───────────────────────────────────────────"
echo ""
echo "  1. Verify your API key is set:"
echo "       cat ${PYRIT_CONFIG_DIR}/.env"
echo "       # Add key if missing:"
echo "       # echo 'OPENAI_API_KEY=\"sk-...\"' >> ${PYRIT_CONFIG_DIR}/.env"
echo ""
echo "  2. Start PyRIT:"
echo "       ${START_SCRIPT}"
echo ""
echo "  3. Access in browser:"
echo "       PyRIT GUI:         http://localhost:8000"
echo "       Jupyter Notebooks: http://localhost:8888"
echo ""
echo "  4. Stop:"
echo "       ${STOP_SCRIPT}"
echo ""
echo "  ─── API Key options ──────────────────────────────────────"
echo "    OpenAI: add to ${PYRIT_CONFIG_DIR}/.env:"
echo "      OPENAI_API_KEY=\"sk-proj-...\""
echo ""
echo "    Groq:   add to ${PYRIT_CONFIG_DIR}/.env:"
echo "      PLATFORM_OPENAI_CHAT_ENDPOINT=\"https://api.groq.com/openai/v1\""
echo "      PLATFORM_OPENAI_CHAT_API_KEY=\"gsk_...\""
echo "      PLATFORM_OPENAI_CHAT_GPT4O_MODEL=\"openai/gpt-oss-120b\""
echo "    And to ${PYRIT_CONFIG_DIR}/.env.local:"
echo "      OPENAI_CHAT_ENDPOINT=\${PLATFORM_OPENAI_CHAT_ENDPOINT}"
echo "      OPENAI_CHAT_KEY=\${PLATFORM_OPENAI_CHAT_API_KEY}"
echo "      OPENAI_CHAT_MODEL=\"openai/gpt-oss-120b\""
echo ""
