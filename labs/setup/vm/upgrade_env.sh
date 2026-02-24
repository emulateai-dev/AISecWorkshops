#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DTX Lab — Post setup (user tools, repos, models, keys)
# Run with: sudo ./post.sh
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
# Build devcontainer image from repo root (context must include .devcontainer/)
docker build \
  -f "$PYRIT_DIR/PyRIT/.devcontainer/Dockerfile" \
  -t pyrit-devcontainer \
  "$PYRIT_DIR/PyRIT/.devcontainer" || echo "⚠️  PyRIT devcontainer build failed (Docker may not be available)."
echo "✅ PyRIT setup complete — repo: $PYRIT_DIR/PyRIT"

# ============================================================
# 14) Vulnerable Model Dataset (git-lfs clone, user-scope)
# ============================================================
VULN_MODEL_DIR="$TARGET_HOME/labs/datasets"
sudo -u "$TARGET_USER" bash -lc "
  set -e
  git lfs install --skip-repo || true
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
curl -SL \
  "https://portswigger.net/burp/releases/download?product=community&version=2026.1.4&type=Linux" \
  -o "$BURP_INSTALLER"
chmod +x "$BURP_INSTALLER"
# Run headless; accept defaults; suppress interactive prompts
"$BURP_INSTALLER" -q || \
  "$BURP_INSTALLER" --mode unattended || true
rm -rf "$BURP_TMP"
echo "✅ BurpSuite Community installation attempted."



# ============================================================
# Done
# ============================================================
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.aisecurity" || true
echo "✅ Post-setup complete for $TARGET_USER"
