#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Folly — Start API + UI
# Run as normal user: ./start.sh [challenge_set]
#
# Options:
#   ./start.sh                   — basic challenges (default)
#   ./start.sh basic             — basic challenges
#   ./start.sh advanced          — advanced challenges
#
# Provider selection (env vars):
#   FOLLY_PROVIDER=openai  (default)
#   FOLLY_PROVIDER=groq
#   FOLLY_MODEL=gpt-4      (override model name)
# ============================================================

LABS_DIR="${LABS_DIR:-$HOME/labs}"
FOLLY_DIR="$LABS_DIR/Folly"
PID_DIR="${XDG_RUNTIME_DIR:-/tmp}/folly"
CHALLENGE_SET="${1:-basic}"
PROVIDER="${FOLLY_PROVIDER:-openai}"

echo "=== Folly Start ==="

# --- Pre-flight ---
command -v folly-api >/dev/null 2>&1 || { echo "❌ folly-api not found. Run install.sh first."; exit 1; }
command -v folly-ui  >/dev/null 2>&1 || { echo "❌ folly-ui not found. Run install.sh first."; exit 1; }

if [ -d "$PID_DIR" ] && { [ -f "$PID_DIR/api.pid" ] || [ -f "$PID_DIR/ui.pid" ]; }; then
  echo "⚠️  Folly may already be running. Run ./stop.sh first, or check:"
  echo "    API PID: $(cat "$PID_DIR/api.pid" 2>/dev/null || echo 'none')"
  echo "    UI  PID: $(cat "$PID_DIR/ui.pid" 2>/dev/null || echo 'none')"
  exit 1
fi

# --- Resolve challenge config ---
case "$CHALLENGE_SET" in
  basic)
    CONFIG_FILE="example_challenges/prompt_injection_masterclass.json"
    ;;
  advanced|advance)
    CONFIG_FILE="example_challenges/advance_challenges.json"
    ;;
  *)
    if [ -f "$CHALLENGE_SET" ]; then
      CONFIG_FILE="$CHALLENGE_SET"
    elif [ -f "$FOLLY_DIR/$CHALLENGE_SET" ]; then
      CONFIG_FILE="$CHALLENGE_SET"
    else
      echo "❌ Unknown challenge set: $CHALLENGE_SET"
      echo "   Use: basic, advanced, or a path to a JSON config file."
      exit 1
    fi
    ;;
esac

# --- Resolve provider / API key / model ---
case "$PROVIDER" in
  openai)
    API_URL="https://api.openai.com/v1"
    MODEL="${FOLLY_MODEL:-gpt-4}"
    if [ -n "${OPENAI_API_KEY:-}" ]; then
      API_KEY="$OPENAI_API_KEY"
    elif [ -f "$HOME/.secrets/OPENAI_API_KEY.txt" ]; then
      API_KEY="$(cat "$HOME/.secrets/OPENAI_API_KEY.txt")"
    else
      echo "❌ OPENAI_API_KEY not set and ~/.secrets/OPENAI_API_KEY.txt not found."
      exit 1
    fi
    ;;
  groq)
    API_URL="https://api.groq.com/openai/v1"
    MODEL="${FOLLY_MODEL:-qwen/qwen3-32b}"
    if [ -n "${GROQ_API_KEY:-}" ]; then
      API_KEY="$GROQ_API_KEY"
    elif [ -f "$HOME/.secrets/GROQ_API_KEY.txt" ]; then
      API_KEY="$(cat "$HOME/.secrets/GROQ_API_KEY.txt")"
    else
      echo "❌ GROQ_API_KEY not set and ~/.secrets/GROQ_API_KEY.txt not found."
      exit 1
    fi
    ;;
  *)
    echo "❌ Unknown provider: $PROVIDER (use openai or groq)"
    exit 1
    ;;
esac

# --- Create PID directory ---
mkdir -p "$PID_DIR"

echo "  Provider:   $PROVIDER"
echo "  Model:      $MODEL"
echo "  Challenges: $CONFIG_FILE"
echo ""

# --- Start API (background) ---
echo "🚀 Starting Folly API on http://localhost:5000 ..."
cd "$FOLLY_DIR"
nohup folly-api "$API_URL" \
  --model "$MODEL" \
  --api-key "$API_KEY" \
  "$CONFIG_FILE" \
  > "$PID_DIR/api.log" 2>&1 &
API_PID=$!
echo "$API_PID" > "$PID_DIR/api.pid"
echo "   API PID: $API_PID (log: $PID_DIR/api.log)"

# --- Wait for API to be ready ---
echo -n "   Waiting for API..."
for i in $(seq 1 30); do
  if curl -s http://localhost:5000 >/dev/null 2>&1; then
    echo " ready!"
    break
  fi
  if ! kill -0 "$API_PID" 2>/dev/null; then
    echo " failed!"
    echo "❌ API process exited. Check logs: $PID_DIR/api.log"
    cat "$PID_DIR/api.log"
    rm -f "$PID_DIR/api.pid"
    exit 1
  fi
  sleep 1
  echo -n "."
done

# --- Start UI (background) ---
echo "🖥️  Starting Folly UI on http://localhost:5001 ..."
nohup folly-ui http://localhost:5000 \
  > "$PID_DIR/ui.log" 2>&1 &
UI_PID=$!
echo "$UI_PID" > "$PID_DIR/ui.pid"
echo "   UI  PID: $UI_PID (log: $PID_DIR/ui.log)"

echo ""
echo "✅ Folly is running!"
echo ""
echo "   API: http://localhost:5000"
echo "   UI:  http://localhost:5001"
echo ""
echo "   Stop with: ./stop.sh"
