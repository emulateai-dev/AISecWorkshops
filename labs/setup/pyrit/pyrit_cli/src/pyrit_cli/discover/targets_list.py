"""CLI-supported targets vs PyRIT library targets."""

from __future__ import annotations

_SUPPORTED = [
    ("openai:<model>", "OpenAI-compatible chat (OpenAIChatTarget). Uses OPENAI_CHAT_* from ~/.pyrit."),
]

_NOT_EXPOSED = [
    "AzureMLChatTarget",
    "HuggingFaceChatTarget",
    "HuggingFaceEndpointTarget",
    "OpenAIImageTarget",
    "OpenAICompletionTarget",
    "TextTarget",
    "HTTPTarget",
    "HTTPXAPITarget",
    "PlaywrightTarget",
    "GandalfTarget",
    "CrucibleTarget",
    "... see pyrit.prompt_target",
]


def list_targets_text() -> str:
    lines = [
        "Supported by pyrit-cli (use with --target / --objective-target / --adversarial-target):",
        "-" * 60,
    ]
    for pat, note in _SUPPORTED:
        lines.append(f"  {pat}")
        lines.append(f"      {note}")
    lines.append("")
    lines.append("Not yet exposed via CLI (available in PyRIT library):")
    lines.append("-" * 60)
    for n in _NOT_EXPOSED:
        lines.append(f"  {n}")
    return "\n".join(lines)
