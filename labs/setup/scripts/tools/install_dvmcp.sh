#!/usr/bin/env bash
# ============================================================
#  install_dvmcp.sh
#  Installer for Damn Vulnerable MCP Labs (DV-MCP)
#
#  Installs:
#    • dv_mcp_labs repo  (git@github.com:emulateai-dev/dv_mcp_labs.git)
#    • Ollama (local LLM runtime)
#    • Vulnerable Llama model from HuggingFace
#      (eai-sec-workshop/vulnerable_llama_model)
#    • Docker image for the MCP challenge servers
#    • Helper scripts: start_service.sh / stop_service.sh / fresh_start.sh
#
#  Supports: Ubuntu / Debian-based Linux (tested on 22.04+)
#  Usage:    bash install_dvmcp.sh
# ============================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }

echo ""
echo "============================================================"
echo "   Damn Vulnerable MCP Labs – Installer"
echo "============================================================"
echo ""

# ── Configuration (override via env vars) ─────────────────────
BASE_DIR="${BASE_DIR:-/home/dtx/labs/mcp}"
CLONE_DIR="${CLONE_DIR:-dv_mcp_labs}"
REPO_SSH="git@github.com:emulateai-dev/dv_mcp_labs.git"
REPO_HTTPS="https://github.com/emulateai-dev/dv_mcp_labs.git"

CONTAINER_NAME="${CONTAINER_NAME:-dvmcp}"
IMAGE_NAME="${IMAGE_NAME:-dvmcp}"

# Host port range that maps to challenge ports 9001-9010 inside the container
HOST_PORT_START="${HOST_PORT_START:-18567}"
HOST_PORT_END="${HOST_PORT_END:-18576}"
CONTAINER_PORT_RANGE="9001-9010"

# HuggingFace model details
HF_REPO="eai-sec-workshop/vulnerable_llama_model"
OLLAMA_MODEL_NAME="vulnerable-llama"

LAB_DIR="${BASE_DIR}/${CLONE_DIR}"

# ── 1. Preflight checks ───────────────────────────────────────
info "Running preflight checks..."

need() {
  command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed. Please install it first."
}

need git
need docker

# Check Docker daemon is running
docker info >/dev/null 2>&1 || error "Docker daemon is not running. Start it with: sudo systemctl start docker"

success "Preflight checks passed."

# ── 2. Create base directory ──────────────────────────────────
info "Checking base directory: ${BASE_DIR}"
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"
success "Base directory ready: ${BASE_DIR}"

# ── 3. Clone the dv_mcp_labs repository ──────────────────────
info "Checking repository: ${CLONE_DIR}"
if [ -d "${LAB_DIR}/.git" ]; then
  info "Repository already exists. Pulling latest changes..."
  git -C "${LAB_DIR}" pull --ff-only || warn "Could not pull latest – continuing with existing version."
  success "Repository up-to-date: ${LAB_DIR}"
else
  info "Cloning repository..."
  # Try SSH first (preferred for contributors), fall back to HTTPS
  if git clone "${REPO_SSH}" "${CLONE_DIR}" 2>/dev/null; then
    success "Cloned via SSH: ${REPO_SSH}"
  else
    warn "SSH clone failed (no SSH key?). Falling back to HTTPS..."
    git clone "${REPO_HTTPS}" "${CLONE_DIR}"
    success "Cloned via HTTPS: ${REPO_HTTPS}"
  fi
fi

# ── 4. Install / check Ollama ─────────────────────────────────
info "Checking Ollama..."
if command -v ollama >/dev/null 2>&1; then
  success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
else
  info "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  success "Ollama installed."
fi

# ── 5. Start Ollama service ───────────────────────────────────
info "Ensuring Ollama service is running..."
if pgrep -x "ollama" >/dev/null 2>&1; then
  success "Ollama service is already running."
else
  ollama serve >/dev/null 2>&1 &
  sleep 4
  if pgrep -x "ollama" >/dev/null 2>&1; then
    success "Ollama service started."
  else
    warn "Ollama may not have started. Continuing anyway – pull will fail if it's not running."
  fi
fi

# ── 6. Pull vulnerable Llama model from HuggingFace via Ollama ─
info "Checking model '${OLLAMA_MODEL_NAME}' (from HuggingFace: ${HF_REPO})..."
if ollama list 2>/dev/null | grep -q "^${OLLAMA_MODEL_NAME}"; then
  success "Model '${OLLAMA_MODEL_NAME}' already available in Ollama."
