#!/usr/bin/env bash
# install_finbot-ctf-demo.sh
# Installs finbot-ctf-demo into labs/webapps/ using uv, creates a local .venv,
# and writes start_service.sh / stop_service.sh to launch on port 10001.

set -euo pipefail

# --- Config (override via env) ---
BASE_DIR="${BASE_DIR:-labs/webapps}"
REPO_URL="${REPO_URL:-https://github.com/detoxio-ai/finbot-ctf-demo.git}"
CLONE_DIR_NAME="${CLONE_DIR_NAME:-finbot-ctf-demo}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
APP_PORT="${APP_PORT:-10001}"

echo "==> Installing finbot-ctf-demo"
echo "    BASE_DIR=${BASE_DIR}"
echo "    REPO_URL=${REPO_URL}"
echo "    CLONE_DIR_NAME=${CLONE_DIR_NAME}"
echo "    PYTHON_VERSION=${PYTHON_VERSION}"
echo "    APP_PORT=${APP_PORT}"

# --- Preflight ---
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required but not found." >&2
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv is not installed or not on PATH. See https://docs.astral.sh/uv/ for install instructions." >&2
  exit 1
fi

# --- Create target dir ---
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"

# --- Clone repo ---
if [[ -d "${CLONE_DIR_NAME}" ]]; then
  echo "Repo directory '${BASE_DIR}/${CLONE_DIR_NAME}' already exists. Skipping clone."
else
  echo "Cloning repository into ${BASE_DIR}/${CLONE_DIR_NAME} ..."
  git clone "${REPO_URL}" "${CLONE_DIR_NAME}"
fi

cd "${CLONE_DIR_NAME}"

# --- Create virtualenv and install requirements ---
echo "Creating .venv with uv (Python ${PYTHON_VERSION})..."
uv venv .venv --python "${PYTHON_VERSION}"

echo "Activating .venv and installing dependencies..."
# shellcheck disable=SC1091
source .venv/bin/activate

if [[ -f requirements.txt ]]; then
  uv pip install -r requirements.txt
elif [[ -f pyproject.toml ]]; then
  uv pip install -e .
else
  echo "WARNING: No requirements.txt or pyproject.toml found; continuing without dependency install."
fi

# Ensure gunicorn is available (in case it's missing from requirements)
if ! command -v gunicorn >/dev/null 2>&1; then
  echo "gunicorn not found in environment; installing..."
  uv pip install gunicorn
fi

# --- Create start_service.sh ---
START_SCRIPT="${BASE_DIR}/${CLONE_DIR_NAME}/start_service.sh"
cat > "${START_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Run from repo root
cd "$(dirname "$0")"

# Bind port (override with PORT)
export PORT="${PORT:-10001}"

# Optional gunicorn tuning
export WORKERS="${WORKERS:-2}"
export TIMEOUT="${TIMEOUT:-120}"

# Activate env
# shellcheck disable=SC1091
source .venv/bin/activate

# Start the Flask app (app object at app:app)
exec uv run gunicorn app:app \
  --bind "0.0.0.0:${PORT}" \
  --workers "${WORKERS}" \
  --timeout "${TIMEOUT}"
EOF
chmod +x "${START_SCRIPT}"

# --- Create stop_service.sh ---
STOP_SCRIPT="${BASE_DIR}/${CLONE_DIR_NAME}/stop_service.sh"
cat > "${STOP_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "🛑 Stopping finbot-ctf-demo (gunicorn)..."
PIDS=$(pgrep -f "gunicorn app:app" 2>/dev/null || true)
if [[ -n "${PIDS}" ]]; then
  echo "${PIDS}" | xargs kill -TERM
  echo "✅ Stopped."
else
  echo "ℹ️  No running gunicorn app:app process found."
fi
EOF
chmod +x "${STOP_SCRIPT}"

# --- Final notes ---
echo ""
echo "============================================================"
echo "   finbot-ctf-demo – Installation Complete!"
echo "============================================================"
echo ""
echo "  Repo      : ${BASE_DIR}/${CLONE_DIR_NAME}"
echo "  Virtualenv: ${BASE_DIR}/${CLONE_DIR_NAME}/.venv"
echo ""
echo "  Helper scripts:"
echo "    Start → ${START_SCRIPT}"
echo "    Stop  → ${STOP_SCRIPT}"
echo ""
echo "  ─── Next steps ────────────────────────────────────────"
echo "  1. Start (default port ${APP_PORT}):"
echo "       ${START_SCRIPT}"
echo ""
echo "  2. Override port:"
echo "       PORT=${APP_PORT} ${START_SCRIPT}"
echo ""
echo "  3. Stop:"
echo "       ${STOP_SCRIPT}"
echo ""
