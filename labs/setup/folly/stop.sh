#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Folly — Stop API + UI
# Run as normal user: ./stop.sh
# ============================================================

PID_DIR="${XDG_RUNTIME_DIR:-/tmp}/folly"

echo "=== Folly Stop ==="

STOPPED=false

# --- Stop API ---
if [ -f "$PID_DIR/api.pid" ]; then
  API_PID="$(cat "$PID_DIR/api.pid")"
  if kill -0 "$API_PID" 2>/dev/null; then
    echo "🛑 Stopping Folly API (PID $API_PID)..."
    kill "$API_PID"
    sleep 1
    # Force kill if still running
    if kill -0 "$API_PID" 2>/dev/null; then
      echo "   Sending SIGKILL..."
      kill -9 "$API_PID" 2>/dev/null || true
    fi
    echo "   ✅ API stopped"
  else
    echo "   ℹ️  API (PID $API_PID) was not running"
  fi
  rm -f "$PID_DIR/api.pid"
  STOPPED=true
fi

# --- Stop UI ---
if [ -f "$PID_DIR/ui.pid" ]; then
  UI_PID="$(cat "$PID_DIR/ui.pid")"
  if kill -0 "$UI_PID" 2>/dev/null; then
    echo "🛑 Stopping Folly UI (PID $UI_PID)..."
    kill "$UI_PID"
    sleep 1
    if kill -0 "$UI_PID" 2>/dev/null; then
      echo "   Sending SIGKILL..."
      kill -9 "$UI_PID" 2>/dev/null || true
    fi
    echo "   ✅ UI stopped"
  else
    echo "   ℹ️  UI (PID $UI_PID) was not running"
  fi
  rm -f "$PID_DIR/ui.pid"
  STOPPED=true
fi

# --- Fallback: kill by port if no PID files ---
if ! $STOPPED; then
  echo "   No PID files found. Checking for processes on ports 5000/5001..."
  for port in 5000 5001; do
    PID="$(lsof -ti :$port 2>/dev/null || true)"
    if [ -n "$PID" ]; then
      echo "   🛑 Killing process on port $port (PID $PID)..."
      kill "$PID" 2>/dev/null || true
      STOPPED=true
    fi
  done
fi

if $STOPPED; then
  echo ""
  echo "✅ Folly stopped."
else
  echo ""
  echo "ℹ️  No running Folly processes found."
fi

# --- Clean up log files ---
rm -f "$PID_DIR/api.log" "$PID_DIR/ui.log" 2>/dev/null || true
rmdir "$PID_DIR" 2>/dev/null || true
