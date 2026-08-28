#!/usr/bin/env bash
#
# Extract the raw LLM request/response JSONL embedded in an opencode-trace HTML file.
#
# The @ljw1004/opencode-trace plugin writes one HTML file per session into
# ~/opencode-trace. Each file is a self-contained viewer *plus* the raw wire
# bodies, appended as JSONL after an unterminated `<!--` comment at the tail.
# This script strips the HTML and hands you the JSONL.
#
# Usage:
#   ./trace-to-jsonl.sh ~/opencode-trace/<session>.html > trace.jsonl
#   ./trace-to-jsonl.sh ~/opencode-trace/<session>.html | jq -c '{_id,_kind,_purpose,_url}'
#
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $(basename "$0") <opencode-trace-file.html>" >&2
  exit 2
fi

file="$1"
[[ -f "$file" ]] || { echo "error: no such file: $file" >&2; exit 1; }

# The JSONL payload starts on the line after the last line beginning with `<!--`.
start=$(grep -n '^<!--' "$file" | tail -1 | cut -d: -f1) || true
if [[ -z "${start:-}" ]]; then
  echo "error: no trace payload found in $file (is this an opencode-trace HTML file?)" >&2
  exit 1
fi

tail -n +$((start + 1)) "$file"
