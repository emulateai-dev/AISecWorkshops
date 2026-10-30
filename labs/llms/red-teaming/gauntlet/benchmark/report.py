"""Render benchmark results: MSC heatmap, difficulty index, technique power, turns."""
from __future__ import annotations
import json
from pathlib import Path
HERE = Path(__file__).resolve().parent
import sys; sys.path.insert(0, str(HERE))
import complexity


def _msc(cell_techs, tau):
    """(min_tier_rank, solver_id, min_turns) over techniques that solve a cell."""
    best = None
    for tid, d in cell_techs.items():
        if d.get("skipped") or d.get("rate", 0) < tau:
            continue
        r = complexity.rank(d["tier"])
        if best is None or r < best[0] or (r == best[0] and (d.get("min_turns") or 9) < (best[2] or 9)):
            best = (r, tid, d.get("min_turns"))
    return best


def render(data, out_path):
    meta, res = data["meta"], data["results"]
    levels, chs, tau = meta["levels"], meta["challenges"], meta["tau"]
    L = ["# 📊 The Gauntlet — Benchmark Results",
         "",
         f"Model path: `{meta['base']}` · k={meta['k']} trials/cell · τ={tau} (cell solved if success-rate ≥ τ) · "
         f"tiers ≤ {meta['max_tier']} · prune={meta['prune']} · {meta['total_trials']} model trials.",
         "",
         "**MSC = Minimum Solving Complexity**: the simplest technique tier that solves a cell "
         "(C0 trivial → C4 expert/multi-turn). `✗` = unsolved by catalogued techniques.",
         "", "## Minimum Solving Complexity (challenge × level)", ""]

    # heatmap
    hdr = "| challenge | " + " | ".join(levels) + " |"
    sep = "|" + "---|" * (len(levels) + 1)
    L += [hdr, sep]
    diff_index = {}
    for ch in chs:
        row = [ch]
        total = 0
        for lvl in levels:
            m = _msc(res[ch][lvl], tau)
            if m is None:
                row.append("✗"); total += len(complexity.TIERS)
            else:
                tier = complexity.TIERS[m[0]]
                turns = m[2]
                row.append(f"{tier}" + (f" ({turns}t)" if turns and turns > 1 else ""))
                total += m[0]
        diff_index[ch] = total
        L.append("| " + " | ".join(row) + " |")
    L += ["", "_Cell shows the easiest tier that solved it; `(Nt)` = turns needed (multi-turn)._", ""]

    # difficulty index
    L += ["## Challenge difficulty index", "", "Higher = harder (sum of MSC ranks across levels; ✗ counts max).", ""]
    L += ["| challenge | difficulty |", "|---|---|"]
    for ch in sorted(diff_index, key=lambda c: -diff_index[c]):
        L.append(f"| {ch} | {diff_index[ch]} |")
    L.append("")

    # technique power
    L += ["## Technique power", "",
          "For each technique: cells solved (rate ≥ τ) and the deepest level reached.", ""]
    pw = {}
    for ch in chs:
        for lvl in levels:
            for tid, d in res[ch][lvl].items():
                if d.get("skipped") or d.get("rate", 0) < tau:
                    pw.setdefault(tid, {"tier": d["tier"], "solved": 0, "deepest": ""})
                    continue
                e = pw.setdefault(tid, {"tier": d["tier"], "solved": 0, "deepest": ""})
                e["solved"] += 1
                if (not e["deepest"]) or levels.index(lvl) > levels.index(e["deepest"]):
                    e["deepest"] = lvl
    L += ["| technique | tier | cells solved | deepest level |", "|---|---|---|---|"]
    for tid in sorted(pw, key=lambda t: (-pw[t]["solved"], complexity.rank(pw[t]["tier"]))):
        e = pw[tid]
        L.append(f"| {tid} | {e['tier']} | {e['solved']} | {e['deepest'] or '—'} |")
    L.append("")

    text = "\n".join(L)
    Path(out_path).write_text(text)
    print("\n" + text)
    print(f"\n[report] written to {out_path}")
    return text


if __name__ == "__main__":
    f = sys.argv[1] if len(sys.argv) > 1 else str(HERE / "benchmark_results.json")
    render(json.load(open(f)), str(HERE / "../BENCHMARK_RESULTS.md"))
