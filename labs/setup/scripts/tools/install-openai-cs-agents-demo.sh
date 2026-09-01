#!/usr/bin/env bash
# Installs detoxio-ai/openai-cs-agents-demo under ~/labs/agents/,
# prepares python-backend/.venv with uv, installs UI deps,
# binds Next.js dev/prod to 0.0.0.0, and creates start_service.sh to run `npm run dev`.
#
# Optional: point the demo at a local Ollama model instead of the real OpenAI
# API (USE_OLLAMA=true). Unlike Folly, this app has no runtime provider switch
# built in — MODEL/GUARDRAIL_MODEL are hardcoded strings in its own source, so
# this is applied as a one-time source patch after cloning, same idea as the
# Next.js host-binding patch below.

set -euo pipefail

# --- Config (override via env) ---
BASE_DIR="${BASE_DIR:-$HOME/labs/agents}"
REPO_URL="${REPO_URL:-https://github.com/openai/openai-cs-agents-demo}"
CLONE_DIR="${CLONE_DIR:-openai-cs-agents-demo}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
USE_OLLAMA="${USE_OLLAMA:-false}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1}"
OLLAMA_GUARDRAIL_MODEL="${OLLAMA_GUARDRAIL_MODEL:-${OLLAMA_MODEL}}"

echo "==> Installing ${CLONE_DIR}"
echo "    BASE_DIR=${BASE_DIR}"
echo "    REPO_URL=${REPO_URL}"
echo "    PYTHON_VERSION=${PYTHON_VERSION}"
echo "    USE_OLLAMA=${USE_OLLAMA}"
[[ "${USE_OLLAMA}" == "true" ]] && echo "    OLLAMA_MODEL=${OLLAMA_MODEL}  OLLAMA_GUARDRAIL_MODEL=${OLLAMA_GUARDRAIL_MODEL}"

