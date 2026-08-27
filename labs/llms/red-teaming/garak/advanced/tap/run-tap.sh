#!/usr/bin/env bash
# TAP (Tree of Attacks with Pruning) against a model served by Ollama.
#
#   attacker   deepseek-v4-flash:cloud   writes and refines jailbreak prompts
#   evaluator  gemma4:31b-cloud          scores candidates 1-10, drives pruning
#   target     gpt-oss:120b-cloud        the model under test
#
# usage: ./run-tap.sh [smoke|lite|full] [target-model]
#
#   smoke   1x3x1    ~30s     wiring check
#   lite    2x3x3    ~15 min  shallow but real search   (default)
#   full    4x10x10  hours    garak defaults
#
# Override models with env vars: TAP_TARGET, TAP_ATTACKER, TAP_EVALUATOR

set -euo pipefail
cd "$(dirname "$0")"

LEVEL="${1:-lite}"
case "$LEVEL" in
    smoke|lite|full) ;;
    *) echo "usage: $0 [smoke|lite|full] [target-model]" >&2; exit 1 ;;
esac
CONFIG="configs/tap.$LEVEL.yaml"

TARGET="${2:-${TAP_TARGET:-gpt-oss:120b-cloud}}"
ATTACKER="${TAP_ATTACKER:-$(grep -m1 'attack_model_name:'    "$CONFIG" | awk '{print $2}')}"
EVALUATOR="${TAP_EVALUATOR:-$(grep -m1 'evaluator_model_name:' "$CONFIG" | awk '{print $2}')}"

# garak requires a key to be present for OpenAICompatible; Ollama ignores its value.
export OPENAICOMPATIBLE_API_KEY="${OPENAICOMPATIBLE_API_KEY:-ollama-local}"

curl -sf http://localhost:11434/api/tags >/dev/null \
    || { echo "ollama is not responding on :11434 — run 'ollama serve'" >&2; exit 1; }

# Every model's manifest must exist locally before a client can select it.
# ":cloud" tags additionally need `ollama signin` or OLLAMA_API_KEY.
for m in "$TARGET" "$ATTACKER" "$EVALUATOR"; do
    ollama list | awk '{print $1}' | grep -qx "$m" || { echo ">> pulling $m"; ollama pull "$m"; }
done

echo ">> TAP [$LEVEL]  target=$TARGET  attacker=$ATTACKER  evaluator=$EVALUATOR"
grep -E '^ +(branching_factor|width|depth):' "$CONFIG" | sed 's/^/   /'

# tap.TAP is inactive by default, so it must be named explicitly —
# --spec 'tag:...' and 'tier:N' will never select it.
garak \
    --config "$CONFIG" \
    -t ollama.OllamaGeneratorChat \
    -n "$TARGET" \
    --probes tap.TAP \
    --report_prefix "tap_${LEVEL}_"

cat <<'NOTE'

>> Reading the result
   TAP returns a prompt ONLY when the judge scores it a perfect 10/10.
   Anything less returns an empty list, the probe mints zero attempts, and
   garak reports "0it" with no eval line. That is a null result (the target
   held), not a crash.

   Successful jailbreaks, if any, are appended to:
     ~/.cache/garak/data/tap/tap_jailbreaks.txt

   For per-candidate judge scores, run ./tap_trace.py instead — garak's TAP
   logs none of them.
NOTE
