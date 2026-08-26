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

# Go toolchain version. This installs the toolchain only — the Go-based recon
# tools (httpx, nuclei, subfinder, amass) are built by Tool_Setup.sh, which
# holds their own version pins. Keep this at or above what those pins need,
# otherwise Go silently auto-downloads a newer toolchain at build time.
# Verified 2026-08-26: nuclei v3.11.1, httpx v1.10.0 and amass v5.1.1 all
# require go 1.26; subfinder v2.16.0 requires go 1.25.0.
GO_VERSION="1.26.7"

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
# The Python story differs per Ubuntu release, and getting it wrong is fatal:
# `set -euo pipefail` turns any apt failure into an abort, so a single
# unavailable python3.X package here means NOTHING below this section ever
# runs (no Docker, no uv, no Ollama, no models, no nginx).
#
#   22.04 (jammy)  — python3.12 only via the deadsnakes PPA
#   24.04 (noble)  — python3.12 native (universe); python3.10 via deadsnakes
#   25.04 (plucky) — python3.13 native; python3.10/3.11/3.12 are in NO repo,
#                    and deadsnakes publishes nothing for plucky. Adding the
#                    PPA anyway leaves a source that breaks every subsequent
#                    `apt-get update` with "does not have a Release file".
#
# So: add deadsnakes only on releases it actually supports, and install the
# extra interpreters opportunistically. Gaps are filled by uv in section 4,
# which ships standalone builds for every version the labs need.
. /etc/os-release
RELEASE_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-unknown}}"
echo "➡️  Detected ${PRETTY_NAME:-Ubuntu ${VERSION_ID:-?}} (codename: ${RELEASE_CODENAME})"

apt-get install -y ca-certificates gnupg software-properties-common

# Releases for which the deadsnakes PPA actually publishes packages.
DEADSNAKES_RELEASES="jammy noble"
if grep -qw -- "$RELEASE_CODENAME" <<<"$DEADSNAKES_RELEASES"; then
  add-apt-repository -y ppa:deadsnakes/ppa
else
  echo "ℹ️  Skipping deadsnakes PPA — it publishes nothing for '${RELEASE_CODENAME}'."
  # Remove it if an earlier run of this script (or an older VM image) added
  # it, otherwise every apt-get update from here on fails on the missing
  # Release file and takes the rest of this script down with it.
  rm -f /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.sources \
        /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-*.list
  sed -i '/deadsnakes/d' /etc/apt/sources.list
fi
apt-get update

# Packages present on every supported release.
apt-get install -y \
  apt-transport-https \
  gcc \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  git-lfs \
  acl \
  sudo \
  nano \
  vim \
  net-tools \
  nmap \
  tmux \
  jq \
  python3 \
  python3-pip \
  python3-venv \
  python-is-python3 \
  build-essential \
  nginx

# Extra Python interpreters — install the ones this release offers and
# report (never abort on) the ones it doesn't.
apt_install_optional() {
  local pkg
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      if apt-get install -y "$pkg" >/dev/null 2>&1; then
        echo "  ✅ $pkg"
      else
        echo "  ⚠️  $pkg is available but failed to install"
      fi
    else
      echo "  ℹ️  $pkg not in any repo for ${RELEASE_CODENAME} — uv provides it instead (section 4)"
    fi
  done
}
echo "➡️  Installing additional Python interpreters available on this release..."
apt_install_optional \
  python3.10 python3.10-dev python3.10-venv \
  python3.12 python3.12-dev python3.12-venv \
  python3.13 python3.13-dev python3.13-venv

# Validate Python is accessible
python3 --version >/dev/null 2>&1 || { echo "❌ python3 not found after install. Check apt output above."; exit 1; }
python  --version >/dev/null 2>&1 && echo "✅ 'python' alias works." || echo "⚠️  'python' alias not set — install python-is-python3 manually if needed."
echo "✅ Python checks passed ($(python3 --version))."

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
# Group membership doesn't take effect in an already-open shell — the next
# `docker ...` command in this same terminal will fail with a permission
# error on the socket until the user logs out/in (or runs `newgrp docker`).
echo "⚠️  '$TARGET_USER' was added to the 'docker' group — log out and back in (or run 'newgrp docker') before using docker without sudo in an existing terminal."

