#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DTX Lab setup — run with: sudo ./Pre_Installation.sh
# Fixes: empty $USER, sshd vs ssh, root perms, user installs, etc.
# ============================================================

# --- Detect target user (prefer the sudo caller), fallback to 'dtx' ---
TARGET_USER="${SUDO_USER:-dtx}"
if ! id "$TARGET_USER" &>/dev/null; then
  echo "❌ Target user '$TARGET_USER' does not exist."; exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
  echo "❌ Could not resolve home for '$TARGET_USER'."; exit 1
fi

GO_VERSION="1.24.5"
# ============================================================
# UX Tool Variables 
# ============================================================
cai=$(find $TARGET_HOME/.local -name 'cai' 2>/dev/null | grep -o 'cai')
autogenstudio=$(find $TARGET_HOME/.local -name 'autogenstudio' 2>/dev/null | grep -o 'autogenstudio')

echo "🚀 Running setup for user: $TARGET_USER (home: $TARGET_HOME)"
echo "--------------------------------------"

# ============================================================
# 0) Ensure we are root
# ============================================================
if [[ "${EUID}" -ne 0 ]]; then
  echo "❌ Please run this script with sudo (root)."; exit 1
fi

# ============================================================
# 1) Harden SSH (install openssh-server first, then enable)
# ============================================================
apt-get update -qq
apt-get install -y openssh-server
systemctl enable ssh || true
systemctl restart ssh || true

# ============================================================
# 2) Base packages (install curl/git before using them)
# ============================================================
basePac=(apt-transport-https gcc ca-certificates curl gnupg lsb-release git sudo nano vim net-tools nmap tmux python3 python3-pip python3-venv python3.12-venv python-is-python3 build-essential software-properties-common nginx)

for pkg in "${basePac[@]}"; do
    echo "Checking if $pkg is installed"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
       echo "$pkg is already installed"
    elif ! apt-cache show "$pkg" >/dev/null 2>&1; then 
        echo "$pkg cannot be found in our sources"
        echo "skipping $pkg"
    else
        apt install -y "$pkg"
    fi
done
# Add deadsnakes PPA for Python 3.10 and 3.13 (not in Ubuntu 24.04 default repos)
# Confirm OS version
deadsnakes=$(find /etc/apt -name "*deadsnakes*" 2>/dev/null)
OS_VERSION=$(grep -i "VERSION_CODENAME" /etc/os-release | grep -Eo "[a-z]+$")
if [[ "$OS_VERSION" =~ "jammy" || $OS_VERSION =~ "noble" || $OS_VERSION =~ "resolute" ]]; then
    if [[ -z "$deadsnakes" ]]; then 
        add-apt-repository ppa:deadsnakes/ppa -y 
    fi
else
    if [[ -z "$deadsnakes" ]]; then
        add-apt-repository ppa:deadsnakes/ppa -y 
        sed -i "s/$OS_VERSION/noble/g" /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.sources
    else
        sed -i "s/$OS_VERSION/noble/g" /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.sources
    fi
fi

apt update -y 
pythonPac=(python3.10 python3.10-dev python3.10-venv python3.13 python3.13-dev python3.13-venv)
for pkg in "${pythonPac[@]}"; do
    echo "Checking if $pkg is installed or exists"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
       echo "$pkg is already installed"
    elif ! apt-cache show "$pkg" >/dev/null 2>&1; then 
        echo "$pkg cannot be found in our sources"
        echo "skipping $pkg"
    else
        apt install -y "$pkg"
    fi
done

# Validate Python is accessible
python3 --version >/dev/null 2>&1 || { echo "❌ python3 not found after install. Check apt output above."; exit 1; }
python  --version >/dev/null 2>&1 && echo "✅ 'python' alias works." || echo "⚠️  'python' alias not set — install python-is-python3 manually if needed."
echo "✅ Python checks passed."

# ============================================================
# 3) Docker
# ============================================================
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg
gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg /tmp/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
# docker group normally created by package; guard if missing
getent group docker >/dev/null || groupadd docker
usermod -aG docker "$TARGET_USER"

