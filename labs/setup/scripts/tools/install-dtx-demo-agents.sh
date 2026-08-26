#!/bin/bash
# install-dtx-demo-agents.sh — sets up the DTX Demo Agents sandbox
# (labs/agents/red-teaming/dtx-demo-agents). This stack is vendored directly
# in AISecWorkshops — it no longer clones detoxio-ai/ai-red-teaming-training
# (the old, retired-as-a-dependency curriculum repo) just to get this one
# compose stack out of it.

# Exit on any error
set -e

# Paths — APP_DIR assumes AISecWorkshops is cloned at $HOME/labs/AISecWorkshops
# (see labs/setup/vm/Tool_Setup.sh §5); override via env if yours lives elsewhere.
APP_DIR="${APP_DIR:-$HOME/labs/AISecWorkshops/labs/agents/red-teaming/dtx-demo-agents}"
SECRETS_DIR="$HOME/.secrets"

# API key files
OPENAI_FILE="$SECRETS_DIR/OPENAI_API_KEY.txt"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ ERROR: $APP_DIR not found. Make sure AISecWorkshops is cloned at \$HOME/labs/AISecWorkshops, or set APP_DIR to its actual location."
  exit 1
fi

cd "$APP_DIR"

# Ensure .env.template exists
if [ ! -f ".env.template" ]; then
  echo "❌ ERROR: .env.template not found in $APP_DIR"
  exit 1
fi

# Copy .env.template to .env (only if .env doesn't already exist, so repeated
# runs don't clobber values you've customized)
if [ ! -f ".env" ]; then
  echo "📝 Creating .env from template..."
  cp .env.template .env
else
  echo "ℹ️  .env already exists — leaving it as-is."
fi

# Helper function to update env vars
update_env_var() {
  VAR_NAME="$1"
  VAR_VALUE="$2"
  if grep -q "^${VAR_NAME}=" .env; then
    sed -i.bak "s|^${VAR_NAME}=.*|${VAR_NAME}=${VAR_VALUE}|" .env
  else
    echo "${VAR_NAME}=${VAR_VALUE}" >> .env
  fi
}

# Inject secrets
echo "🔐 Injecting API keys into .env..."
if [ -f "$OPENAI_FILE" ]; then
  update_env_var "OPENAI_API_KEY" "$(cat "$OPENAI_FILE")"
else
  echo "⚠️  $OPENAI_FILE not found — OPENAI_API_KEY in .env is still the placeholder. Edit .env manually before using the demo/RAG/tool-agent apps."
fi

# Start and stop containers to pull images
echo "🐳 Starting Docker containers to preload images..."
docker compose up -d

echo "🛑 Shutting down containers (images cached)..."
docker compose down

echo "✅ Setup complete. Images are now preloaded and environment is ready."
echo "   Start it again with: cd $APP_DIR && docker compose up -d"
