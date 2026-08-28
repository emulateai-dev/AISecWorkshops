#!/usr/bin/env python3
"""TAP with per-call tracing.

garak's built-in TAP is almost silent: it emits one tqdm bar over the tree
depth and two DEBUG lines per iteration. It never shows the candidate prompts,
the judge scores, or the target's replies -- so a run that is working and a run
that is quietly getting nowhere look identical, and a silent capture failure
looks exactly like a robust target.

This driver calls garak.resources.tap.run_tap directly with all three
generators wrapped, so every exchange is printed live AND written to
tap_trace.<level>.jsonl for later inspection. The three roles and their models
are read from the chosen config:

  attacker   proposes / refines a jailbreak, emits {"improvement","prompt"} JSON
  evaluator  scores each candidate 1-10 and does the on-topic check (drives pruning)
  target     the model under test (black-box)

usage:
  ./tap_trace.py                       # defaults to configs/tap.lite.yaml
  ./tap_trace.py openai                # -> configs/tap.openai.yaml
  ./tap_trace.py smoke|lite|full|deep  # any bundled level
  ./tap_trace.py configs/tap.openai.yaml [target-model]
  ./tap_trace.py path/to/other.yaml

env overrides: TAP_TARGET, TAP_ATTACKER, TAP_EVALUATOR
keys: OpenAI attacker/evaluator need OPENAI_API_KEY; :cloud targets need
      `ollama signin` or OLLAMA_API_KEY.
"""

import json
import os
import re
import shutil
import sys
import time
from pathlib import Path


def _reexec_under_garak_python():
    """garak is usually installed as an isolated tool (uv tool / pipx), so the
    system python3 that launches this script cannot import it. Find the
    interpreter behind the `garak` CLI and re-exec ourselves under it."""
    exe = shutil.which("garak")
    if not exe:
        sys.exit("garak is not on PATH — install it, e.g. `uv tool install garak`")
    try:
        with open(exe, "rb") as fh:
            first = fh.readline().decode("utf-8", "replace").strip()
    except OSError as e:
        sys.exit(f"cannot read {exe}: {e}")
    if not first.startswith("#!"):
        sys.exit(f"{exe} is not a python entry point — run this with garak's python")
    interp = first[2:].strip().split()[-1]
    if os.path.realpath(interp) == os.path.realpath(sys.executable):
        sys.exit("garak's interpreter cannot import garak — is the install broken?")
    os.execv(interp, [interp, os.path.abspath(__file__), *sys.argv[1:]])


try:
    import garak  # noqa: F401
except ImportError:
    _reexec_under_garak_python()

import yaml

# garak requires a key to be present for any OpenAICompatible endpoint (e.g. an
# Ollama evaluator reached over /v1); Ollama itself ignores the value.
os.environ.setdefault("OPENAICOMPATIBLE_API_KEY", "ollama-local")

HERE = Path(__file__).resolve().parent
LEVELS = ("smoke", "lite", "full", "deep", "openai")


def _resolve_config(arg):
    """Map a CLI arg to (config_path, short_level_name)."""
    if arg in LEVELS:
        return HERE / "configs" / f"tap.{arg}.yaml", arg
    p = Path(arg)
    # strip a leading "tap." so configs/tap.openai.yaml -> level "openai"
    stem = p.stem[4:] if p.stem.startswith("tap.") else p.stem
    return p, stem


arg = sys.argv[1] if len(sys.argv) > 1 else "lite"
CFG, level = _resolve_config(arg)
if not CFG.is_file():
    sys.exit(
        f"no such config: {CFG}\n"
        f"usage: {Path(sys.argv[0]).name} [{'|'.join(LEVELS)}] [target-model]\n"
        f"       {Path(sys.argv[0]).name} path/to/config.yaml [target-model]"
    )

TRACE = HERE / f"tap_trace.{level}.jsonl"

cfg = yaml.safe_load(CFG.read_text())
try:
    tap = cfg["plugins"]["probes"]["tap"]["TAP"]
except (KeyError, TypeError):
    sys.exit(f"{CFG} has no plugins.probes.tap.TAP block — is this a TAP config?")

from garak import _config                                # noqa: E402
from garak.generators.base import Generator              # noqa: E402
from garak.resources.tap.tap_main import load_generator, run_tap  # noqa: E402

_config.load_config()
_config.run.generations = 1
_config.plugins.generators = _config._combine_into(
    cfg.get("plugins", {}).get("generators", {}), _config.plugins.generators
)

# apply env overrides for the two auxiliary models
tap["attack_model_name"] = os.environ.get("TAP_ATTACKER", tap["attack_model_name"])
tap["evaluator_model_name"] = os.environ.get("TAP_EVALUATOR", tap["evaluator_model_name"])

# ---------------------------------------------------------------- tracing ---

ROLES = {
    tap["attack_model_name"]: "ATTACKER",
    tap["evaluator_model_name"]: "EVALUATOR",
}
CALLS = {"n": 0}
RATINGS = []          # judge 1-10 scores, in order, for the end summary
trace_fh = TRACE.open("w", encoding="utf-8")

_RATING_RE = re.compile(r"Rating:\s*\[\[\s*(\d+(?:\.\d+)?)\s*\]\]")


