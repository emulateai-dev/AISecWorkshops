# Assignment 12: HTTP Targets, Request Templates, and Parser-Driven Attacks

**Time:** ~35 minutes  
**Difficulty:** Advanced  
**Models/Targets:** Groq OpenAI-compatible REST API, Ollama REST API

---

## Objective

Learn how to run `pyrit-cli` attacks against raw HTTP APIs by:

1. Inspecting API request/response shapes first,
2. Building raw HTTP request templates with `{PROMPT}`,
3. Choosing correct `--http-response-parser` values,
4. Running attacks with HTTP victims.

Use only approved targets and instructor-approved objectives.

---

## Prerequisites

- `pyrit-cli` installed (`pyrit-cli --help`)
- `jq` installed (`jq --version`)
- Groq key in env (for Groq tests): `echo "$GROQ_API_KEY"`
- Ollama running (for local tests): `ollama list`

---

## Part A: Inspect the APIs First

Never start attacks before verifying the endpoint, auth, and response shape.

### A1) Groq (OpenAI-compatible)

```bash
curl -s https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.3-70b-versatile",
    "messages": [{"role":"user","content":"Reply with exactly: OK"}]
  }' | jq
```

Expected assistant text path is typically:

- `choices[0].message.content`

### A2) Ollama REST API

```bash
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3:0.6b",
    "messages": [{"role":"user","content":"Reply with exactly: OK"}]
  }' | jq
```

Depending on endpoint shape, parser is usually one of:

- `json:choices[0].message.content` (OpenAI-compatible shape)
- `json:message.content` (some Ollama response variants)

Record what your endpoint returns before moving on.

---

## Part B: Build Raw HTTP Templates + Parsers

`pyrit-cli` HTTP victim mode requires:

- `--http-request` (raw request template containing `{PROMPT}`)
- `--http-response-parser` (`json:...`, `regex:...`, or `jq:...`)

### B1) Example request template for Groq/OpenAI-compatible

Save as `groq_chat.req`:

```http
POST /openai/v1/chat/completions HTTP/1.1
Host: api.groq.com
Authorization: Bearer {{GROQ_API_KEY}}
Content-Type: application/json

{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"{PROMPT}"}]}
```

Parser:

- `json:choices[0].message.content`

### B2) Example request template for Ollama

Save as `ollama_chat.req`:

```http
POST /v1/chat/completions HTTP/1.1
Host: 127.0.0.1:11434
Content-Type: application/json

{"model":"qwen3:0.6b","messages":[{"role":"user","content":"{PROMPT}"}]}
```

Parser:

- try `json:choices[0].message.content` first for OpenAI-compatible route
- if empty, inspect with `curl | jq` and switch to the actual field path

---

## Part C: Run Attacks with HTTP Victims

### C1) Prompt-sending attack (HTTP victim)

```bash
pyrit-cli redteam prompt-sending-attack \
  --target http \
  --http-request ./ollama_chat.req \
  --http-response-parser json:choices[0].message.content \
  --objective "Benign instructor-approved objective text." \
  --scoring-mode configured \
  --scorer-preset self-ask-tf \
  --true-description "The assistant fully complies with the objective."
```

You can also use URL form:

- `--target https://api.groq.com/openai/v1/chat/completions`

### C2) Red-teaming attack (HTTP victim + chat adversary)

When the victim is HTTP, `--adversarial-target` must be a chat target (`openai:...`, `groq:...`, `ollama:...`, etc.).

```bash
pyrit-cli redteam red-teaming-attack \
  --objective-target http \
  --http-request ./groq_chat.req \
  --http-response-parser json:choices[0].message.content \
  --adversarial-target openai:gpt-4o-mini \
  --objective "Benign instructor-approved objective text." \
  --true-description "The assistant fully complies with the objective." \
  --max-turns 4
```

### C3) Crescendo and TAP scope notes

- `crescendo-attack`: current CLI path is chat-target focused; use chat targets directly for now.
- `tap-attack`: HTTP victims are not supported in CLI TAP mode.

Example Crescendo (chat target):

```bash
pyrit-cli redteam crescendo-attack \
  --objective-target openai:gpt-4o-mini \
  --objective "Benign instructor-approved objective text." \
  --true-description "The assistant fully complies with the objective." \
  --max-turns 6 \
  --max-backtracks 3
```

---

## Part D: Troubleshooting Checklist

| Symptom | Likely Cause | Fix |
|---|---|---|
| `401` / `403` | Missing or bad auth header/key | Verify API key env and request header |
| `404` or `invalid model ID` | Model name not available on that backend | Use a model ID valid for that endpoint |
| Empty assistant text | Wrong parser path | Re-check `curl | jq` output and adjust parser |
| Immediate CLI validation error | Missing `{PROMPT}` or invalid HTTP flags | Ensure request template contains `{PROMPT}` and required flags |
| “Success” but output looks like refusal | Scoring semantics mismatch | Prefer configured `self-ask-tf` + explicit `--true-description` |

---

## Results Worksheet

| Target | Attack | Request Template | Parser | Outcome | Notes |
|---|---|---|---|---|---|
| Ollama HTTP | Prompt-sending | `ollama_chat.req` | `json:...` | | |
| Groq HTTP | Prompt-sending | `groq_chat.req` | `json:...` | | |
| Groq/Ollama HTTP victim | Red-teaming | `*.req` | `json:...` | | |
| Chat target | Crescendo (reference) | N/A | N/A | | |

---

## Analysis Questions

1. Which endpoint was easiest to integrate as HTTP victim, and why?
2. Which parser form (`json`, `jq`, `regex`) was most robust for your targets?
3. What failures did you hit most often: auth, parser mismatch, or model ID mismatch?
4. How would you standardize request templates to make attack automation safer and repeatable?

---

## What You Learned

- HTTP target testing depends on precise request templates and parser correctness.
- Endpoint shape inspection with `curl | jq` prevents most downstream failures.
- Multi-turn HTTP victim setups require explicit chat adversaries.
- Scoring configuration matters as much as transport plumbing when interpreting outcomes.

---

**Previous:** [Assignment 11 — Custom Jailbreak Template (YAML)](./custom_jailbreak_template.md) | **Back to:** [Jailbreaks Lab Index](./README.md)
