#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DTX Lab — Post setup (user tools, repos, models, keys)
# Run with: sudo ./post.sh
# ============================================================

# --- Resolve target user/home (prefer sudo caller), fallback 'dtx' ---
TARGET_USER="${SUDO_USER:-dtx}"
if ! id "$TARGET_USER" &>/dev/null; then
  echo "❌ Target user '$TARGET_USER' does not exist."; exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
  echo "❌ Could not resolve home for '$TARGET_USER'."; exit 1
fi

echo "➡️  Using TARGET_USER=$TARGET_USER  TARGET_HOME=$TARGET_HOME"

# --- Ensure we're root for system actions
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run with sudo/root."; exit 1
fi

# --- Helper: append to user's .bashrc only once
append_once_bashrc () {
  local marker="$1"
  local block="$2"
  local bashrc="$TARGET_HOME/.bashrc"
  grep -qF "$marker" "$bashrc" 2>/dev/null || {
    printf "%s\n" "$block" >> "$bashrc"
    chown "$TARGET_USER:$TARGET_USER" "$bashrc"
  }
}

# ============================================================
# 1) Ensure uv user environment exists (installed in pre script)
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  if [ ! -f "$HOME/.local/bin/env" ]; then
    echo "❌ uv environment not found at $HOME/.local/bin/env"; exit 1
  fi
'

# ============================================================
# 2) Python tools via uv (user-scope)
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  set -e
  source "$HOME/.local/bin/env"
  uv tool install "dtx[torch]>=0.26.0"
  uv tool install "garak"
  uv tool install "huggingface_hub[cli,torch]"
'

# ============================================================
# 3) Ollama models (system-level, tolerate absence)
# ============================================================
# Start/enable service if present (don’t fail hard on minimal envs)
systemctl enable ollama >/dev/null 2>&1 || true
systemctl start  ollama >/dev/null 2>&1 || true

# Pull models (ignore failures if ollama/daemon not present yet)
ollama pull smollm2                 || true
ollama pull qwen3:0.6b              || true
ollama pull llama-guard3:1b-q3_K_S  || true

# ============================================================
# 4) Export API keys from secrets via user's .bashrc
# ============================================================
API_MARKER="# === Export API keys from secrets directory ==="
API_BLOCK=$(cat <<'EOF'
# === Export API keys from secrets directory ===
if [ -f "$HOME/.secrets/OPENAI_API_KEY.txt" ]; then
  export OPENAI_API_KEY="$(cat "$HOME/.secrets/OPENAI_API_KEY.txt")"
fi
if [ -f "$HOME/.secrets/GROQ_API_KEY.txt" ]; then
  export GROQ_API_KEY="$(cat "$HOME/.secrets/GROQ_API_KEY.txt")"
fi
if [ -f "$HOME/.secrets/HF_TOKEN.txt" ]; then
  export HF_TOKEN="$(cat "$HOME/.secrets/HF_TOKEN.txt")"
fi
EOF
)
append_once_bashrc "$API_MARKER" "$API_BLOCK"

# ============================================================
# 5) Clone labs repos (user-scope)
# ============================================================
LABS_DIR="$TARGET_HOME/labs"
sudo -u "$TARGET_USER" bash -lc "
  set -e
  mkdir -p '$LABS_DIR'
  cd '$LABS_DIR'
  [ -d AISecWorkshops ] || git clone https://github.com/emulateai-dev/AISecWorkshops.git
"

# ============================================================
# 6) Copy validate_installation.sh if present
# ============================================================
INSTALL_DIR="$TARGET_HOME/labs/AISecWorkshops/labs/setup/scripts/tools"
VALIDATE_SCRIPT="$INSTALL_DIR/../validate_installation.sh"
if [ -f "$VALIDATE_SCRIPT" ]; then
  cp "$VALIDATE_SCRIPT" "$TARGET_HOME/validate_installation.sh"
  chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/validate_installation.sh"
  echo "✅ Copied validate_installation.sh to $TARGET_HOME/"
fi

# ============================================================
# 7) Install LLM CLI and set OpenAI key (user-scope)
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  set -e
  source "$HOME/.local/bin/env"
  uv tool install "llm"
  if [ -f "$HOME/.secrets/OPENAI_API_KEY.txt" ]; then
    OPENAI_KEY="$(cat "$HOME/.secrets/OPENAI_API_KEY.txt")"
    if [ -n "$OPENAI_KEY" ]; then
      llm keys set openai --value "$OPENAI_KEY"
    else
      echo "⚠️  OPENAI_API_KEY.txt is empty; skipping llm key set."
    fi
  else
    echo "ℹ️  No $HOME/.secrets/OPENAI_API_KEY.txt; skipping llm key set."
  fi
