#!/usr/bin/env bash
# =====================================================================
# The Gauntlet — setup
# Build .env from keys in ~/.secrets (or SECRETS_DIR). If no key is found,
# still create .env and tell the user to pick a provider and add an API key.
# Key VALUES are inlined into .env but NEVER printed to the terminal.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

SECRETS_DIR="${SECRETS_DIR:-$HOME/.secrets}"
ENV_FILE=".env"

# Providers the lab can use:  name | key file in ~/.secrets | .env variable.
# groq is the configured default (config/provider.yaml); the rest are for convenience.
PROVIDERS=(
  "groq|GROQ_API_KEY.txt|GROQ_API_KEY"
  "openai|OPENAI_API_KEY.txt|OPENAI_API_KEY"
  "anthropic|ANTHROPIC_API_KEY.txt|ANTHROPIC_API_KEY"
)

echo "🔧 The Gauntlet setup"
echo "   secrets dir: $SECRETS_DIR"

# Never clobber an existing .env.
if [ -f "$ENV_FILE" ]; then
  echo "ℹ️  $ENV_FILE already exists — leaving it untouched."
  echo "    Delete it and re-run ./setup.sh to regenerate from $SECRETS_DIR."
  exit 0
fi

# Discover which provider keys are present (non-empty files).
found_keys=()
if [ -d "$SECRETS_DIR" ]; then
  for p in "${PROVIDERS[@]}"; do
    IFS='|' read -r name file var <<< "$p"
    f="$SECRETS_DIR/$file"
    if [ -f "$f" ] && [ -s "$f" ]; then
      found_keys+=("$name|$var|$f")
    fi
  done
fi

# ---- No keys available: create .env and guide the user. ----
if [ "${#found_keys[@]}" -eq 0 ]; then
  cp .env.template "$ENV_FILE"
  cat <<EOF

⚠️  No provider API keys found in $SECRETS_DIR
    (looked for: GROQ_API_KEY.txt, OPENAI_API_KEY.txt, ANTHROPIC_API_KEY.txt)

    Created $ENV_FILE from the template — but you must pick a provider and add a key:

      1) Edit $ENV_FILE and set   GROQ_API_KEY=gsk_...   (Groq is the default provider), OR
      2) Drop the key in a file:  echo 'gsk_...' > $SECRETS_DIR/GROQ_API_KEY.txt
         then re-run ./setup.sh   (it will inline the key for you), OR
      3) Offline demo (no key):   set  GAUNTLET_MOCK=1  in $ENV_FILE

    Free Groq key: https://console.groq.com/keys
    Then start the lab with:  ./start.sh
EOF
  exit 0
fi

# ---- Keys found: write .env from the template with the key(s) inlined. ----
# Strip the lines we manage (keep the template's comments), then append real values.
grep -vE '^(GROQ_API_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|SECRETS_DIR)=' .env.template > "$ENV_FILE"
{
  echo ""
  echo "# --- keys inlined by setup.sh from $SECRETS_DIR (do not commit) ---"
} >> "$ENV_FILE"

primary=""
for entry in "${found_keys[@]}"; do
  IFS='|' read -r name var file <<< "$entry"
  val="$(tr -d '\r\n' < "$file")"           # strip newlines; value stays out of the terminal
  printf '%s=%s\n' "$var" "$val" >> "$ENV_FILE"   # printf %s is literal (safe for key chars)
  [ -z "$primary" ] && primary="$name"
  echo "   ✅ $name key loaded into $ENV_FILE (from $file)"
done

echo ""
echo "✅ $ENV_FILE ready (provider: $primary). Start the lab with:  ./start.sh"
echo "   (Keys are inlined, so SECRETS_DIR is not needed and was left unset.)"
