#!/usr/bin/env bash
#
# Install (or remove) the custom bias probe + detector into the running garak.
#
# garak discovers plugins by listing the .py files inside its own package
# directory, so a custom plugin has to live there. This script finds that
# directory for whichever garak is on your PATH and copies the two modules in.
#
# garak caches its plugin index, but the cache self-invalidates: it compares the
# files on disk against the cached entries and rebuilds when they differ. So do
# NOT delete resources/plugin_cache.json by hand — garak asserts that file exists
# and will crash on every run if it is missing.
#
#   ./install-plugins.sh            # install / refresh
#   ./install-plugins.sh --remove   # uninstall
#   ./install-plugins.sh --where    # just print the target directory
#   ./install-plugins.sh --python   # print garak's interpreter (for validate-detector.py)
#
set -euo pipefail
cd "$(dirname "$0")"

GARAK_BIN="$(command -v garak || true)"
[[ -n "$GARAK_BIN" ]] || { echo "error: garak not on PATH (try: uv tool install garak)" >&2; exit 1; }

# Ask garak's own interpreter where the package lives — works for uv tools,
# pipx, and plain virtualenvs alike.
PYBIN="$(dirname "$GARAK_BIN")/python"
[[ -x "$PYBIN" ]] || PYBIN="$(head -1 "$GARAK_BIN" | sed 's|^#!||')"
PKG="$("$PYBIN" -c 'import garak, pathlib; print(pathlib.Path(garak.__file__).parent)')"
[[ -d "$PKG/probes" && -d "$PKG/detectors" ]] || { echo "error: $PKG does not look like a garak package" >&2; exit 1; }

case "${1:-}" in
  --where)
    echo "$PKG"; exit 0 ;;
  --python)
    echo "$PYBIN"; exit 0 ;;
  --remove)
    rm -f "$PKG/probes/bias_dpo.py" "$PKG/detectors/bias_dpo.py"
    echo "removed bias_dpo probe + detector from $PKG"
    echo "the next garak run rebuilds its plugin index automatically"
    exit 0 ;;
esac

cp plugins/probes/bias_dpo.py     "$PKG/probes/bias_dpo.py"
cp plugins/detectors/bias_dpo.py  "$PKG/detectors/bias_dpo.py"

echo "installed into $PKG"
echo "  probes/bias_dpo.py"
echo "  detectors/bias_dpo.py"
echo "the next garak run rebuilds its plugin index (a few seconds), then:"
echo "  garak --plugin_info probes.bias_dpo.BiasDPO"
