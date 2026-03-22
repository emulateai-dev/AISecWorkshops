# pyrit-cli documentation

Workshop-oriented guides for the CLI. **Authoritative flag and env reference:** bundled [HELP.md](../src/pyrit_cli/HELP.md) (also used by `ask-ai`).

## Reading order (basic → advanced)

| Order | Guide | What you learn |
|-------|--------|----------------|
| 1 | [Workshop track](workshop-track.md) | Install → setup → discover → red team (single-turn → multi-turn → HTTP → TAP) → `ask-ai` (simple → HTTP file hints) |

## Adding more guides later

1. Add a new Markdown file in this directory (e.g. `scoring-deep-dive.md`, `02-custom-targets.md`).
2. Link it from this **README** in a new row in the table above (or a new subsection).
3. Keep one **canonical** reference for flags: [HELP.md](../src/pyrit_cli/HELP.md). Long guides should explain *when* and *why*; HELP stays the *what* for every option.

**Naming suggestions**

- `workshop-track.md` — linear path for new users (current).
- `topic-<name>.md` — focused deep dives.
- `lab-<n>-<title>.md` — per-lab handouts.

## Related links

- Package overview: [README.md](../README.md) (short copy-paste examples).
- PyRIT library: [https://azure.github.io/PyRIT/](https://azure.github.io/PyRIT/)

Use only on targets and data you are allowed to test.