# ============================================================
# 4) USER-SCOPE installs (asdf, uv, node, go tools, tmux conf, tools)
# ============================================================
sudo -u "$TARGET_USER" bash -lc "
  set -euo pipefail

  # --- ASDF ---
  if [ ! -d \"$TARGET_HOME/.asdf\" ]; then
    git clone https://github.com/asdf-vm/asdf.git \"$TARGET_HOME/.asdf\" --branch v0.14.0
  fi
  grep -qxF '. \$HOME/.asdf/asdf.sh' \"$TARGET_HOME/.bashrc\" || echo '. \$HOME/.asdf/asdf.sh' >> \"$TARGET_HOME/.bashrc\"
  grep -qxF '. \$HOME/.asdf/completions/asdf.bash' \"$TARGET_HOME/.bashrc\" || echo '. \$HOME/.asdf/completions/asdf.bash' >> \"$TARGET_HOME/.bashrc\"
  . \"$TARGET_HOME/.asdf/asdf.sh\"

  # --- uv ---
  curl -LsSf https://astral.sh/uv/install.sh | sh
  grep -qxF 'source \$HOME/.local/bin/env' \"$TARGET_HOME/.bashrc\" || echo 'source \$HOME/.local/bin/env' >> \"$TARGET_HOME/.bashrc\"
  source \"$TARGET_HOME/.local/bin/env\"

  # Python via uv
  uv python install 3.12

  # --- Node.js via asdf (+ keyring) ---
  asdf plugin list | grep -qx nodejs || asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  if [ ! -x \"$TARGET_HOME/.asdf/plugins/nodejs/bin/import-release-team-keyring\" ]; then
    echo '⚠️ nodejs plugin keyring script missing; re-adding plugin...'
    asdf plugin remove nodejs || true
    asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  fi
  asdf install nodejs lts
  asdf global nodejs lts
  npm install -g promptfoo

  # --- Go via asdf + tools ---
  asdf plugin list | grep -qx golang || asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
  asdf install golang $GO_VERSION
  asdf global golang $GO_VERSION
  export GOBIN=\"$TARGET_HOME/.local/bin\"
  mkdir -p \"\$GOBIN\"
  export PATH=\"\$GOBIN:\$PATH\"
  go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
  go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
  go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  CGO_ENABLED=0 go install -v github.com/owasp-amass/amass/v5/cmd/amass@main

  # --- tmux config ---
  cat > \"$TARGET_HOME/.tmux.conf\" <<'TMUXRC'
# Vim-style pane nav
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
# Ctrl+Shift+Arrows
bind -n C-S-Left select-pane -L
bind -n C-S-Right select-pane -R
bind -n C-S-Up select-pane -U
bind -n C-S-Down select-pane -D
# Mouse + visuals
set -g mouse on
set -g status-bg colour235
set -g status-fg white
set -g pane-border-style fg=white
set -g pane-active-border-style fg=brightgreen
set -g history-limit 100000
TMUXRC
  tmux has-session 2>/dev/null && tmux source-file \"$TARGET_HOME/.tmux.conf\" || true

  # --- Tools via uv ---
  if [[ \"$cai\" == 'cai' ]]; then 
    echo \"cai is already installed\"
  else
    uv tool install cai-framework
  fi

  if [[ \"$autogenstudio\" == 'autogenstudio' ]]; then
    echo \"autogenstudio is already installed\"
  else
    uv tool install autogenstudio
  fi

  echo '✅ User-scope installs complete.'
"

# Ensure ownership of user home (avoid fragile globs like /home/$USER/.*)
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

# ============================================================
# 5) Ollama (system level)
# ============================================================
if command -v ollama >/dev/null 2>&1; then
  echo "ℹ️  Ollama already installed — skipping."
else
  curl -fsSL https://ollama.com/install.sh | sh
fi
# Systemctl check for ollama 
ollamaCheck=$(systemctl list-unit-files --type=service | grep -o 'ollama')
if [[ "$ollamaCheck" == 'ollama' ]]; then
  systemctl enable ollama || true
  systemctl start ollama || true
else
  echo "Ollama service not found but ollama command is available"
fi

# ============================================================
# 6) Secrets dir
# ============================================================
SECRETS_DIR="$TARGET_HOME/.secrets"
mkdir -p "$SECRETS_DIR"
touch "$SECRETS_DIR/OPENAI_API_KEY.txt"
touch "$SECRETS_DIR/GROQ_API_KEY.txt"
chown -R "$TARGET_USER:$TARGET_USER" "$SECRETS_DIR"

# ============================================================
# 7) Shared folder via NGINX
# ============================================================
sudo -u "$TARGET_USER" bash -lc "
  set -e
  SHARED_DIR=\"$TARGET_HOME/shared\"
  mkdir -p \"\$SHARED_DIR\"
  if [ ! -f \"\$SHARED_DIR/index.html\" ]; then
    echo '<h1>Hello from shared!</h1>' > \"\$SHARED_DIR/index.html\"
  fi
  # Permissions so nginx (www-data) can traverse
  chmod o+x \"$TARGET_HOME\" \"\$SHARED_DIR\"
  find \"\$SHARED_DIR\" -type d -exec chmod o+x {} \;
  find \"\$SHARED_DIR\" -type f -exec chmod o+r {} \;
"

NGINX_CONF=/etc/nginx/sites-available/shared
cat > "$NGINX_CONF" <<EOF
server {
    listen 80 default_server;
    server_name _;
    root $TARGET_HOME/shared;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /shared/ {
        alias $TARGET_HOME/shared/;
        index index.html;
        autoindex on;
        autoindex_exact_size off;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/shared
rm -f /etc/nginx/sites-enabled/default
nginx -t || true
systemctl reload nginx || true

echo "✅ Setup complete for user: $TARGET_USER"
