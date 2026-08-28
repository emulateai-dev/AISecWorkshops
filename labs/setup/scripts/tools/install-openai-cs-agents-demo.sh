#!/usr/bin/env bash
# Installs detoxio-ai/openai-cs-agents-demo under ~/labs/agents/,
# prepares python-backend/.venv with uv, installs UI deps,
# binds Next.js dev/prod to 0.0.0.0, and creates start_service.sh to run `npm run dev`.

set -euo pipefail

# --- Config (override via env) ---
BASE_DIR="${BASE_DIR:-$HOME/labs/agents}"
REPO_URL="${REPO_URL:-https://github.com/openai/openai-cs-agents-demo}"
CLONE_DIR="${CLONE_DIR:-openai-cs-agents-demo}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

echo "==> Installing ${CLONE_DIR}"
echo "    BASE_DIR=${BASE_DIR}"
echo "    REPO_URL=${REPO_URL}"
echo "    PYTHON_VERSION=${PYTHON_VERSION}"

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

# --- start_service.sh at repo root ---
cat > start_service.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Runs both frontend and backend via the ui package.json "dev" script.
cd "$(dirname "$0")/ui"

# If you keep OPENAI_API_KEY in ../python-backend/.env, python-dotenv will load it.
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

# --- optional backend .env template ---
if [[ ! -f python-backend/.env ]]; then
  # Auto-read from ~/.secrets/ if available, otherwise leave as placeholder
  _OPENAI_KEY=""
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    _OPENAI_KEY="${OPENAI_API_KEY}"
  elif [[ -f "$HOME/.secrets/OPENAI_API_KEY.txt" ]]; then
    _OPENAI_KEY="$(cat "$HOME/.secrets/OPENAI_API_KEY.txt")"
  fi

  cat > python-backend/.env <<EOF
OPENAI_API_KEY=${_OPENAI_KEY:-replace_me}
EOF

  if [[ -z "${_OPENAI_KEY}" ]]; then
    echo "ℹ️  OPENAI_API_KEY not found in env or ~/.secrets/OPENAI_API_KEY.txt"
    echo "    Edit python-backend/.env and set your key before starting."
  else
    echo "✅ OPENAI_API_KEY written to python-backend/.env"
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
echo "  # Option A: export your key in the shell"
echo "  export OPENAI_API_KEY=your_api_key"
echo "  ${BASE_DIR}/${CLONE_DIR}/start_service.sh"
echo ""
echo "  # Option B: put your key in ${BASE_DIR}/${CLONE_DIR}/python-backend/.env (already created)"
echo "  ${BASE_DIR}/${CLONE_DIR}/start_service.sh"
echo ""
echo "UI: Next.js dev binds to 0.0.0.0:3000"
echo "API: Uvicorn binds to 0.0.0.0:8000"