'

# ============================================================
# 8) Create ~/.aisecurity venv + core ML pkgs (user-scope)
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  set -e
  source "$HOME/.local/bin/env" 2>/dev/null || true

  PY_BIN="$( (uv python find 3.12 2>/dev/null) || command -v python3.12 || command -v python3 || echo python )"
  "$PY_BIN" -m venv "$HOME/.aisecurity"

  source "$HOME/.aisecurity/bin/activate"
  python -m pip install --upgrade pip
  pip install --upgrade torch nltk transformers datasets
  deactivate
'

# ============================================================
# 11) Metasploit — MUST run as root (msfinstall does root ops)
# ============================================================
# Use a temp working dir under /tmp, then clean up
TMPDIR="$(mktemp -d)"
pushd "$TMPDIR" >/dev/null
curl -sSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o msfinstall
chmod 755 msfinstall
rm -f /usr/share/keyrings/metasploit-framework.gpg || true
yes | ./msfinstall >/dev/null 2>&1 || true
yes | msfdb init   >/dev/null 2>&1 || true
popd >/dev/null
rm -rf "$TMPDIR"


# ============================================================
# 12) Ollama service — listen on 0.0.0.0 (remote access)
# ============================================================
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
systemctl daemon-reload
systemctl restart ollama > /dev/null 2>&1 || true
echo "✅ Ollama configured to listen on 0.0.0.0"

# ============================================================
# 13) PyRIT Docker Setup (clone, build devcontainer image)
# ============================================================
PYRIT_DIR="$TARGET_HOME/labs/pyrit"
sudo -u "$TARGET_USER" bash -lc "
  set -e
  mkdir -p '$PYRIT_DIR'
  cd '$PYRIT_DIR'
  if [ ! -d PyRIT ]; then
    git clone https://github.com/jitendra-eai/PyRIT.git
  else
    echo 'ℹ️  PyRIT repo already exists; skipping clone.'
  fi
  mkdir -p \"\$HOME/.pyrit\"
  touch \"\$HOME/.pyrit/.env\" \"\$HOME/.pyrit/.env.local\"
"
# Build devcontainer image from repo root (context must include .devcontainer/)
docker build \
  -f "$PYRIT_DIR/PyRIT/.devcontainer/Dockerfile" \
  -t pyrit-devcontainer \
  "$PYRIT_DIR/PyRIT/.devcontainer" \
  > /dev/null 2>&1 || echo "⚠️  PyRIT devcontainer build failed (Docker may not be available)."
echo "✅ PyRIT setup complete — repo: $PYRIT_DIR/PyRIT"

# ============================================================
# 14) Vulnerable Model Dataset (git-lfs clone, user-scope)
# ============================================================
VULN_MODEL_DIR="$TARGET_HOME/labs/datasets"
sudo -u "$TARGET_USER" bash -lc "
  set -e
  git lfs install --skip-repo > /dev/null 2>&1 || true
  mkdir -p '$VULN_MODEL_DIR'
  cd '$VULN_MODEL_DIR'
  if [ ! -d vulnerable_model ]; then
    git clone https://huggingface.co/eai-sec-workshop/vulnerable_llama_model
  else
    echo 'ℹ️  vulnerable_model dataset already exists; skipping clone.'
  fi
"
echo "✅ Vulnerable model dataset ready: $VULN_MODEL_DIR/vulnerable_model"

# ============================================================
# 15) BurpSuite Community Edition (silent / non-interactive)
# ============================================================
BURP_TMP="$(mktemp -d)"
BURP_INSTALLER="$BURP_TMP/burpsuite_installer.sh"
curl -sSL \
  "https://portswigger.net/burp/releases/download?product=community&version=2026.1.4&type=Linux" \
  -o "$BURP_INSTALLER"
chmod +x "$BURP_INSTALLER"
# Run headless; accept defaults; suppress interactive prompts
"$BURP_INSTALLER" -q 2>/dev/null || \
  "$BURP_INSTALLER" --mode unattended 2>/dev/null || true
rm -rf "$BURP_TMP"
echo "✅ BurpSuite Community installation attempted."

# ============================================================
# 16) MCP Inspector — install globally via npm (user-scope)
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  set -e
  # Install the package globally so it is cached and ready to use without
  # an extra download each time. Users can then launch it at any time with:
  #   npx @modelcontextprotocol/inspector
  npm install -g @modelcontextprotocol/inspector
  echo "✅ MCP Inspector installed. Run with: npx @modelcontextprotocol/inspector"
'

# ============================================================
# Done
# ============================================================
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.aisecurity" 2>/dev/null || true
echo "✅ Post-setup complete for $TARGET_USER"

