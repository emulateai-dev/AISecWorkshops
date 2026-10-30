#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cp .env.template .env
  echo "ℹ️  Created .env from template. Add your GROQ_API_KEY or set SECRETS_DIR, then re-run."
fi

echo "🏰 Starting The Gauntlet…"
docker compose up -d --build

PORT="$(grep -E '^GAUNTLET_PORT=' .env | cut -d= -f2)"; PORT="${PORT:-8000}"
echo "✅ Up.  Web UI:  http://localhost:${PORT}"
echo "   API:        http://localhost:${PORT}/challenges"
echo "   Stop with:  ./stop.sh"
