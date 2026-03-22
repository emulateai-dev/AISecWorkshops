"""Read/write ~/.pyrit/.env and .env.local with merge + atomic save."""

from __future__ import annotations

import os
import re
import tempfile
from pathlib import Path
from typing import Literal

ConnectionMode = Literal["openai_native", "openai_compatible"]

_SENSITIVE = re.compile(r"(KEY|TOKEN|SECRET|PASSWORD|API_KEY)", re.I)


def pyrit_dir() -> Path:
    override = os.environ.get("PYRIT_ENV_DIR", "").strip()
    if override:
        return Path(override).expanduser()
    return Path.home() / ".pyrit"


def env_path(name: str) -> Path:
    return pyrit_dir() / name


def ensure_pyrit_dir() -> Path:
    d = pyrit_dir()
    d.mkdir(parents=True, exist_ok=True)
    for f in (".env", ".env.local"):
        p = d / f
        if not p.exists():
            p.touch()
    return d


def parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, _, v = line.partition("=")
            k, v = k.strip(), v.strip().strip('"').strip("'")
            out[k] = v
    return out


def mask_value(key: str, value: str) -> str:
    if _SENSITIVE.search(key) and value:
        if len(value) <= 8:
            return "****"
        return value[:4] + "…" + value[-2:]
    return value


def merge_write(path: Path, updates: dict[str, str], *, remove_keys: frozenset[str] | None = None) -> None:
    """Merge updates into existing env file; optionally remove keys."""
    existing = parse_env_file(path)
    if remove_keys:
        for k in remove_keys:
            existing.pop(k, None)
    existing.update({k: v for k, v in updates.items() if v is not None})
    lines = [f'{k}="{v}"' if " " in v or "$" in v else f"{k}={v}" for k, v in sorted(existing.items())]
    _atomic_write(path, "\n".join(lines) + "\n")


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".env_", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def save_openai_native(openai_api_key: str, *, model: str = "gpt-4o") -> tuple[str, str]:
    """Write Option A: native OpenAI in ``.env`` plus ``OPENAI_CHAT_*`` in ``.env.local`` for PyRIT.

    PyRIT's ``OpenAIChatTarget`` reads ``OPENAI_CHAT_KEY`` / ``OPENAI_CHAT_ENDPOINT``,
    not ``OPENAI_API_KEY`` alone; we mirror the key and set the public API endpoint.
    """
    d = ensure_pyrit_dir()
    env_main = d / ".env"
    env_local = d / ".env.local"

    platform_keys = frozenset(
        {
            "PLATFORM_OPENAI_CHAT_ENDPOINT",
            "PLATFORM_OPENAI_CHAT_API_KEY",
            "PLATFORM_OPENAI_CHAT_GPT4O_MODEL",
        }
    )

    merge_write(env_main, {"OPENAI_API_KEY": openai_api_key.strip()}, remove_keys=platform_keys)
    merge_write(
        env_local,
        {
            "OPENAI_CHAT_ENDPOINT": "https://api.openai.com/v1",
            "OPENAI_CHAT_KEY": openai_api_key.strip(),
            "OPENAI_CHAT_MODEL": model.strip(),
        },
    )
    return f"Saved {env_main}", f"Updated {env_local} (OpenAIChatTarget mapping)"


def save_openai_compatible(
    endpoint: str,
    api_key: str,
    model: str,
) -> tuple[str, str]:
    """Write Option B: PLATFORM_* in .env and OPENAI_CHAT_* in .env.local."""
    d = ensure_pyrit_dir()
    env_main = d / ".env"
    env_local = d / ".env.local"

    main_updates = {
        "PLATFORM_OPENAI_CHAT_ENDPOINT": endpoint.strip().rstrip("/"),
        "PLATFORM_OPENAI_CHAT_API_KEY": api_key.strip(),
        "PLATFORM_OPENAI_CHAT_GPT4O_MODEL": model.strip(),
    }
    merge_write(env_main, main_updates, remove_keys=frozenset({"OPENAI_API_KEY"}))

    local_content = (
        "# Overrides for default OpenAIChatTarget (PyRIT)\n"
        'OPENAI_CHAT_ENDPOINT="${PLATFORM_OPENAI_CHAT_ENDPOINT}"\n'
        'OPENAI_CHAT_KEY="${PLATFORM_OPENAI_CHAT_API_KEY}"\n'
        f'OPENAI_CHAT_MODEL="{model.strip()}"\n'
    )
    _atomic_write(env_local, local_content)
    return f"Updated {env_main}", f"Updated {env_local}"


def load_for_ui() -> dict:
    ensure_pyrit_dir()
    main = parse_env_file(env_path(".env"))
    local = parse_env_file(env_path(".env.local"))

    if main.get("PLATFORM_OPENAI_CHAT_ENDPOINT"):
        mode: ConnectionMode = "openai_compatible"
    elif main.get("OPENAI_API_KEY"):
        mode = "openai_native"
    else:
        mode = "openai_compatible"

    display_main = {k: mask_value(k, v) for k, v in main.items()}
    display_local = {k: mask_value(k, v) for k, v in local.items()}

    native_model = local.get("OPENAI_CHAT_MODEL") or main.get("PLATFORM_OPENAI_CHAT_GPT4O_MODEL") or "gpt-4o"

    return {
        "mode": mode,
        "openai_api_key": main.get("OPENAI_API_KEY", ""),
        "native_model": native_model,
        "endpoint": main.get("PLATFORM_OPENAI_CHAT_ENDPOINT", "https://api.groq.com/openai/v1"),
        "platform_api_key": main.get("PLATFORM_OPENAI_CHAT_API_KEY", ""),
        "model": main.get("PLATFORM_OPENAI_CHAT_GPT4O_MODEL", "qwen/qwen3-32b"),
        "display_main": display_main,
        "display_local": display_local,
    }
