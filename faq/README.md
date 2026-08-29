# Workshop FAQ

Questions that came up **during live sessions**, answered properly after the fact.

One file per month, named `YYYY-MM.md`. A question is filed under the month it was
*asked*, and the answer is written and revised in place — so the same file grows over
the month rather than being split by answer date.

> These are conceptual answers meant to be read alongside the labs. Where an answer
> depends on something you can run, it links to the lab that runs it.

---

## Index

| Month | Questions | File |
|---|---|---|
| August 2026 | 2 | [2026-08.md](./2026-08.md) |

---

## Conventions

Each month file uses the same shape:

```markdown
# FAQ — <Month Year>

| # | Question | Status |
|---|----------|--------|
| 1 | ...      | Answered |
| 2 | ...      | Open |

## 1. <Question>
*Asked: <session / date>*

<answer>

### Where this shows up in the labs
<links>
```

**Status** is one of:

| Status | Meaning |
|---|---|
| `Answered` | Written up and reviewed |
| `Draft` | Answer exists but needs a second pass |
| `Open` | Captured during the session, not yet answered |

### Adding a question

1. Open (or create) the month file for the month it was asked.
2. Add a row to the question table with status `Open`.
3. Write the answer under a matching `## <n>. <question>` heading; flip the status.
4. Bump the count in the index table above.

Keep questions in the words they were asked in — the phrasing is part of the record of
what was actually unclear.
