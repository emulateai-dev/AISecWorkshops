#!/usr/bin/env bash
# Run validate-detector.py under garak's own interpreter, wherever it lives.
#
#   ./run-validate.sh        # 10 pairs
#   ./run-validate.sh 20     # 20 pairs
set -euo pipefail
cd "$(dirname "$0")"
exec "$(./install-plugins.sh --python)" validate-detector.py "$@"