# ============================================================
# 4) USER-SCOPE runtimes (asdf, uv, python, node, go toolchain, tmux conf)
#    Runtimes only — the tools built on top of them are in Tool_Setup.sh.
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

  # Python via uv — 3.12 is the interpreter the lab venvs target, and on
  # releases where apt has no python3.10/3.12 (25.04+) these standalone
  # builds are the ONLY source for them. Installing all three keeps every
  # lab's interpreter available regardless of the host release.
  uv python install 3.10 3.12 3.13

  # --- Node.js via asdf (+ keyring) ---
  asdf plugin list | grep -qx nodejs || asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  if [ ! -x \"$TARGET_HOME/.asdf/plugins/nodejs/bin/import-release-team-keyring\" ]; then
    echo '⚠️ nodejs plugin keyring script missing; re-adding plugin...'
    asdf plugin remove nodejs || true
    asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  fi
  asdf install nodejs lts
  asdf global nodejs lts
  # promptfoo (npm) is installed by Tool_Setup.sh — see its "Node tools" step.

  # --- Go toolchain via asdf ---
  # Toolchain only. The recon tools built with it (httpx, nuclei, subfinder,
  # amass) are installed by Tool_Setup.sh so they can be re-pinned and
  # refreshed without re-running this whole system-level script.
  asdf plugin list | grep -qx golang || asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
  asdf install golang $GO_VERSION
  asdf global golang $GO_VERSION
  # GOBIN target that Tool_Setup.sh installs into; also on PATH via uv's env.
  mkdir -p \"$TARGET_HOME/.local/bin\"

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

  # Lab tools installed via uv (cai-framework, autogenstudio, dtx, garak,
  # huggingface_hub, llm) all live in Tool_Setup.sh — this script only
  # provisions the runtimes they need.

  echo '✅ User-scope runtimes complete (asdf, uv, python, node, go).'
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
# Don't fail hard here — some minimal/containerized envs don't have this
# systemd unit — but DO surface it clearly instead of failing silently,
# since section 6 below depends entirely on the daemon actually being up.
systemctl enable ollama || echo "⚠️  Could not enable the ollama systemd unit — continuing, but model pulls below will likely fail."
systemctl start ollama || echo "⚠️  Could not start the ollama service — continuing, but model pulls below will likely fail."

# Poll instead of a fixed sleep — a fresh install/first start can take longer
# than a couple seconds to bind its HTTP endpoint, especially on a slow or
# resource-constrained VM, and section 6 below fails hard if it isn't ready.
OLLAMA_READY=0
for _ in $(seq 1 15); do
  if ollama list >/dev/null 2>&1; then
    OLLAMA_READY=1
    break
  fi
  sleep 2
done
if [[ "$OLLAMA_READY" -eq 0 ]]; then
  echo "⚠️  ollama daemon is not responding after 30s — model pulls in the next section will fail until this is fixed (check: systemctl status ollama)."
fi

# ============================================================
# 6) Ollama models — base models + the jailbroken/vulnerable model, pulled
#    here (once), right after Ollama itself, so a broken download shows up
#    immediately and these specific models are ready before any lab-specific
#    setup runs. Tool_Setup.sh intentionally does NOT repeat this pull — see
#    the comment left there instead of the old duplicate logic. (Some
#    individual labs, e.g. install-folly.sh, still pull their own separate
#    model independently — this section only owns the models listed below.)
# ============================================================
pull_if_missing() {
  local model="$1"
  if ollama list 2>/dev/null | grep -q "^${model}"; then
    echo "ℹ️  Model '${model}' already present — skipping pull."
  else
    ollama pull "${model}" || echo "⚠️  Failed to pull '${model}' — skipping."
  fi
}

# Base models used across the garak / jailbreaks labs
pull_if_missing smollm2
pull_if_missing qwen3:0.6b
pull_if_missing llama-guard3:1b-q3_K_S
pull_if_missing llama3.1

# Jailbroken SmolLM (small, HF-hosted GGUF) — the model referenced as
# "jailbroken" in labs/llms/red-teaming/jailbreaks/{uncensored_models,
# safety_alignment}.md and labs/setup/ollama/running_gguf_models.md.
# NOTE: this is a DIFFERENT model from jailbroken-llama/vulnerable-llama
# below — same word "jailbroken" in the docs, two unrelated models. Do
# not conflate them when writing or updating lab instructions.
pull_if_missing hf.co/detoxio-test/SmolLM-135M-Instruct-Jailbroken_GGUF

# Vulnerable/jailbroken Llama model — registered as 'jailbroken-llama',
# aliased as 'vulnerable-llama' (the name the DVMCP lab challenges expect;
# see labs/setup/scripts/tools/install-dvmcp.sh, which checks for this
# local copy before falling back to its own HF pull).
# Fetched with curl, NOT `git clone`. The repo holds a single 4.92GB GGUF in
# Git LFS, and cloning it pulls that object through the LFS endpoint on one
# stream — measured at ~394 KB/s on the lab VM (a ~2.5 hour download) while
# the same box pulls 130 MB/s from a general CDN and 8.5 MB/s from the plain
# HF file URL. curl also resumes (-C -), so an interrupted setup continues
# instead of restarting, and needs no git-lfs installed at this point.
VULN_MODEL_DIR="$TARGET_HOME/labs/datasets"
VULN_MODEL_REPO="$VULN_MODEL_DIR/vulnerable_llama_model"
VULN_GGUF_URL="https://huggingface.co/eai-sec-workshop/vulnerable_llama_model/resolve/main/jailbroken-llama.gguf"
VULN_GGUF_SHA256="e7c71d50417b8ad42c7aafdc5074fb471822514f97fec25e14d84700e9e89b33"
sudo -u "$TARGET_USER" bash -lc "
  set -e
  mkdir -p '$VULN_MODEL_REPO'
  cd '$VULN_MODEL_REPO'
  [ -f Modelfile ] || echo 'FROM ./jailbroken-llama.gguf' > Modelfile

  if [ -f jailbroken-llama.gguf ] && \
     echo '$VULN_GGUF_SHA256  jailbroken-llama.gguf' | sha256sum -c - >/dev/null 2>&1; then
    echo 'ℹ️  jailbroken-llama.gguf already present and verified; skipping download.'
  else
    echo '➡️  Downloading jailbroken-llama.gguf (4.9GB) — this takes a few minutes...'
    curl -fL --retry 5 --retry-delay 3 -C - -o jailbroken-llama.gguf '$VULN_GGUF_URL'
    # A truncated or HTML-error download still produces a file, and
    # \`ollama create\` would then fail with the unhelpful 'supplied file was
    # not in GGUF format'. Verify before handing it to ollama.
    echo '$VULN_GGUF_SHA256  jailbroken-llama.gguf' | sha256sum -c -
  fi
"
echo "✅ Vulnerable model ready: $VULN_MODEL_REPO/jailbroken-llama.gguf"

if ollama list 2>/dev/null | grep -q "^jailbroken-llama"; then
  echo "ℹ️  jailbroken-llama already registered in Ollama — skipping."
else
  echo "➡️  Registering jailbroken-llama with Ollama..."
  (cd "$VULN_MODEL_REPO" && ollama create jailbroken-llama -f Modelfile) \
    && echo "✅ jailbroken-llama registered in Ollama." \
    || echo "⚠️  Failed to register jailbroken-llama in Ollama."
fi

if ollama list 2>/dev/null | grep -q "^vulnerable-llama"; then
  echo "ℹ️  vulnerable-llama alias already exists — skipping."
else
  ollama cp jailbroken-llama vulnerable-llama \
    && echo "✅ vulnerable-llama alias created from jailbroken-llama." \
    || echo "⚠️  Failed to create vulnerable-llama alias."
fi

# ============================================================
# 7) Secrets dir
# ============================================================
# Placeholders only — the workshop attendee pastes real keys in. Tool_Setup.sh
# adds a .bashrc block that exports each of these IF the file is non-empty, so
# every key it can export needs a file created here. HF_TOKEN was missing:
# without it, HuggingFace model and dataset pulls run unauthenticated and get
# rate-limited ("You are sending unauthenticated requests to the HF Hub"),
# which the garak HF-model lab and the jailbreak dataset labs both hit.
SECRETS_DIR="$TARGET_HOME/.secrets"
mkdir -p "$SECRETS_DIR"
touch "$SECRETS_DIR/OPENAI_API_KEY.txt"
touch "$SECRETS_DIR/GROQ_API_KEY.txt"
touch "$SECRETS_DIR/HF_TOKEN.txt"
# Keys, not world-readable.
chmod 700 "$SECRETS_DIR"
chmod 600 "$SECRETS_DIR"/*.txt
chown -R "$TARGET_USER:$TARGET_USER" "$SECRETS_DIR"

# ============================================================
# 8) Shared folder via NGINX
# ============================================================
sudo -u "$TARGET_USER" bash -lc "
  set -e
  SHARED_DIR=\"$TARGET_HOME/shared\"
  mkdir -p \"\$SHARED_DIR\"
  if [ ! -f \"\$SHARED_DIR/index.html\" ]; then
    echo '<h1>Hello from shared!</h1>' > \"\$SHARED_DIR/index.html\"
  fi
  # Shared dir itself is meant to be public, so o+x/o+r there is fine.
  chmod o+x \"\$SHARED_DIR\"
  find \"\$SHARED_DIR\" -type d -exec chmod o+x {} \;
  find \"\$SHARED_DIR\" -type f -exec chmod o+r {} \;
"
# Home dir is NOT meant to be public — grant traverse to nginx's user only
# (via ACL) instead of chmod o+x, which would let every local user on this
# box list/enter $TARGET_HOME (default creds are dtx:dtx, so keep this narrow).
if command -v setfacl >/dev/null 2>&1; then
  setfacl -m u:www-data:x "$TARGET_HOME"
else
  echo "⚠️  setfacl not found (acl package) — falling back to chmod o+x on $TARGET_HOME, which is broader than necessary."
  chmod o+x "$TARGET_HOME"
fi

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
nginx -t
systemctl reload nginx

# ============================================================
# 9) Health check summary — the steps above tolerate individual failures
#    (`|| true` / `|| echo ⚠️`) so one broken download doesn't abort the
#    whole run. This is the one place that checks what actually landed,
#    so "✅ Setup complete" below can't mask a degraded setup.
# ============================================================
echo ""
echo "🔍 Health check:"
FAILED=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $label"
  else
    echo "  ❌ $label"
    FAILED=1
  fi
}

check "docker service active"        systemctl is-active --quiet docker
check "ollama service active"        systemctl is-active --quiet ollama
check "nginx service active"         systemctl is-active --quiet nginx

# One ollama list call, reused for all model checks below instead of one
# round-trip to the daemon per model.
OLLAMA_MODEL_LIST="$(ollama list 2>/dev/null || true)"
check_model() {
  local label="$1" pattern="$2"
  if grep -q "$pattern" <<<"$OLLAMA_MODEL_LIST"; then
    echo "  ✅ $label"
  else
    echo "  ❌ $label"
    FAILED=1
  fi
}
check_model "ollama: smollm2"              "^smollm2"
check_model "ollama: qwen3:0.6b"           "^qwen3:0.6b"
check_model "ollama: llama-guard3:1b-q3_K_S" "^llama-guard3:1b-q3_K_S"
check_model "ollama: llama3.1"             "^llama3.1"
check_model "ollama: SmolLM-Jailbroken"    "SmolLM-135M-Instruct-Jailbroken"
check_model "ollama: jailbroken-llama"     "^jailbroken-llama"
check_model "ollama: vulnerable-llama"     "^vulnerable-llama"

# Python interpreters may come from apt OR from uv's standalone builds
# (see section 2/4), so check both sources before calling one missing.
check_python() {
  local ver="$1"
  if command -v "python${ver}" >/dev/null 2>&1; then
    echo "  ✅ python${ver} (apt)"
  elif sudo -u "$TARGET_USER" bash -lc "source \"\$HOME/.local/bin/env\" 2>/dev/null; uv python find ${ver}" >/dev/null 2>&1; then
    echo "  ✅ python${ver} (uv)"
  else
    echo "  ❌ python${ver}"
    FAILED=1
  fi
}
check_python 3.10
check_python 3.12
check_python 3.13

if [[ "$FAILED" -eq 1 ]]; then
  echo ""
  echo "⚠️  Setup finished but one or more checks above FAILED — scroll up for the ⚠️ warnings, fix those, then re-run this script (it's idempotent)."
  exit 1
else
  echo ""
  echo "✅ Setup complete for user: $TARGET_USER — all checks passed."
fi
