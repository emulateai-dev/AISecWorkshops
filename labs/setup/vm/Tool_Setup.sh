#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DTX Lab — Post setup (user tools, repos, models, keys)
# Run with: sudo ./Tool_Setup.sh
#
# This script is idempotent — safe to re-run at any time to
# install missing components or refresh the environment.
# ============================================================

# --- Resolve target user/home (prefer sudo caller), fallback 'dtx' ---
TARGET_USER="${SUDO_USER:-dtx}"
if ! id "$TARGET_USER"; then
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
  grep -qF "$marker" "$bashrc" || {
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
  # uv tool install is idempotent — upgrades if already installed
  uv tool install --upgrade "dtx[torch]>=0.26.0"
  uv tool install --upgrade "garak"
  uv tool install --upgrade "huggingface_hub[cli,torch]"
'

# ============================================================
# 3) Ollama models (system-level, tolerate absence)
# ============================================================
# Start/enable service if present (don’t fail hard on minimal envs)
systemctl enable ollama || true
systemctl start  ollama || true

# Pull models only if not already present
pull_if_missing() {
  local model="$1"
  if ollama list 2>/dev/null | grep -q "^${model}"; then
    echo "ℹ️  Model '${model}' already present — skipping pull."
  else
    ollama pull "${model}" || echo "⚠️  Failed to pull '${model}' — skipping."
  fi
}
pull_if_missing smollm2
pull_if_missing qwen3:0.6b
pull_if_missing llama-guard3:1b-q3_K_S
pull_if_missing llama3.1

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
  uv tool install --upgrade "llm"
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
  source "$HOME/.local/bin/env" || true

  PY_BIN="$( (uv python find 3.12) || command -v python3.12 || command -v python3 || echo python )"

  if [ ! -d "$HOME/.aisecurity" ]; then
    "$PY_BIN" -m venv "$HOME/.aisecurity"
    echo "✅ Created ~/.aisecurity venv."
  else
    echo "ℹ️  ~/.aisecurity venv already exists — upgrading packages."
  fi

  source "$HOME/.aisecurity/bin/activate"
  python -m pip install --upgrade pip
  pip install --upgrade torch nltk transformers datasets
  deactivate
'

# ============================================================
# 11) Metasploit — MUST run as root (msfinstall does root ops)
# ============================================================
if command -v msfconsole >/dev/null 2>&1; then
  echo "ℹ️  Metasploit already installed — skipping."
else
  MSF_TMP="$(mktemp -d)"
  pushd "$MSF_TMP"
  curl -SL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o msfinstall
  chmod 755 msfinstall
  rm -f /usr/share/keyrings/metasploit-framework.gpg || true
  yes | ./msfinstall || true
  yes | msfdb init   || true
  popd
  rm -rf "$MSF_TMP"
fi


# ============================================================
# 12) Ollama service — listen on 0.0.0.0 (remote access)
# ============================================================
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
systemctl daemon-reload
systemctl restart ollama || true
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
# Build devcontainer image only if not already built
if docker image inspect pyrit-devcontainer >/dev/null 2>&1; then
  echo "ℹ️  pyrit-devcontainer image already exists — skipping build."
else
  docker build \
    -f "$PYRIT_DIR/PyRIT/.devcontainer/Dockerfile" \
    -t pyrit-devcontainer \
    "$PYRIT_DIR/PyRIT/.devcontainer" || echo "⚠️  PyRIT devcontainer build failed (Docker may not be available)."
fi
echo "✅ PyRIT setup complete — repo: $PYRIT_DIR/PyRIT"

# ============================================================
# 14) Vulnerable Model Dataset (git-lfs clone, user-scope)
# ============================================================
if ! git lfs version >/dev/null 2>&1; then
  echo "ℹ️  git-lfs not found. Installing git-lfs..."
  apt-get update || true
  apt-get install -y git-lfs
fi

VULN_MODEL_DIR="$TARGET_HOME/labs/datasets"
sudo -u "$TARGET_USER" bash -lc "
  set -e
  git lfs install --skip-repo || true
  mkdir -p '$VULN_MODEL_DIR'
  cd '$VULN_MODEL_DIR'
  if [ ! -d vulnerable_llama_model ]; then
    git clone https://huggingface.co/eai-sec-workshop/vulnerable_llama_model
  else
    echo 'ℹ️  vulnerable_model dataset already exists; skipping clone.'
  fi
"
echo "✅ Vulnerable model dataset ready: $VULN_MODEL_DIR/vulnerable_llama_model"

# Register the vulnerable model with Ollama (single source of truth)
# Both jailbroken-llama and vulnerable-llama point to the same GGUF
if ollama list 2>/dev/null | grep -q "^jailbroken-llama"; then
  echo "ℹ️  jailbroken-llama already registered in Ollama — skipping."
else
  echo "➡️  Registering jailbroken-llama with Ollama..."
  (cd "$VULN_MODEL_DIR/vulnerable_llama_model" && ollama create jailbroken-llama -f Modelfile) \
    && echo "✅ jailbroken-llama registered in Ollama." \
    || echo "⚠️  Failed to register jailbroken-llama in Ollama."
fi

# Create vulnerable-llama alias (used by DVMCP lab) — same model, no re-download
if ollama list 2>/dev/null | grep -q "^vulnerable-llama"; then
  echo "ℹ️  vulnerable-llama alias already exists — skipping."
else
  ollama cp jailbroken-llama vulnerable-llama \
    && echo "✅ vulnerable-llama alias created from jailbroken-llama." \
    || echo "⚠️  Failed to create vulnerable-llama alias."
fi

# ============================================================
# 15) BurpSuite Community Edition (silent / non-interactive)
# ============================================================
if command -v burpsuite >/dev/null 2>&1 || [ -f "/usr/local/bin/burpsuite" ] || \
   find /opt /usr/local -name "burpsuite*" -maxdepth 4 2>/dev/null | grep -q .; then
  echo "ℹ️  BurpSuite already installed — skipping."
else
  BURP_TMP="$(mktemp -d)"
  BURP_INSTALLER="$BURP_TMP/burpsuite_installer.sh"
  curl -SL \
    "https://portswigger.net/burp/releases/download?product=community&version=2026.1.4&type=Linux" \
    -o "$BURP_INSTALLER"
  chmod +x "$BURP_INSTALLER"
  # Run headless; accept defaults; suppress interactive prompts
  "$BURP_INSTALLER" -q || \
    "$BURP_INSTALLER" --mode unattended || true
  rm -rf "$BURP_TMP"
  echo "✅ BurpSuite Community installation attempted."
fi



# ============================================================
# 16) Lab installations (user-scope, all idempotent)
# ============================================================
SCRIPTS_DIR="$TARGET_HOME/labs/AISecWorkshops/labs/setup/scripts/tools"

install_lab() {
  local script="$1"
  local label="$2"
  if [ ! -f "$SCRIPTS_DIR/$script" ]; then
    echo "⚠️  $script not found — skipping $label."
    return
  fi
  echo "➡️  Installing $label..."
  sudo -u "$TARGET_USER" bash -lc "bash '$SCRIPTS_DIR/$script'" \
    && echo "✅ $label installed." \
    || echo "⚠️  $label install failed — check output above."
}

# install_lab install-folly.sh                        "Folly"
# install_lab install-pyrit.sh                        "PyRIT"
# install_lab install-edr.sh                          "EDR"
# install_lab install-openai-cs-agents-demo.sh        "OpenAI CS Agents"
# install_lab install-dvmcp.sh                        "DVMCP"
# install_lab install-pentagi.sh                      "PentAGI"
# install_lab install-ai-red-teaming-playground-labs.sh "AI Red Teaming Labs"

echo '127.0.0.1 emulateai-mcp.local' | sudo tee -a /etc/hosts

# ============================================================
# Done
# ============================================================
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.aisecurity" || true
echo "✅ Post-setup complete for $TARGET_USER"

