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

# Pins for the Go-based recon tools built in section 2c. Pinned so builds are
# reproducible instead of silently triggering Go's auto-toolchain-download
# (each tool's own go.mod can require a newer Go than the toolchain that
# Pre_Installation.sh installed — check GO_VERSION there before bumping any
# of these). Verified 2026-08-26: nuclei v3.11.1, httpx v1.10.0 and amass
# v5.1.1 all require go 1.26; subfinder v2.16.0 requires go 1.25.0.
HTTPX_VERSION="v1.10.0"
NUCLEI_VERSION="v3.11.1"
SUBFINDER_VERSION="v2.16.0"
AMASS_VERSION="v5.1.1"

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
# 2a) Python tools via uv (user-scope)
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  set -e
  source "$HOME/.local/bin/env"

  # Prune dangling symlinks in ~/.local/bin first. VM images built from an
  # older uv tools directory leave broken links behind (e.g. cai, cai-gif,
  # autogenstudio pointing into a ~/.local/share/uv/tools tree that no
  # longer exists). uv refuses to overwrite an existing executable path
  # even when the link is broken, and --upgrade does NOT imply --force, so
  # every install below would fail with "Executable already exists" and the
  # tool would stay permanently missing. Removing only broken links is
  # safe: a working tool never has one.
  pruned=0
  for link in "$HOME/.local/bin"/*; do
    if [ -L "$link" ] && [ ! -e "$link" ]; then
      rm -f "$link"; pruned=$((pruned+1))
    fi
  done
  [ "$pruned" -gt 0 ] && echo "ℹ️  Removed $pruned dangling symlink(s) from ~/.local/bin." || true

  # uv tool install is idempotent — upgrades if already installed
  uv tool install --upgrade "dtx[torch]>=0.26.0"
  uv tool install --upgrade "garak"
  uv tool install --upgrade "huggingface_hub[cli,torch]"
  # Moved here from Pre_Installation.sh — these are lab tools, not runtimes,
  # so they belong in the re-runnable tool layer.
  uv tool install --upgrade "cai-framework"
  uv tool install --upgrade "autogenstudio"
'

# ============================================================
# 2b) Node tools (user-scope) — promptfoo, used in the day-1 LLM labs.
#     Moved here from Pre_Installation.sh; Node itself is installed there
#     via asdf, so this only fails if that step never ran.
# ============================================================
sudo -u "$TARGET_USER" bash -lc '
  set -e
  # `&& .` alone would return 1 when the file is absent and `set -e` would
  # kill this block before the friendlier check below can report why.
  [ -f "$HOME/.asdf/asdf.sh" ] && . "$HOME/.asdf/asdf.sh" || true
  if ! command -v npm >/dev/null 2>&1; then
    echo "⚠️  npm not found — run Pre_Installation.sh first (it installs Node via asdf). Skipping promptfoo."
    exit 0
  fi
  npm install -g promptfoo
  command -v asdf >/dev/null 2>&1 && asdf reshim nodejs || true
  echo "✅ promptfoo installed: $(promptfoo --version 2>/dev/null || echo unknown)"
'

# ============================================================
# 2c) Go recon tools (user-scope) — httpx, nuclei, subfinder, amass.
#     Moved here from Pre_Installation.sh so they can be re-pinned and
#     refreshed without re-running the whole system-level script.
# ============================================================
sudo -u "$TARGET_USER" bash -lc "
  set -e
  [ -f \"\$HOME/.asdf/asdf.sh\" ] && . \"\$HOME/.asdf/asdf.sh\" || true
  if ! command -v go >/dev/null 2>&1; then
    echo '⚠️  go not found — run Pre_Installation.sh first (it installs the Go toolchain via asdf). Skipping recon tools.'
    exit 0
  fi
  export GOBIN=\"\$HOME/.local/bin\"
  mkdir -p \"\$GOBIN\"
  export PATH=\"\$GOBIN:\$PATH\"

  # Each go install recompiles from source — amass alone takes minutes — so
  # skip any tool already built at the pinned version. go version -m reads
  # the version stamped into the binary, which is authoritative even when
  # the tool's own --version output is formatted differently.
  install_go_tool() {
    local bin=\"\$1\" want=\"\$2\" pkg=\"\$3\"
    local have=''
    if [ -x \"\$GOBIN/\$bin\" ]; then
      have=\"\$(go version -m \"\$GOBIN/\$bin\" 2>/dev/null | awk '/	mod	/{print \$3; exit}')\"
    fi
    if [ \"\$have\" = \"\$want\" ]; then
      echo \"ℹ️  \$bin already at \$want — skipping build.\"
      return 0
    fi
    echo \"➡️  Building \$bin \$want (found: \${have:-none})...\"
    shift 3
    env \"\$@\" go install -v \"\$pkg@\$want\"
  }

  install_go_tool httpx     $HTTPX_VERSION     github.com/projectdiscovery/httpx/cmd/httpx
  install_go_tool nuclei    $NUCLEI_VERSION    github.com/projectdiscovery/nuclei/v3/cmd/nuclei
  install_go_tool subfinder $SUBFINDER_VERSION github.com/projectdiscovery/subfinder/v2/cmd/subfinder
  install_go_tool amass     $AMASS_VERSION     github.com/owasp-amass/amass/v5/cmd/amass CGO_ENABLED=0
  echo '✅ Recon tools present in '\"\$GOBIN\"
"

# ============================================================
# 3) Ollama service + base models
# ============================================================
# Pre_Installation.sh owns the full model set (including the 4.9GB
# jailbroken-llama GGUF and its vulnerable-llama alias). But the pre-built
# VM path — Option A in README.md — runs ONLY this script, never
# Pre_Installation.sh, so a model set that lives exclusively there leaves
# every Option A attendee without the models the day-1 labs need.
#
# The pulls below are therefore repeated here, but guarded: each is a
# no-op when the model is already present, so on the Option B path (where
# Pre_Installation.sh ran first) this section costs nothing. The two large
# derived models stay in Pre_Installation.sh only — see the note further
# down in section 14.
systemctl enable ollama || true
systemctl start  ollama || true

if command -v ollama >/dev/null 2>&1; then
  pull_if_missing() {
    local model="$1"
    if ollama list 2>/dev/null | grep -q "^${model}"; then
      echo "ℹ️  Model '${model}' already present — skipping pull."
    else
      echo "➡️  Pulling '${model}'..."
      ollama pull "${model}" || echo "⚠️  Failed to pull '${model}' — skipping."
    fi
  }
  pull_if_missing smollm2
  pull_if_missing qwen3:0.6b
  pull_if_missing llama-guard3:1b-q3_K_S
  pull_if_missing llama3.1
  # Jailbroken SmolLM (135M, HF-hosted GGUF) used by the uncensored_models
  # and safety_alignment labs. NOTE: a DIFFERENT model from the
  # jailbroken-llama / vulnerable-llama pair — same word "jailbroken" in
  # the docs, two unrelated models. Do not conflate them.
  pull_if_missing hf.co/detoxio-test/SmolLM-135M-Instruct-Jailbroken_GGUF
else
  echo "⚠️  ollama not installed — skipping model pulls. Run Pre_Installation.sh first."
fi

# ============================================================
# 4) Secrets dir + export API keys via user's .bashrc
# ============================================================
# Created here as well as in Pre_Installation.sh, for the same reason as
# the models above: the Option A (pre-built VM) path runs only this
# script, and without these files the export block below silently exports
# nothing — which is how a VM ends up with no OPENAI_API_KEY, no
# GROQ_API_KEY and rate-limited HuggingFace pulls. mkdir/touch are no-ops
# when the files already exist, so real keys are never overwritten.
SECRETS_DIR="$TARGET_HOME/.secrets"
mkdir -p "$SECRETS_DIR"
touch "$SECRETS_DIR/OPENAI_API_KEY.txt"
touch "$SECRETS_DIR/GROQ_API_KEY.txt"
touch "$SECRETS_DIR/HF_TOKEN.txt"
# These hold API keys and the VM ships with default creds (dtx:dtx).
chmod 700 "$SECRETS_DIR"
chmod 600 "$SECRETS_DIR"/*.txt
chown -R "$TARGET_USER:$TARGET_USER" "$SECRETS_DIR"

# Tell the user which keys are still blank, rather than letting the labs
# fail later with an opaque auth error.
for KEYFILE in OPENAI_API_KEY GROQ_API_KEY HF_TOKEN; do
  if [ -s "$SECRETS_DIR/$KEYFILE.txt" ]; then
    echo "  ✅ $KEYFILE is set"
  else
    echo "  ⚠️  $KEYFILE is EMPTY — add it with:  echo '<your key>' > ~/.secrets/$KEYFILE.txt"
  fi
done

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
  # PyRIT and pyrit_cli are git submodules — a plain clone leaves both
  # directories empty, which silently breaks the day-1 PyRIT labs. Init them
  # here so a fresh clone is immediately usable. Safe to re-run.
  cd AISecWorkshops
  git submodule update --init --recursive
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
  # CPU-only PyTorch. The default index pulls ~2.5GB of CUDA wheels that are
  # dead weight on a VM with no GPU — keep the CPU index pinned here.
  pip install --index-url https://download.pytorch.org/whl/cpu torch torchvision torchaudio
  pip install --upgrade nltk transformers datasets
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

# Listening on 0.0.0.0 is pointless if the firewall never opens the port —
# open it here so this step is self-sufficient (labs/setup/scripts/tools/
# open_ufw_ports.sh and the VirtualBox NAT list in labs/setup/vm/README.md
# also include 11434 for VMs that configure the firewall separately).
if command -v ufw >/dev/null 2>&1; then
  ufw allow 11434/tcp || true
fi
echo "✅ Ollama configured to listen on 0.0.0.0 (port 11434 opened in ufw if present)"

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
  # NOTE: this image is NOT required for the day-1 PyRIT labs — those use
  # pyrit-cli (section 13b). Only the PyRIT notebook/devcontainer workflow
  # needs it, so a failure here is a warning, not a blocker.
  if docker build \
       -f "$PYRIT_DIR/PyRIT/.devcontainer/Dockerfile" \
       -t pyrit-devcontainer \
       "$PYRIT_DIR/PyRIT/.devcontainer" > /tmp/pyrit-devcontainer-build.log 2>&1; then
    echo "✅ pyrit-devcontainer image built."
  else
    echo "⚠️  PyRIT devcontainer build FAILED — full log: /tmp/pyrit-devcontainer-build.log"
    if grep -q "EBADENGINE\|notsup" /tmp/pyrit-devcontainer-build.log 2>/dev/null; then
      echo "   Cause: the PyRIT Dockerfile installs Node 20 and then 'npm install -g npm@latest'."
      echo "   npm 12 dropped Node 20 support, so that line now fails for everyone."
      echo "   Fix belongs upstream in jitendra-eai/PyRIT (.devcontainer/Dockerfile): pin"
      echo "   'npm@10' or move the base image to Node 22+."
    else
      echo "   Check whether docker is running: systemctl status docker"
    fi
    echo "   This does NOT block the day-1 labs — those use pyrit-cli, not this image."
  fi
fi
echo "✅ PyRIT setup complete — repo: $PYRIT_DIR/PyRIT"

# ============================================================
# 13b) pyrit-cli (user-scope) — the terminal tool used in the day-1
#      jailbreak labs. Installed editable from the repo submodule so
#      `git pull` + `make submodules-update` refreshes it in place.
#      HuggingFace `datasets` (needed by the `--dataset hf:…` benchmark
#      labs) is a core dependency of pyrit_cli — there is no [hf] extra.
# ============================================================
PYRIT_CLI_DIR="$TARGET_HOME/labs/AISecWorkshops/labs/setup/pyrit/pyrit_cli"
if [ -f "$PYRIT_CLI_DIR/pyproject.toml" ]; then
  sudo -u "$TARGET_USER" bash -lc "
    set -e
    source \"\$HOME/.local/bin/env\"
    cd '$PYRIT_CLI_DIR'
    # Editable install: the code is linked live from the submodule, so a
    # `git pull` there is picked up without reinstalling. Only install when
    # missing; re-run with --force by hand if the submodule's dependencies
    # change (uv tool install --editable --force '.').
    if command -v pyrit-cli >/dev/null 2>&1; then
      echo \"ℹ️  pyrit-cli already installed — skipping (editable install tracks the submodule).\"
    else
      uv tool install --editable '.'
    fi
    mkdir -p \"\$HOME/.pyrit\"
    touch \"\$HOME/.pyrit/.env\" \"\$HOME/.pyrit/.env.local\"
  " && echo "✅ pyrit-cli installed (editable from submodule)." \
    || echo "⚠️  pyrit-cli install failed — check output above."
else
  echo "⚠️  pyrit_cli submodule is empty at $PYRIT_CLI_DIR — run 'git submodule update --init --recursive' in the repo, then re-run this script."
fi

# ============================================================
# 14) Vulnerable / jailbroken Llama model
# ============================================================
# The vulnerable_llama_model dataset clone plus the jailbroken-llama /
# vulnerable-llama Ollama registration now happen in Pre_Installation.sh
# (single source of truth — see that script's "Ollama models" section).
# Nothing to do here. install-dvmcp.sh still checks for the local clone
# at $TARGET_HOME/labs/datasets/vulnerable_llama_model and falls back to
# its own HF pull if it isn't there, so it works either way.

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
# install_lab install-dtx-demo-agents.sh               "DTX Demo Agents"

# Idempotent — a bare append would add a duplicate line on every re-run.
if grep -qE '^127\.0\.0\.1[[:space:]]+emulateai-mcp\.local$' /etc/hosts; then
  echo "ℹ️  /etc/hosts entry for emulateai-mcp.local already present — skipping."
else
  echo '127.0.0.1 emulateai-mcp.local' >> /etc/hosts
  echo "✅ Added emulateai-mcp.local to /etc/hosts"
fi

# ============================================================
# Done
# ============================================================
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.aisecurity" || true
echo "✅ Post-setup complete for $TARGET_USER"