else
  info "Pulling vulnerable Llama model from HuggingFace..."
  info "  HF repo : ${HF_REPO}"
  info "  This may take several minutes depending on your connection."

  # Ollama can pull directly from HuggingFace using the hf.co/ prefix
  if ollama pull "hf.co/${HF_REPO}"; then
    # Tag it with our preferred short name
    ollama cp "hf.co/${HF_REPO}" "${OLLAMA_MODEL_NAME}" 2>/dev/null || true
    success "Model pulled and tagged as '${OLLAMA_MODEL_NAME}'."
  else
    warn "ollama pull failed. You can retry manually:"
    warn "  ollama pull hf.co/${HF_REPO}"
    warn "  ollama cp hf.co/${HF_REPO} ${OLLAMA_MODEL_NAME}"
    warn "Continuing with the rest of the installation..."
  fi
fi

# ── 7. Python venv + dependencies (for running client locally) ──
info "Setting up Python virtual environment in ${LAB_DIR}..."
cd "${LAB_DIR}"

if command -v python3 >/dev/null 2>&1; then
  PY_MAJ=$(python3 -c 'import sys; print(sys.version_info.major)')
  PY_MIN=$(python3 -c 'import sys; print(sys.version_info.minor)')
  if [[ "${PY_MAJ}" -ge 3 && "${PY_MIN}" -ge 10 ]]; then
    success "Python ${PY_MAJ}.${PY_MIN} found."
  else
    warn "Python ${PY_MAJ}.${PY_MIN} is older than 3.10. Installing python3.10..."
    sudo apt-get update -qq
    sudo apt-get install -y python3.10 python3.10-venv python3-pip
  fi
else
  info "Python3 not found. Installing..."
  sudo apt-get update -qq
  sudo apt-get install -y python3.10 python3.10-venv python3-pip
fi

if [ ! -d "${LAB_DIR}/venv" ]; then
  python3 -m venv "${LAB_DIR}/venv"
  success "Virtual environment created."
else
  success "Virtual environment already exists."
fi

"${LAB_DIR}/venv/bin/pip" install --quiet --upgrade pip
if [ -f "${LAB_DIR}/requirements.txt" ]; then
  "${LAB_DIR}/venv/bin/pip" install --quiet -r "${LAB_DIR}/requirements.txt"
  success "Python dependencies installed."
else
  warn "requirements.txt not found – skipping Python deps install."
fi

# ── 8. Build Docker image ─────────────────────────────────────
info "Building Docker image '${IMAGE_NAME}' from ${LAB_DIR}/Dockerfile..."
cd "${LAB_DIR}"
docker build -t "${IMAGE_NAME}" .
success "Docker image '${IMAGE_NAME}' built."

# ── 9. Initialize challenge environment directories ───────────
info "Setting up challenge runtime directories..."
mkdir -p /tmp/dvmcp_challenge3/public /tmp/dvmcp_challenge3/private
mkdir -p /tmp/dvmcp_challenge4/state
mkdir -p /tmp/dvmcp_challenge6/user_uploads
mkdir -p /tmp/dvmcp_challenge8/sensitive
mkdir -p /tmp/dvmcp_challenge10/config
echo '{"weather_tool_calls": 0}' > /tmp/dvmcp_challenge4/state/state.json
echo "Welcome to the public directory!" > /tmp/dvmcp_challenge3/public/welcome.txt
echo "This is a public file." > /tmp/dvmcp_challenge3/public/public_file.txt
success "Challenge runtime directories ready."

# ── 10. Generate helper scripts ───────────────────────────────
info "Generating helper scripts in ${BASE_DIR}..."

# ── start_service.sh ──
START_SCRIPT="${BASE_DIR}/start_service.sh"
cat > "${START_SCRIPT}" <<EOL
#!/usr/bin/env bash
# start_service.sh – Start the DVMCP Docker container
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME}"
IMAGE_NAME="${IMAGE_NAME}"
HOST_PORT_START="${HOST_PORT_START}"
HOST_PORT_END="${HOST_PORT_END}"
CONTAINER_PORT_RANGE="${CONTAINER_PORT_RANGE}"

echo "🚀 Starting container: \${CONTAINER_NAME}  (host \${HOST_PORT_START}-\${HOST_PORT_END} → container \${CONTAINER_PORT_RANGE})"

if docker ps -a --format '{{.Names}}' | grep -Eq "^\${CONTAINER_NAME}\$"; then
  if docker ps --format '{{.Names}}' | grep -Eq "^\${CONTAINER_NAME}\$"; then
    echo "✅ Container \${CONTAINER_NAME} is already running."
    exit 0
  else
    echo "⚠️  Container exists but is stopped. Restarting..."
    docker start "\${CONTAINER_NAME}"
  fi
else
  docker run -d \\
    --name "\${CONTAINER_NAME}" \\
    -p \${HOST_PORT_START}-\${HOST_PORT_END}:\${CONTAINER_PORT_RANGE} \\
    "\${IMAGE_NAME}"
fi

