#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
REPO_URL="https://github.com/ghostsecurity/reaper.git"
CLONE_DIR="${1:-$HOME/labs/reaper}"
OPENAI_KEY_FILE="$HOME/.secrets/OPENAI_API_KEY.txt"

# --- Ports (customize if needed) ---
PORT=18000
PROXY_PORT=28080

# --- Resolve OpenAI Key ---
OPENAI_API_KEY=""
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  : # already set in environment
elif [[ -f "$OPENAI_KEY_FILE" ]]; then
  OPENAI_API_KEY=$(< "$OPENAI_KEY_FILE")
else
  echo "⚠️  WARNING: OpenAI API key not found at $OPENAI_KEY_FILE"
  echo "    Installation will continue. Set your key before starting:"
  echo "    mkdir -p ~/.secrets && echo 'your_key' > $OPENAI_KEY_FILE"
fi

# --- Clone the repo if needed ---
if [[ ! -d "$CLONE_DIR" ]]; then
  echo "📥 Cloning Reaper repo into $CLONE_DIR..."
  git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
fi

cd "$CLONE_DIR"

# --- Generate .env file ---
echo "📝 Writing .env file..."
cat > .env <<EOF
COMPOSE_PROJECT_NAME=reaper
ENV=development
HOST=0.0.0.0
PORT=8000
PROXY_PORT=8080
OPENAI_API_KEY=${OPENAI_API_KEY}
EOF

# --- Generate docker-compose.yml file ---
echo "📄 Writing docker-compose.yml with correct port mappings..."
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  reaper:
    build:
      context: .
      dockerfile: Dockerfile
    env_file: .env
    environment:
      - ENV=docker
      - HOST=0.0.0.0
      - OPENAI_API_KEY=\${OPENAI_API_KEY}
    ports:
      - ${PORT}:8000
      - ${PROXY_PORT}:8080
EOF

# --- Generate start_service.sh ---
START_SCRIPT="${CLONE_DIR}/start_service.sh"
cat > "${START_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "🚀 Starting Reaper..."
docker compose up -d
echo "✅ Reaper is running!"
echo "→ Main UI:    http://localhost:18000"
echo "→ Proxy Port: http://localhost:28080"
EOF
chmod +x "${START_SCRIPT}"

# --- Generate stop_service.sh ---
STOP_SCRIPT="${CLONE_DIR}/stop_service.sh"
cat > "${STOP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "🛑 Stopping Reaper..."
docker compose down
echo "✅ Reaper stopped."
EOF
chmod +x "${STOP_SCRIPT}"

# --- Preload Docker images ---
echo "📦 Preloading Docker images (build + stop)..."
cd "${CLONE_DIR}"
docker compose up -d --build
docker compose stop

# --- Done ---
echo ""
echo "============================================================"
echo "   Reaper – Installation Complete!"
echo "============================================================"
echo ""
echo "  Repository : ${CLONE_DIR}"
echo "  Config     : ${CLONE_DIR}/.env"
echo ""
echo "  Helper scripts:"
echo "    Start → $(realpath "${START_SCRIPT}")"
echo "    Stop  → $(realpath "${STOP_SCRIPT}")"
echo ""
echo "  ─── Next steps ────────────────────────────────────────"
echo "  1. Edit your API key (if not already set):"
echo "       nano ${CLONE_DIR}/.env"
echo ""
echo "  2. Start:"
echo "       $(realpath "${START_SCRIPT}")"
echo ""
echo "  3. Access:"
echo "       Main UI:    http://localhost:18000"
echo "       Proxy Port: http://localhost:28080"
echo ""
