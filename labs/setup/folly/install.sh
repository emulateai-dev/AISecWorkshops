#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Folly — Install (clone + uv tool install)
# Run as normal user: ./install.sh
# ============================================================

FOLLY_REPO="https://github.com/detoxio-ai/Folly.git"
LABS_DIR="${LABS_DIR:-$HOME/labs}"
FOLLY_DIR="$LABS_DIR/Folly"

echo "=== Folly Install ==="

# --- Pre-flight checks ---
command -v git >/dev/null 2>&1 || { echo "❌ git not found. Install git first."; exit 1; }
command -v uv  >/dev/null 2>&1 || { echo "❌ uv not found. Install uv first: curl -LsSf https://astral.sh/uv/install.sh | sh"; exit 1; }

# --- Clone ---
mkdir -p "$LABS_DIR"
if [ -d "$FOLLY_DIR" ]; then
  echo "📁 Folly already cloned at $FOLLY_DIR — pulling latest..."
  cd "$FOLLY_DIR"
  git pull --ff-only || echo "⚠️  git pull failed (you may have local changes); continuing with existing code."
else
  echo "📥 Cloning Folly..."
  git clone "$FOLLY_REPO" "$FOLLY_DIR"
  cd "$FOLLY_DIR"
fi

# --- Install as uv tool ---
echo "📦 Installing Folly via uv (editable mode)..."
uv tool install --editable . --force

# --- Verify ---
echo ""
echo "🔍 Verifying installation..."
PASS=true
for cmd in folly-api folly-ui folly-cli; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  ✅ $cmd"
  else
    echo "  ❌ $cmd not found — check that ~/.local/bin is in your PATH"
    PASS=false
  fi
done

if $PASS; then
  echo ""
  echo "✅ Folly installed successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Set your API key:  export OPENAI_API_KEY=\$(cat ~/.secrets/OPENAI_API_KEY.txt)"
  echo "  2. Start Folly:       ./start.sh"
else
  echo ""
  echo "⚠️  Some commands were not found. Try: source ~/.local/bin/env"
  exit 1
fi
