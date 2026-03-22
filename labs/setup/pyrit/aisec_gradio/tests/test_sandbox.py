"""Unit tests for subprocess Python sandbox."""

from __future__ import annotations

from aisec_gradio.agent.sandbox import SandboxPolicy, run_python_sandbox


def test_sandbox_prints_stdout():
    r = run_python_sandbox("print('hello')", SandboxPolicy(timeout_sec=10))
    assert r.exit_code == 0
    assert "hello" in r.combined_text


def test_sandbox_timeout():
    r = run_python_sandbox("while True:\n    pass", SandboxPolicy(timeout_sec=1))
    assert r.exit_code == -1
    assert "Timed out" in r.combined_text


def test_sandbox_truncates_long_output():
    policy = SandboxPolicy(timeout_sec=10, max_output_chars=200)
    r = run_python_sandbox("print('x' * 5000)", policy)
    assert len(r.combined_text) <= 250  # truncated + marker
    assert "truncated" in r.combined_text.lower()


def test_sandbox_nonzero_exit_surfaces_stderr():
    r = run_python_sandbox(
        "import sys; sys.stderr.write('oops'); sys.exit(2)",
        SandboxPolicy(timeout_sec=10),
    )
    assert r.exit_code == 2
    assert "oops" in r.combined_text
    assert "`2`" in r.combined_text or "2" in r.combined_text
