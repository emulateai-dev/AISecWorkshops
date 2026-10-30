"""
The Gauntlet — FastAPI backend.

One backend, shared SQLite session store, two clients:
  • native session API  (/sessions, /chat)        -> used by the Web UI & CLI
  • OpenAI-compatible shim (/v1/chat/completions)  -> used by automation / garak

Run from the gauntlet/ directory:
    uvicorn server.app:app --host 0.0.0.0 --port 8000
"""
from __future__ import annotations
import os
import time
import uuid
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from engine import config, defenses, grader, llm
from engine.secrets import resolve_keys, readiness_table
from server import store

APP_DIR = Path(__file__).resolve().parent.parent
UI_FILE = APP_DIR / "ui" / "index.html"

app = FastAPI(title="The Gauntlet", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
def _startup() -> None:
    store.init()
    pc = config.provider_config()["provider"]
    readiness = resolve_keys(pc)
    mode = "MOCK (offline)" if llm.MOCK else "LIVE"
    print(f"\n🏰 The Gauntlet — provider: {pc['name']}  mode: {mode}")
    print("Key readiness:\n" + readiness_table(readiness) + "\n")


# ----------------------------- models -----------------------------
class NewSession(BaseModel):
    session_id: str | None = None
    challenge: str
    level: str | None = None
    overrides: dict | None = None


class ChatIn(BaseModel):
    message: str


# ----------------------------- helpers -----------------------------
_OVERRIDE_KEYS = ("system", "secret", "win", "expect", "judge_prompt", "brief", "defenses", "score", "topic", "difficulty")


def _build_spec(challenge_id: str, overrides: dict) -> dict:
    if challenge_id == "custom":
        spec = {"topic": "custom", "difficulty": "easy", "brief": "Custom challenge.", "win": "canary"}
    else:
        spec = dict(config.get_challenge(challenge_id))
    for k in _OVERRIDE_KEYS:
        if k in overrides:
            spec[k] = overrides[k]
    if challenge_id == "custom" and "system" not in spec:
        raise HTTPException(400, "custom challenge requires overrides.system")
    return spec


def _resolve_model(challenge_id: str, level: str, overrides: dict) -> str:
    if overrides.get("model"):
        return overrides["model"]
    if challenge_id != "custom":
        return config.model_for(challenge_id, level)
    return config.levels()[level]["model"]


def _run_turn(sid: str, message: str) -> dict:
    sess = store.get_session(sid)
    if not sess:
        raise HTTPException(404, f"no such session: {sid}")
    spec, model, level = sess["spec"], sess["model"], sess["level"]
    was_solved = sess["solved"]
    defs = defenses.defenses_for(spec, level)

    # input defense
    try:
        defenses.apply_input(message, defs)
    except defenses.Blocked as b:
        store.add_message(sid, "user", message)
        store.add_message(sid, "assistant", str(b))
        attempts = store.bump_attempts(sid)
        return {"reply": str(b), "won": False, "blocked": True, "attempts": attempts,
                "score": None, "total": 0, "already_solved": was_solved}

    history = store.get_messages(sid)
    msgs = [{"role": "system", "content": spec["system"]}] + history + [{"role": "user", "content": message}]
    raw = llm.complete(model, msgs)
    reply = defenses.apply_output(raw, defs, spec.get("secret"))

    store.add_message(sid, "user", message)
    store.add_message(sid, "assistant", reply)
    attempts = store.bump_attempts(sid)

    result = grader.grade(spec, reply, attempts)
    if result["won"] and not was_solved:
        finding = {
            "schema": "gauntlet.finding/v1",
            "challenge": sess["challenge"], "topic": spec.get("topic"),
            "level": level, "model": model, "attempts": attempts,
            "winning_prompt": message, "model_output": reply,
            "score": result["score"], "total": result["total"],
            "created": time.time(),
        }
        store.mark_solved(sid, result["score"], finding)
    return {"reply": reply, "won": result["won"], "blocked": False, "attempts": attempts,
            "score": result["score"], "total": result["total"], "already_solved": was_solved}


# ----------------------------- routes -----------------------------
@app.get("/challenges")
def challenges():
    return [config.public_view(cid) for cid in config.challenges()]


@app.post("/sessions")
def new_session(body: NewSession):
    overrides = body.overrides or {}
    if body.challenge != "custom" and body.challenge not in config.challenges():
        raise HTTPException(404, f"unknown challenge: {body.challenge}")
    level = body.level or (config.default_level(body.challenge) if body.challenge != "custom" else "L1")
    if level not in config.levels():
        raise HTTPException(400, f"unknown level: {level}")

    spec = _build_spec(body.challenge, overrides)
    if spec.get("agentic"):
        raise HTTPException(400, f"'{body.challenge}' is an agentic challenge — needs the tool-runtime (Phase 2).")
    model = _resolve_model(body.challenge, level, overrides)

    sid = body.session_id or f"s-{uuid.uuid4().hex[:8]}"
    if store.session_exists(sid):
        raise HTTPException(409, f"session id already exists: {sid}")
    store.create_session(sid, body.challenge, level, model, spec)

    badge = {"easy": "🟢", "medium": "🟡", "hard": "🔴"}.get(spec.get("difficulty"), "⚪")
    return {"session_id": sid, "challenge": body.challenge, "level": level,
            "model": model, "badge": badge, "brief": spec.get("brief")}


@app.get("/sessions/{sid}")
def get_session(sid: str):
    sess = store.get_session(sid)
    if not sess:
        raise HTTPException(404, f"no such session: {sid}")
    return {"session_id": sid, "challenge": sess["challenge"], "level": sess["level"],
            "model": sess["model"], "solved": sess["solved"], "attempts": sess["attempts"],
            "score": sess["score"], "brief": sess["spec"].get("brief")}


@app.post("/sessions/{sid}/chat")
def chat(sid: str, body: ChatIn):
    return _run_turn(sid, body.message)


@app.get("/sessions/{sid}/transcript")
def transcript(sid: str):
    sess = store.get_session(sid)
    if not sess:
        raise HTTPException(404, f"no such session: {sid}")
    return {"session_id": sid, "challenge": sess["challenge"], "level": sess["level"],
            "solved": sess["solved"], "messages": store.get_messages(sid),
            "finding": store.get_finding(sid)}


@app.get("/sessions")
def list_sessions():
    return store.list_sessions()


# ---- OpenAI-compatible shim: model = "session:<id>" (for garak/opencode/automation) ----
@app.post("/v1/chat/completions")
def openai_shim(body: dict):
    model = body.get("model", "")
    if not model.startswith("session:"):
        raise HTTPException(400, "model must be 'session:<id>' for the Gauntlet shim")
    sid = model.split(":", 1)[1]
    user_msgs = [m for m in body.get("messages", []) if m.get("role") == "user"]
    if not user_msgs:
        raise HTTPException(400, "no user message")
    result = _run_turn(sid, user_msgs[-1]["content"])
    suffix = f"\n\n[gauntlet] won={result['won']} attempts={result['attempts']}"
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:12]}", "object": "chat.completion",
        "created": int(time.time()), "model": model,
        "choices": [{"index": 0, "finish_reason": "stop",
                     "message": {"role": "assistant", "content": result["reply"] + suffix}}],
        "gauntlet": result,
    }


@app.get("/")
def index():
    if UI_FILE.is_file():
        return FileResponse(UI_FILE)
    return {"service": "The Gauntlet", "ui": "not built", "api": "/challenges"}
