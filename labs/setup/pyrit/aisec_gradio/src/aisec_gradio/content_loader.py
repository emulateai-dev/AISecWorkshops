"""Load packaged Markdown under ``aisec_gradio/content/``."""

from __future__ import annotations

from pathlib import Path


def _content_dir() -> Path:
    return Path(__file__).resolve().parent / "content"


def load_content_markdown(relpath: str) -> str:
    """Load ``content/<relpath>`` or return a short fallback."""
    p = _content_dir() / relpath
    if p.is_file():
        return p.read_text(encoding="utf-8", errors="replace")
    return f"_(Missing workshop content file: `{relpath}`)_\n"