sleep 2
if docker ps --format '{{.Names}}' | grep -Eq "^\${CONTAINER_NAME}\$"; then
  echo "✅ Container \${CONTAINER_NAME} is running."
  echo ""
  echo "  Challenge SSE endpoints:"
  for i in \$(seq 1 10); do
    PORT=\$((HOST_PORT_START + i - 1))
    printf "    Challenge %-2s →  http://localhost:%s/sse\\n" "\$i" "\$PORT"
  done
else
  echo "❌ Failed to start container \${CONTAINER_NAME}"
  exit 1
fi
EOL
chmod +x "${START_SCRIPT}"
success "Created: ${START_SCRIPT}"

# ── stop_service.sh ──
STOP_SCRIPT="${BASE_DIR}/stop_service.sh"
cat > "${STOP_SCRIPT}" <<EOL
#!/usr/bin/env bash
# stop_service.sh – Stop and remove the DVMCP Docker container
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME}"

echo "🛑 Stopping container: \${CONTAINER_NAME}"

if docker ps -a --format '{{.Names}}' | grep -Eq "^\${CONTAINER_NAME}\$"; then
  docker stop "\${CONTAINER_NAME}" || true
  docker rm "\${CONTAINER_NAME}" || true
  echo "✅ Container \${CONTAINER_NAME} stopped and removed."
else
  echo "⚠️  No container named \${CONTAINER_NAME} found."
fi
EOL
chmod +x "${STOP_SCRIPT}"
success "Created: ${STOP_SCRIPT}"

# ── fresh_start.sh ──
FRESH_SCRIPT="${BASE_DIR}/fresh_start.sh"
cat > "${FRESH_SCRIPT}" <<EOL
#!/usr/bin/env bash
# fresh_start.sh – Rebuild image from scratch and restart container
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME}"
IMAGE_NAME="${IMAGE_NAME}"
HOST_PORT_START="${HOST_PORT_START}"
HOST_PORT_END="${HOST_PORT_END}"
CONTAINER_PORT_RANGE="${CONTAINER_PORT_RANGE}"
LAB_DIR="${LAB_DIR}"

echo "🔄 Pulling latest repo changes..."
git -C "\${LAB_DIR}" pull --ff-only || echo "⚠️  Could not pull latest – rebuilding with current code."

echo "🐳 Rebuilding Docker image (no cache): \${IMAGE_NAME}"
docker build --no-cache -t "\${IMAGE_NAME}" "\${LAB_DIR}"

echo "🛑 Stopping old container (if any)..."
docker stop "\${CONTAINER_NAME}" 2>/dev/null || true
docker rm   "\${CONTAINER_NAME}" 2>/dev/null || true

echo "🚀 Starting fresh container..."
docker run -d \\
  --name "\${CONTAINER_NAME}" \\
  -p \${HOST_PORT_START}-\${HOST_PORT_END}:\${CONTAINER_PORT_RANGE} \\
  "\${IMAGE_NAME}"

sleep 2
if docker ps --format '{{.Names}}' | grep -Eq "^\${CONTAINER_NAME}\$"; then
  echo "✅ Container \${CONTAINER_NAME} is running."
  echo ""
  echo "  Challenge SSE endpoints:"
  for i in \$(seq 1 10); do
    PORT=\$((HOST_PORT_START + i - 1))
    printf "    Challenge %-2s →  http://localhost:%s/sse\\n" "\$i" "\$PORT"
  done
else
  echo "❌ Failed to start container \${CONTAINER_NAME}"
  exit 1
fi
EOL
chmod +x "${FRESH_SCRIPT}"
success "Created: ${FRESH_SCRIPT}"

# ── 11. First run: start the container ───────────────────────
info "Starting the DVMCP container for the first time..."
bash "${START_SCRIPT}"

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "${GREEN}   Installation Complete!${NC}"
echo "============================================================"
echo ""
echo "  Repository    : ${LAB_DIR}"
echo "  Docker image  : ${IMAGE_NAME}"
echo "  Container     : ${CONTAINER_NAME}"
echo ""
echo "  Ollama model  : ${OLLAMA_MODEL_NAME}  (hf.co/${HF_REPO})"
echo ""
echo "  Helper scripts:"
echo "    Start   → ${START_SCRIPT}"
echo "    Stop    → ${STOP_SCRIPT}"
echo "    Rebuild → ${FRESH_SCRIPT}"
echo ""
echo "  MCP client (local, in a new terminal):"
echo "    source ${LAB_DIR}/venv/bin/activate"
echo "    python ${LAB_DIR}/fixes/ollama_mcp_client.py"
echo ""
echo "  Challenge SSE endpoints (host ports):"
for i in $(seq 1 10); do
  PORT=$((HOST_PORT_START + i - 1))
  printf "    Challenge %-2s →  http://localhost:%s/sse\n" "$i" "$PORT"
done
echo ""