# --- Preflight ---
need(){ command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' is required."; exit 1; }; }
need git; need uv; need npm; need npx

# --- Clone repo ---
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"
if [[ -d "${CLONE_DIR}" ]]; then
  echo "Repo dir exists: ${BASE_DIR}/${CLONE_DIR} (skipping clone)"
else
  git clone "${REPO_URL}" "${CLONE_DIR}"
fi

cd "${CLONE_DIR}"

# --- Backend setup: python-backend/.venv ---
if [[ ! -d python-backend ]]; then
  echo "ERROR: 'python-backend' directory not found." >&2
  exit 2
fi

pushd python-backend >/dev/null
uv venv .venv --python "${PYTHON_VERSION}"
# shellcheck disable=SC1091
source .venv/bin/activate
[[ -f requirements.txt ]] && uv pip install -r requirements.txt
# Ensure backend dev server deps
uv pip install "uvicorn[standard]" python-dotenv >/dev/null
popd >/dev/null

# --- UI deps ---
if [[ ! -d ui ]]; then
  echo "ERROR: 'ui' directory not found." >&2
  exit 3
fi

pushd ui >/dev/null
npm install
# ensure concurrently exists for combined dev script
npm install -D concurrently >/dev/null || true

# --- Bind Next.js to 0.0.0.0 in dev and prod ---
# Update "dev:next": npx next dev --hostname 0.0.0.0
if grep -q '"dev:next"' package.json; then
  sed -i -E \
    's/("dev:next"\s*:\s*")((npx\s+)?next dev)([^"]*)"/\1npx next dev --hostname 0.0.0.0\4"/' \
    package.json
else
  echo 'WARNING: Could not find "dev:next" in ui/package.json; skipping dev host patch.'
fi

# Update "start": next start --hostname 0.0.0.0
if grep -q '"start"' package.json; then
  sed -i -E \
    's/("start"\s*:\s*")((npx\s+)?next start|next start)([^"]*)"/\1next start --hostname 0.0.0.0\4"/' \
    package.json
fi
popd >/dev/null

# --- Patch server.py: functools.partial has no __code__/__closure__ ---
# python-backend/requirements.txt pins openai-agents to no version at all, so
# `pip install -r requirements.txt` always resolves whatever's newest. As of
# openai-agents 0.22.0, Handoff.on_invoke_handoff is built as
# `partial(_invoke_handoff_with_redaction, _invoke_handoff_impl)` (confirmed
# by reading agents/handoffs/__init__.py in that release) instead of a plain
# closure. server.py's _record_events() does `fn.__code__.co_freevars` on it
# purely to derive a cosmetic display label for a handoff's on_handoff
# callback — functools.partial has no __code__, so this crashes every chat
# turn that goes through a handoff with:
#   AttributeError: 'functools.partial' object has no attribute '__code__'
# Making the two lookups defensive (empty fv/cl -> the label is skipped,
# nothing else breaks) survives this SDK-internals change and any future one
# like it, instead of chasing an exact openai-agents version to pin.
SERVER_PY="python-backend/server.py"
if [[ -f "${SERVER_PY}" ]]; then
  if grep -q 'fn\.__code__\.co_freevars' "${SERVER_PY}"; then
    sed -i \
      -e 's/fv = fn\.__code__\.co_freevars/fv = getattr(getattr(fn, "__code__", None), "co_freevars", ())/' \
      -e 's/cl = fn\.__closure__ or \[\]/cl = getattr(fn, "__closure__", None) or []/' \
      "${SERVER_PY}"
    echo "Patched ${SERVER_PY}: on_invoke_handoff introspection is now functools.partial-safe."
  else
    echo "${SERVER_PY} already patched (or upstream changed this code) — skipping."
  fi
fi

# --- Optional: wire the demo to a local Ollama model instead of OpenAI ---
if [[ "${USE_OLLAMA}" == "true" ]]; then
  echo ""
  echo "==> Wiring ${CLONE_DIR} to local Ollama (model: ${OLLAMA_MODEL})"

  if command -v ollama >/dev/null 2>&1; then
    echo "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
  else
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi

  if ! pgrep -x "ollama" >/dev/null 2>&1; then
    ollama serve >/dev/null 2>&1 &
    sleep 4
  fi

  for m in "${OLLAMA_MODEL}" "${OLLAMA_GUARDRAIL_MODEL}"; do
    if ollama list 2>/dev/null | grep -q "^${m}"; then
      echo "Model '${m}' already available in Ollama."
    else
      echo "Pulling Ollama model '${m}'... (this may take a while)"
      ollama pull "${m}" || echo "WARNING: failed to pull '${m}' — pull it manually before starting the app: ollama pull ${m}"
    fi
  done

  # Patch the hardcoded OpenAI model names to the local Ollama models. These
  # sed targets are pinned to the exact upstream source lines as of this
  # writing (openai/openai-cs-agents-demo) — if a future `git pull` there
  # changes agents.py/guardrails.py, these silently no-op with a warning
  # instead of corrupting the file; re-check MODEL=/GUARDRAIL_MODEL= by hand
  # in that case.
  AGENTS_PY="python-backend/airline/agents.py"
  GUARDRAILS_PY="python-backend/airline/guardrails.py"

  if grep -q '^MODEL = "gpt-5.2"$' "${AGENTS_PY}"; then
    sed -i "s/^MODEL = \"gpt-5.2\"\$/MODEL = \"${OLLAMA_MODEL}\"/" "${AGENTS_PY}"
    echo "Patched MODEL -> ${OLLAMA_MODEL} in ${AGENTS_PY}"
  elif grep -q "^MODEL = \"${OLLAMA_MODEL}\"\$" "${AGENTS_PY}"; then
    echo "${AGENTS_PY} already patched — skipping."
  else
    echo "WARNING: expected line 'MODEL = \"gpt-5.2\"' not found in ${AGENTS_PY} (upstream may have changed) — set MODEL there by hand."
  fi

  if grep -q '^GUARDRAIL_MODEL = "gpt-4.1-mini"$' "${GUARDRAILS_PY}"; then
    sed -i "s/^GUARDRAIL_MODEL = \"gpt-4.1-mini\"\$/GUARDRAIL_MODEL = \"${OLLAMA_GUARDRAIL_MODEL}\"/" "${GUARDRAILS_PY}"
    echo "Patched GUARDRAIL_MODEL -> ${OLLAMA_GUARDRAIL_MODEL} in ${GUARDRAILS_PY}"
  elif grep -q "^GUARDRAIL_MODEL = \"${OLLAMA_GUARDRAIL_MODEL}\"\$" "${GUARDRAILS_PY}"; then
    echo "${GUARDRAILS_PY} already patched — skipping."
  else
    echo "WARNING: expected line 'GUARDRAIL_MODEL = \"gpt-4.1-mini\"' not found in ${GUARDRAILS_PY} (upstream may have changed) — set GUARDRAIL_MODEL there by hand."
  fi

  # Force the Agents SDK onto the Chat Completions API. It defaults to
  # OpenAI's newer Responses API, which Ollama's OpenAI-compatible endpoint
  # does not implement (only /v1/chat/completions) — without this, every
  # request 404s against Ollama regardless of OPENAI_BASE_URL.
  MAIN_PY="python-backend/main.py"
  if grep -q "set_default_openai_api" "${MAIN_PY}"; then
    echo "${MAIN_PY} already sets an explicit API mode — skipping."
  else
    python3 - "${MAIN_PY}" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
insert_at = 0
for i, line in enumerate(lines):
    if line.startswith("from ") or line.startswith("import "):
        insert_at = i + 1
lines.insert(
    insert_at,
    "\nfrom agents import set_default_openai_api\n"
    "set_default_openai_api(\"chat_completions\")  "
    "# Ollama only supports Chat Completions, not the Responses API\n",
)
with open(path, "w") as f:
    f.writelines(lines)
PYEOF
    echo "Patched ${MAIN_PY} to force Chat Completions mode (required for Ollama)."
  fi
fi

# --- start_service.sh at repo root ---
cat > start_service.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Runs both frontend and backend via the ui package.json "dev" script.
cd "$(dirname "$0")/ui"

# If you keep OPENAI_API_KEY (and, in Ollama mode, OPENAI_BASE_URL) in
# ../python-backend/.env, python-dotenv will load it.
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "ℹ️  OPENAI_API_KEY not set in shell. If it's in python-backend/.env, that's fine."
fi

exec npm run dev
EOF
chmod +x start_service.sh

# --- stop_service.sh at repo root ---
STOP_SCRIPT="${BASE_DIR}/${CLONE_DIR}/stop_service.sh"
cat > "${BASE_DIR}/${CLONE_DIR}/stop_service.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "🛑 Stopping OpenAI CS Agents Demo..."
PIDS=$(pgrep -f "npm run dev" 2>/dev/null || true)
if [[ -n "${PIDS}" ]]; then
  echo "${PIDS}" | xargs kill -TERM
  echo "✅ Stopped."
else
  echo "ℹ️  No running npm run dev process found."
fi
EOF
chmod +x "${BASE_DIR}/${CLONE_DIR}/stop_service.sh"

# --- backend .env ---
# Idempotent key=value updater — safe to re-run even if .env already exists
# from a prior run in a different mode (e.g. switching USE_OLLAMA on later).
set_env_var() {
  local file="$1" name="$2" value="$3"
  touch "${file}"
  if grep -q "^${name}=" "${file}"; then
    sed -i "s|^${name}=.*|${name}=${value}|" "${file}"
  else
    echo "${name}=${value}" >> "${file}"
  fi
}

ENV_FILE="python-backend/.env"
if [[ "${USE_OLLAMA}" == "true" ]]; then
  set_env_var "${ENV_FILE}" "OPENAI_API_KEY" "ollama"
  set_env_var "${ENV_FILE}" "OPENAI_BASE_URL" "http://localhost:11434/v1"
  echo "✅ ${ENV_FILE} configured for local Ollama (${OLLAMA_MODEL} / ${OLLAMA_GUARDRAIL_MODEL})."
else
  _OPENAI_KEY=""
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    _OPENAI_KEY="${OPENAI_API_KEY}"
  elif [[ -f "$HOME/.secrets/OPENAI_API_KEY.txt" ]]; then
    _OPENAI_KEY="$(cat "$HOME/.secrets/OPENAI_API_KEY.txt")"
  fi
  set_env_var "${ENV_FILE}" "OPENAI_API_KEY" "${_OPENAI_KEY:-replace_me}"
  if [[ -z "${_OPENAI_KEY}" ]]; then
    echo "ℹ️  OPENAI_API_KEY not found in env or ~/.secrets/OPENAI_API_KEY.txt"
    echo "    Edit ${ENV_FILE} and set your key before starting."
  else
    echo "✅ OPENAI_API_KEY written to ${ENV_FILE}"
  fi
fi

echo ""
echo "✅ Install complete."
echo "Repo: ${BASE_DIR}/${CLONE_DIR}"
echo ""
echo "  Helper scripts:"
echo "    Start → ${BASE_DIR}/${CLONE_DIR}/start_service.sh"
echo "    Stop  → ${BASE_DIR}/${CLONE_DIR}/stop_service.sh"
echo ""
echo "Usage:"
if [[ "${USE_OLLAMA}" == "true" ]]; then
  echo "  # Ollama mode is configured in python-backend/.env — just start it:"
  echo "  ${BASE_DIR}/${CLONE_DIR}/start_service.sh"
else
  echo "  # Option A: export your key in the shell"
  echo "  export OPENAI_API_KEY=your_api_key"
  echo "  ${BASE_DIR}/${CLONE_DIR}/start_service.sh"
  echo ""
  echo "  # Option B: put your key in ${BASE_DIR}/${CLONE_DIR}/python-backend/.env (already created)"
  echo "  ${BASE_DIR}/${CLONE_DIR}/start_service.sh"
  echo ""
  echo "  # Or re-run this installer with USE_OLLAMA=true to use a local model instead:"
  echo "  USE_OLLAMA=true OLLAMA_MODEL=llama3.1 $0"
fi
echo ""
echo "UI: Next.js dev binds to 0.0.0.0:3000"
echo "API: Uvicorn binds to 0.0.0.0:8000"
