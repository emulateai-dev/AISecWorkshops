#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "🛑 Stopping The Gauntlet…"
docker compose down
echo "✅ Stopped. (Sessions in ./data are preserved.)"
