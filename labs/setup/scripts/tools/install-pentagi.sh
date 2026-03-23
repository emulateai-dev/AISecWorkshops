#!/bin/bash

# Exit immediately if any command fails
set -e

# Define paths
LABS_DIR="$HOME/labs"
REPO_URL="https://github.com/vxcontrol/pentagi.git"
REPO_DIR="$LABS_DIR/pentagi"
SECRETS_DIR="$HOME/.secrets"
OPENAI_FILE="$SECRETS_DIR/OPENAI_API_KEY.txt"
ENV_TEMPLATE=".env.example"
ENV_FILE=".env"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Create labs directory
mkdir -p "$LABS_DIR"
cd "$LABS_DIR"

# Clone Pentagi repo if not already present
if [ ! -d "$REPO_DIR" ]; then
  echo "Cloning Pentagi repository..."
  git clone "$REPO_URL"
else
  echo "Repository already exists at $REPO_DIR"
fi

cd "$REPO_DIR"

# Ensure .env.template exists
if [ ! -f "$ENV_TEMPLATE" ]; then
  echo "❌ ERROR: $ENV_TEMPLATE not found in $REPO_DIR"
  exit 1
fi

# Copy .env.template to .env
echo "Copying $ENV_TEMPLATE to $ENV_FILE..."
cp "$ENV_TEMPLATE" "$ENV_FILE"

# Inject OpenAI API key
if [ -f "$OPENAI_FILE" ]; then
  OPENAI_KEY=$(cat "$OPENAI_FILE")
  if [ -n "$OPENAI_KEY" ]; then
    if grep -q "^OPEN_AI_KEY=" "$ENV_FILE"; then
      sed -i.bak "s|^OPEN_AI_KEY=.*|OPEN_AI_KEY=${OPENAI_KEY}|" "$ENV_FILE"
    else
      echo "OPEN_AI_KEY=${OPENAI_KEY}" >> "$ENV_FILE"
    fi
    echo "✅ OpenAI key inserted into $ENV_FILE"
  else
    echo "⚠️  WARNING: $OPENAI_FILE is empty. You will need to set the key manually."
    echo "    Edit: $REPO_DIR/$ENV_FILE  →  OPEN_AI_KEY=your_key_here"
  fi
else
  echo "⚠️  WARNING: OpenAI key file not found at $OPENAI_FILE"
  echo "    Installation will continue. Set the key before starting:"
  echo "    mkdir -p ~/.secrets && echo 'your_key' > $OPENAI_FILE"
  echo "    Then re-run this script, or edit: $REPO_DIR/$ENV_FILE"
fi

# Replace 127.0.0.1 with 0.0.0.0 in docker-compose.yml
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
  sed -i.bak 's/127\.0\.0\.1/0.0.0.0/g' "$DOCKER_COMPOSE_FILE"
  echo "🔧 Replaced 127.0.0.1 with 0.0.0.0 in $DOCKER_COMPOSE_FILE"
else
  echo "⚠️ WARNING: $DOCKER_COMPOSE_FILE not found; skipping IP replacement."
fi

# --- Generate start_service.sh ---
START_SCRIPT="${REPO_DIR}/start_service.sh"
cat > "${START_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "🚀 Starting Pentagi..."
docker compose up -d
echo "✅ Pentagi is running!"
echo "→ Access: https://localhost:8443"
EOF
chmod +x "${START_SCRIPT}"

# --- Generate stop_service.sh ---
STOP_SCRIPT="${REPO_DIR}/stop_service.sh"
cat > "${STOP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "🛑 Stopping Pentagi..."
docker compose down
echo "✅ Pentagi stopped."
EOF
chmod +x "${STOP_SCRIPT}"

# Preload Docker images
echo "📦 Preloading Docker images..."
docker compose up -d
docker compose down

echo ""
echo "============================================================"
echo "   Pentagi – Installation Complete!"
echo "============================================================"
echo ""
echo "  Repository : ${REPO_DIR}"
echo "  Config     : ${REPO_DIR}/.env"
echo ""
echo "  Helper scripts:"
echo "    Start → ${START_SCRIPT}"
echo "    Stop  → ${STOP_SCRIPT}"
echo ""
echo "  ─── Next steps ────────────────────────────────────────"
echo "  1. Edit your API key (if not already set):"
echo "       nano ${REPO_DIR}/.env"
echo ""
echo "  2. Start:"
echo "       ${START_SCRIPT}"
echo ""
echo "  3. Access: https://localhost:8443"
echo ""