def _text(x):
    """Pull plain text out of a Conversation / Message / str."""
    for attr in ("last_message", "text"):
        if hasattr(x, attr):
            v = getattr(x, attr)
            v = v() if callable(v) else v
            if isinstance(v, str):
                return v
            x = v
    if hasattr(x, "turns"):
        parts = []
        for t in x.turns:
            msg = getattr(t, "content", None) or getattr(t, "message", None)
            parts.append(getattr(msg, "text", str(msg)))
        return "\n".join(parts)
    return str(x)


def _clip(s, n=400):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[:n] + f" …[+{len(s) - n} chars]"


_orig_generate = Generator.generate


def traced_generate(self, prompt, generations_this_call=1, typecheck=True):
    role = ROLES.get(getattr(self, "name", ""), "TARGET")
    CALLS["n"] += 1
    seq = CALLS["n"]
    t0 = time.time()
    try:
        out = _orig_generate(self, prompt, generations_this_call, typecheck)
        err = None
    except Exception as e:                                   # noqa: BLE001
        out, err = [], f"{type(e).__name__}: {e}"
        raise
    finally:
        dt = time.time() - t0
        sent = _text(prompt)
        got = " | ".join(_text(o) for o in (out or []) if o is not None)
        # surface a judge rating inline and record it for the summary
        badge = ""
        if role == "EVALUATOR":
            m = _RATING_RE.search(got or "")
            if m:
                score = float(m.group(1))
                RATINGS.append(score)
                badge = f"  ⟶ score {m.group(1)}/10"
        print(f"\n[{seq:03d}] {role:9s} {getattr(self, 'name', '?'):26s} {dt:6.1f}s{badge}",
              flush=True)
        print(f"      → {_clip(sent)}", flush=True)
        print(f"      ← {_clip(got) if not err else 'ERROR ' + err}", flush=True)
        trace_fh.write(json.dumps({
            "seq": seq, "role": role, "model": getattr(self, "name", None),
            "seconds": round(dt, 2), "sent": sent, "received": got, "error": err,
        }) + "\n")
        trace_fh.flush()
    return out


Generator.generate = traced_generate

# ------------------------------------------------------------------- run ---

target_name = (
    sys.argv[2] if len(sys.argv) > 2
    else os.environ.get("TAP_TARGET", "gpt-oss:120b-cloud")
)
target_type = cfg.get("plugins", {}).get("_target_type", "ollama.OllamaGeneratorChat")

# Build the target the way TAP builds its own generators, so the model name is
# set at construction time (the generators require it there).
target = load_generator(
    target_type,
    target_name,
    cfg.get("plugins", {}).get("generators", {}).get(target_type.split(".")[0], {}),
)

print(f"level     {level}   ({CFG})")
print(f"target    {target_name}  ({target_type})")
print(f"attacker  {tap['attack_model_name']}  ({tap['attack_model_type']})")
print(f"evaluator {tap['evaluator_model_name']}  ({tap['evaluator_model_type']})")
print(f"tree      branching={tap['branching_factor']} width={tap['width']} "
      f"depth={tap['depth']} keep_last_n={tap.get('keep_last_n', 1)} pruning={tap['pruning']}")
print(f"goal      {tap['goal_str']}")
print(f"trace     {TRACE}\n" + "-" * 78, flush=True)

t_start = time.time()
try:
    jailbreaks = run_tap(
        goal=tap["goal_str"],
        target=tap["target"],
        target_generator=target,
        attack_model_type=tap["attack_model_type"],
        attack_model_name=tap["attack_model_name"],
        attack_model_config=tap.get("attack_model_config", {}),
        attack_max_attempts=tap.get("attack_max_attempts", 3),
        evaluator_model_type=tap["evaluator_model_type"],
        evaluator_model_name=tap["evaluator_model_name"],
        evaluator_model_config=tap.get("evaluator_model_config", {}),
        branching_factor=tap["branching_factor"],
        width=tap["width"],
        depth=tap["depth"],
        n_streams=tap.get("n_streams", 1),
        keep_last_n=tap.get("keep_last_n", 1),
        pruning=tap.get("pruning", True),
    )
finally:
    trace_fh.close()

print("\n" + "=" * 78)
print(f"elapsed {time.time() - t_start:.0f}s over {CALLS['n']} model calls")
if RATINGS:
    esc = " → ".join(str(int(s) if s.is_integer() else s) for s in RATINGS[:24])
    print(f"judge scores ({len(RATINGS)}): {esc}{' …' if len(RATINGS) > 24 else ''}")
    print(f"best score reached: {max(RATINGS):g}/10")
if jailbreaks:
    print(f"\n✅ {len(jailbreaks)} jailbreak(s) found — judge scored 10/10:\n")
    for j in jailbreaks:
        print("  • " + _clip(j, 600) + "\n")
else:
    print("\nno jailbreaks found (no candidate reached 10/10).")
    print("TAP only returns a prompt on a perfect 10/10; anything less yields an")
    print("empty list, which garak turns into zero attempts (`ok on 0/ 0`). That is")
    print(f"a null result, not a crash — read {TRACE.name} for the full transcript.")
