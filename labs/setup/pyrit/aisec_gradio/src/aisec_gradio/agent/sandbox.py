"""Run arbitrary Python in a subprocess (never exec in the Gradio process)."""

from __future__ import annotations

import os
import queue
import subprocess
import sys
import tempfile
import threading
import time
from collections.abc import Iterator
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


def _sandbox_env(policy: SandboxPolicy) -> dict[str, str]:
    env = os.environ.copy()
    env["AISEC_SANDBOX"] = "1"
    env["AISEC_SANDBOX_ALLOW_NETWORK"] = "1" if policy.allow_network else "0"
    if not policy.allow_network:
        env.pop("HTTP_PROXY", None)
        env.pop("HTTPS_PROXY", None)
        env.pop("ALL_PROXY", None)
    return env


def run_python_sandbox(code: str, policy: SandboxPolicy | dict) -> SandboxResult:
    """Execute ``code`` with ``sys.executable`` in a subprocess; capture stdout/stderr."""
    if isinstance(policy, dict):
        policy = _policy_from_dict(policy)

    max_code = int(os.environ.get("AISEC_SANDBOX_MAX_CODE_CHARS", "200000"))
    if len(code) > max_code:
        return SandboxResult(1, f"Code exceeds max length ({max_code} chars).")

    env = _sandbox_env(policy)

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


def stream_python_sandbox(code: str, policy: SandboxPolicy | dict) -> Iterator[str]:
    """Yield stdout/stderr fragments as they arrive; **return** final :class:`SandboxResult` via StopIteration.

    Uses line-oriented reads on two threads so the parent can yield to Gradio between lines.
    """
    if isinstance(policy, dict):
        policy = _policy_from_dict(policy)

    max_code = int(os.environ.get("AISEC_SANDBOX_MAX_CODE_CHARS", "200000"))
    if len(code) > max_code:
        msg = f"Code exceeds max length ({max_code} chars)."
        yield msg
        return SandboxResult(1, msg)

    env = _sandbox_env(policy)
    out_acc: list[str] = []
    err_acc: list[str] = []
    total_chars = 0
    truncated = False

    def _pump(name: str, pipe) -> None:
        try:
            for line in iter(pipe.readline, ""):
                q.put((name, line))
        finally:
            q.put((name, None))
            try:
                pipe.close()
            except Exception:
                pass

    with tempfile.TemporaryDirectory(prefix="aisec_sandbox_") as tmp:
        script = Path(tmp) / "user_code.py"
        script.write_text(code, encoding="utf-8")
        q: queue.Queue[tuple[str, str | None]] = queue.Queue()
        proc = subprocess.Popen(
            [sys.executable, str(script)],
            cwd=tmp,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env,
        )
        assert proc.stdout is not None and proc.stderr is not None
        t_out = threading.Thread(target=_pump, args=("out", proc.stdout), daemon=True)
        t_err = threading.Thread(target=_pump, args=("err", proc.stderr), daemon=True)
        t_out.start()
        t_err.start()

        deadline = time.monotonic() + policy.timeout_sec
        finished = {"out": False, "err": False}

        try:
            while True:
                if time.monotonic() > deadline:
                    proc.kill()
                    try:
                        proc.wait(timeout=5)
                    except Exception:
                        pass
                    yield f"\n\n**Timed out after {policy.timeout_sec}s.**\n"
                    break

                if proc.poll() is not None and finished["out"] and finished["err"]:
                    break

                try:
                    tag, line = q.get(timeout=0.08)
                except queue.Empty:
                    continue

                if line is None:
                    finished[tag] = True
                    continue

                if truncated:
                    continue

                total_chars += len(line)
                if total_chars > policy.max_output_chars:
                    truncated = True
                    yield "\n\n[…output truncated…]\n"
                    proc.kill()
                    try:
                        proc.wait(timeout=5)
                    except Exception:
                        pass
                    break

                if tag == "out":
                    out_acc.append(line)
                    yield line
                else:
                    err_acc.append(line)
                    yield f"\n**[stderr]** {line}"

            t_out.join(timeout=10)
            t_err.join(timeout=10)
        finally:
            if proc.poll() is None:
                proc.kill()
            try:
                proc.wait(timeout=10)
            except Exception:
                pass

        exit_code = proc.returncode if proc.returncode is not None else -1

    out_s = "".join(out_acc)
    err_s = "".join(err_acc)
    lines = [f"**exit code:** `{exit_code}`"]
    if out_s.strip():
        lines.append("**stdout:**\n```\n" + out_s.rstrip() + "\n```")
    if err_s.strip():
        lines.append("**stderr:**\n```\n" + err_s.rstrip() + "\n```")
    combined = "\n\n".join(lines)
    if len(combined) > policy.max_output_chars:
        combined = combined[: policy.max_output_chars] + "\n\n[…output truncated…]"
    return SandboxResult(exit_code, combined)


def format_sandbox_result(res: SandboxResult) -> str:
    """Markdown for chat (same as combined_text for now)."""
    return res.combined_text
