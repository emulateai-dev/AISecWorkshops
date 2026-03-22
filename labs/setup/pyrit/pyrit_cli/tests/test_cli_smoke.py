from __future__ import annotations

from typer.testing import CliRunner

from pyrit_cli.cli import app

runner = CliRunner()


def test_version() -> None:
    r = runner.invoke(app, ["--version"])
    assert r.exit_code == 0
    assert "pyrit-cli" in r.stdout


def test_converters_list_keys() -> None:
    r = runner.invoke(app, ["converters", "list-keys"])
    assert r.exit_code == 0
    assert "base64" in r.stdout


def test_targets_list() -> None:
    r = runner.invoke(app, ["targets", "list"])
    assert r.exit_code == 0
    assert "openai:" in r.stdout


def test_datasets_list() -> None:
    r = runner.invoke(app, ["datasets", "list", "--glob", "*airt*"])
    assert r.exit_code == 0


def test_scorers_list() -> None:
    r = runner.invoke(app, ["scorers", "list"])
    assert r.exit_code == 0
    assert "self-ask-tf" in r.stdout


def test_setup_status(pyrit_env_dir) -> None:
    r = runner.invoke(app, ["setup", "status"])
    assert r.exit_code == 0
    assert "PyRIT config directory" in r.stdout


def test_red_teaming_help() -> None:
    r = runner.invoke(app, ["redteam", "red-teaming-attack", "--help"])
    assert r.exit_code == 0
    assert "objective-target" in r.stdout


def test_prompt_sending_attack_help() -> None:
    r = runner.invoke(app, ["redteam", "prompt-sending-attack", "--help"])
    assert r.exit_code == 0
    assert "--target" in r.stdout


def test_ask_ai_help() -> None:
    r = runner.invoke(
        app,
        ["ask-ai", "--help"],
        env={"COLUMNS": "200", "LINES": "60"},
    )
    assert r.exit_code == 0
    assert "query" in r.stdout.lower() or "describe" in r.stdout.lower()


def test_setup_configure_help() -> None:
    r = runner.invoke(
        app,
        ["setup", "configure", "--help"],
        env={"COLUMNS": "200", "LINES": "60"},
    )
    assert r.exit_code == 0
    assert "configure" in r.stdout.lower() or "wizard" in r.stdout.lower()


def test_tap_attack_help() -> None:
    # Rich-wrapped help truncates when COLUMNS is tiny (default in tests).
    r = runner.invoke(
        app,
        ["redteam", "tap-attack", "--help"],
        env={"COLUMNS": "200", "LINES": "60"},
    )
    assert r.exit_code == 0
    assert "objective-target" in r.stdout
    assert "tree-width" in r.stdout


def test_converters_list(pyrit_env_dir) -> None:
    r = runner.invoke(app, ["converters", "list"])
    assert r.exit_code == 0
    assert "Base64Converter" in r.stdout or "base64" in r.stdout.lower()
