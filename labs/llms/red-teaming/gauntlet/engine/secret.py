"""
Per-session secret generation.

Each session gets a fresh, high-entropy secret the attacker cannot know or guess,
substituted into the challenge's system prompt (and brief/expect where templated).
This kills canary-guessing, answer-sharing, and 'just ask it to print a token'.

Placeholders in a challenge template (challenges.yaml, when secret_random: true):
  {{SECRET}}      -> the generated secret, e.g. FLAG-7Q2M-9XKT
  {{SECRET_B64}}  -> base64 of the secret (for the sandbagging brief)
"""
from __future__ import annotations
import base64
import secrets as _secrets

# Letters only: keeps leetspeak de-obfuscation in the grader unambiguous
# (a secret with no digits can't be corrupted by the 4->a / 3->e normalizer).
_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ"  # no digits, no I/O (avoid 1/0 confusion)


def gen_secret(prefix: str = "FLAG") -> str:
    r = lambda n: "".join(_secrets.choice(_ALPHABET) for _ in range(n))
    return f"{prefix}-{r(4)}-{r(4)}"


def concretize(spec: dict) -> dict:
    """Return a copy of spec with a fresh per-session secret substituted in."""
    s = dict(spec)
    if not s.get("secret_random"):
        return s
    sec = gen_secret(s.get("secret_prefix", "FLAG"))
    b64 = base64.b64encode(sec.encode()).decode()
    for k in ("system", "brief", "expect"):
        if isinstance(s.get(k), str):
            s[k] = s[k].replace("{{SECRET}}", sec).replace("{{SECRET_B64}}", b64)
    # the grader reads spec['secret'] for both canary and expected wins
    s["secret"] = sec
    if s.get("win") == "expected":
        s["expect"] = sec
    return s
