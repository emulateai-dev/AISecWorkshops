#!/usr/bin/env bash
# =====================================================================
# The Gauntlet — rebuild
# The app code (engine/server/config/ui) is baked into the image, so after a
# `git pull` or any local change you must rebuild for it to take effect.
# Sessions in ./data (a bind mount) are preserved across rebuilds.
#
#   ./rebuild.sh            # stop, rebuild image, restart
#   ./rebuild.sh --no-cache # full clean rebuild (ignore Docker layer cache)
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

NOCACHE=""
case "${1:-}" in
  --no-cache|-c) NOCACHE="--no-cache" ;;
  "") ;;
  *) echo "usage: ./rebuild.sh [--no-cache]"; exit 2 ;;
esac

if [ ! -f .env ]; then
  echo "⚠️  No .env found — run ./setup.sh first (or cp .env.template .env and add a key)."
  exit 1
fi

echo "🔁 Rebuilding The Gauntlet${NOCACHE:+ (no cache)}…"
docker compose down                      # stop + remove container (keeps ./data)
if [ -n "$NOCACHE" ]; then
  docker compose build --no-cache
fi
docker compose up -d --build             # (re)build image and recreate container

PORT="$(grep -E '^GAUNTLET_PORT=' .env | cut -d= -f2 || true)"; PORT="${PORT:-8000}"
echo "✅ Rebuilt & up.  Web UI:  http://localhost:${PORT}"
echo "   API:        http://localhost:${PORT}/challenges"
echo "   Stop with:  ./stop.sh"
