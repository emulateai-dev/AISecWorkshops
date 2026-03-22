"""Load per-assignment reference text for the LangGraph system prompt."""

from __future__ import annotations

from aisec_gradio.builtin_sample_code import (
    BUILTIN_DATASETS_SAMPLE,
    DATASET_WRITING_SAMPLE,
    OPENAI_CHAT_TARGET_SAMPLE,
    SEED_PROGRAMMING_SAMPLE,
)
from aisec_gradio.content_loader import load_content_markdown
from aisec_gradio.workshop_registry import assignment_by_ids, parse_assignment_key

CONTEXT_BUDGET_DEFAULT = 80_000


def load_assignment_context(assignment_key: str, *, budget: int = CONTEXT_BUDGET_DEFAULT) -> str:
    """Concatenate summary + reference files + bundled Python for select assignments."""
    try:
        sid, aid = parse_assignment_key(assignment_key)
    except ValueError:
        return ""
    meta = assignment_by_ids(sid, aid)
    if not meta:
        return ""

    chunks: list[str] = []
    summary = load_content_markdown(meta["summary_relpath"])
    chunks.append(f"## Assignment summary (`{meta['summary_relpath']}`)\n\n{summary}")

    for rel in meta.get("reference_files") or []:
        body = load_content_markdown(rel)
        chunks.append(f"## Reference: `{rel}`\n\n{body}")

    if assignment_key == "datasets:builtin":
        chunks.append("## Bundled sample code (Python)\n\n```python\n" + BUILTIN_DATASETS_SAMPLE.strip() + "\n```")
    elif assignment_key == "prompt_targets:openai_chat":
        chunks.append(
            "## Bundled sample code (Python)\n\n```python\n" + OPENAI_CHAT_TARGET_SAMPLE.strip() + "\n```"
        )
    elif assignment_key == "datasets:seed_programming":
        chunks.append("## Bundled sample code (Python)\n\n```python\n" + SEED_PROGRAMMING_SAMPLE.strip() + "\n```")
    elif assignment_key == "datasets:dataset_writing":
        chunks.append("## Bundled sample code (Python)\n\n```python\n" + DATASET_WRITING_SAMPLE.strip() + "\n```")

    text = "\n\n---\n\n".join(chunks)
    if len(text) > budget:
        return text[:budget] + "\n\n[…context truncated…]"
    return text
