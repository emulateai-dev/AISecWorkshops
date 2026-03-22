"""Run arbitrary Python in a subprocess (never exec in the Gradio process)."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol, runtime_checkable


@dataclass
class SandboxPolicy:
    timeout_sec: float = 90.0
    max_output_chars: int = 200_000
    allow_network: bool = False


@dataclass
class SandboxResult:
    exit_code: int
    combined_text: str


@runtime_checkable
class SandboxRunner(Protocol):
    """Phase-2 hook: swap subprocess for Docker/Firejail (flag-gated) without changing tools.

    Default implementation: :func:`run_python_sandbox`.
    """

    def run_python(self, code: str, policy: SandboxPolicy | dict) -> SandboxResult:
        ...


def _policy_from_dict(d: dict) -> SandboxPolicy:
    return SandboxPolicy(
        timeout_sec=float(d.get("timeout_sec", 90)),
        max_output_chars=int(d.get("max_output_chars", 200_000)),
        allow_network=bool(d.get("allow_network", False)),
    )


def run_python_sandbox(code: str, policy: SandboxPolicy | dict) -> SandboxResult:
    """Execute ``code`` with ``sys.executable`` in a subprocess; capture stdout/stderr."""
    if isinstance(policy, dict):
        policy = _policy_from_dict(policy)

    max_code = int(os.environ.get("AISEC_SANDBOX_MAX_CODE_CHARS", "200000"))
    if len(code) > max_code:
        return SandboxResult(1, f"Code exceeds max length ({max_code} chars).")

    env = os.environ.copy()
    env["AISEC_SANDBOX"] = "1"
    env["AISEC_SANDBOX_ALLOW_NETWORK"] = "1" if policy.allow_network else "0"
    if not policy.allow_network:
        env.pop("HTTP_PROXY", None)
        env.pop("HTTPS_PROXY", None)
        env.pop("ALL_PROXY", None)

    with tempfile.TemporaryDirectory(prefix="aisec_sandbox_") as tmp:
        script = Path(tmp) / "user_code.py"
        script.write_text(code, encoding="utf-8")
        try:
            proc = subprocess.run(
                [sys.executable, str(script)],
                cwd=tmp,
                capture_output=True,
                text=True,
                timeout=policy.timeout_sec,
                env=env,
            )
        except subprocess.TimeoutExpired:
            return SandboxResult(-1, f"Timed out after {policy.timeout_sec}s.")

        out = proc.stdout or ""
        err = proc.stderr or ""
        lines = [f"**exit code:** `{proc.returncode}`"]
        if out.strip():
            lines.append("**stdout:**\n```\n" + out.rstrip() + "\n```")
        if err.strip():
            lines.append("**stderr:**\n```\n" + err.rstrip() + "\n```")
        text = "\n\n".join(lines)
        if len(text) > policy.max_output_chars:
            text = text[: policy.max_output_chars] + "\n\n[…output truncated…]"
        return SandboxResult(proc.returncode, text)


def format_sandbox_result(res: SandboxResult) -> str:
    """Markdown for chat (same as combined_text for now)."""
    return res.combined_text
