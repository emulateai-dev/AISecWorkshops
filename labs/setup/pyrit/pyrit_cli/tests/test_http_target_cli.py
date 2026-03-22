from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock

import pytest

from pyrit_cli.redteam.http_target_cli import (
    build_http_objective_target,
    parse_http_response_parser,
)
from pyrit_cli.redteam.red_teaming import build_redteam_converter_config


def test_parse_json_parser() -> None:
    fn = parse_http_response_parser("json:choices[0].message.content", regex_base_url=None)
    mock = MagicMock()
    mock.content = b'{"choices":[{"message":{"content":"hi"}}]}'
    assert fn(response=mock) == "hi"


def test_parse_regex_parser() -> None:
    fn = parse_http_response_parser(r"regex:hello\s+\w+", regex_base_url=None)
    mock = MagicMock()
    mock.content = "prefix hello world suffix"
    out = fn(response=mock)
    assert "hello world" in out


def test_jq_parser_requires_binary(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("pyrit_cli.redteam.http_target_cli.shutil.which", lambda _: None)
    with pytest.raises(ValueError, match="jq"):
        parse_http_response_parser("jq:.a", regex_base_url=None)


def test_build_http_target_from_file(tmp_path: Path) -> None:
    req = tmp_path / "x.req"
    req.write_text(
        "POST /v1/chat HTTP/1.1\nHost: example.com\nContent-Type: application/json\n\n"
        '{"x":"{PROMPT}"}',
        encoding="utf-8",
    )
    t = build_http_objective_target(
        request_path=req,
        response_parser_spec="json:answer",
        prompt_placeholder="{PROMPT}",
        regex_base_url=None,
        use_tls=True,
        timeout=5.0,
        model_name="t",
    )
    assert "example.com" in t.http_request
    assert t.callback_function is not None


def test_build_redteam_converter_json_escape_conflicts_request() -> None:
    with pytest.raises(ValueError, match="Cannot combine"):
        build_redteam_converter_config(
            http_json_body_converter=True,
            request_converter_keys=["base64"],
            response_converter_keys=[],
        )


def test_build_redteam_converter_json_escape_plus_response() -> None:
    cfg = build_redteam_converter_config(
        http_json_body_converter=True,
        request_converter_keys=[],
        response_converter_keys=["rot13"],
    )
    assert cfg is not None
    assert cfg.request_converters
    assert cfg.response_converters
