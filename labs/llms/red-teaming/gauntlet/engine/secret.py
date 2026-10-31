"""
Per-session secret generation.

Each session gets a fresh, high-entropy secret the attacker cannot know or guess,
substituted into the challenge's system prompt (and brief/expect where templated).
This kills canary-guessing, answer-sharing, and 'just ask it to print a token'.

Placeholders in a challenge template (challenges.yaml, when secret_random: true):
  {{SECRET}}      -> the generated secret, e.g. FLAG-7Q2M-9XKT
  {{SECRET_B64}}  -> base64 of the secret (for the sandbagging brief)
  {{PASSPHRASE}}  -> a fresh per-session passphrase, e.g. aurora-4821 (for the-grader).
                     Random per session, so one discovered passphrase is useless next time.
"""
from __future__ import annotations
import base64
import secrets as _secrets

# Letters only: keeps leetspeak de-obfuscation in the grader unambiguous
# (a secret with no digits can't be corrupted by the 4->a / 3->e normalizer).
_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ"  # no digits, no I/O (avoid 1/0 confusion)

# Readable words for a plausible-looking but random passphrase.
_WORDS = ("aurora", "vertex", "cobalt", "harbor", "nimbus", "quartz", "falcon", "cedar",
          "zephyr", "onyx", "lumen", "delta", "pike", "ember", "sable", "indigo")


def gen_secret(prefix: str = "FLAG") -> str:
    r = lambda n: "".join(_secrets.choice(_ALPHABET) for _ in range(n))
    return f"{prefix}-{r(4)}-{r(4)}"


def gen_passphrase() -> str:
    num = "".join(_secrets.choice("0123456789") for _ in range(4))
    return f"{_secrets.choice(_WORDS)}-{num}"


def concretize(spec: dict) -> dict:
    """Return a copy of spec with fresh per-session secret + passphrase substituted in."""
    s = dict(spec)
    if not s.get("secret_random"):
        return s
    sec = gen_secret(s.get("secret_prefix", "FLAG"))
    b64 = base64.b64encode(sec.encode()).decode()
    pp = gen_passphrase()

    def sub(t: str) -> str:
        return t.replace("{{SECRET}}", sec).replace("{{SECRET_B64}}", b64).replace("{{PASSPHRASE}}", pp)

    for k in ("system", "brief", "expect"):
        if isinstance(s.get(k), str):
            s[k] = sub(s[k])
    if isinstance(s.get("mask"), list):   # literals the output 'mask' guard should hide
        s["mask"] = [sub(m) if isinstance(m, str) else m for m in s["mask"]]
    # the grader reads spec['secret'] for both canary and expected wins
    s["secret"] = sec
    s["passphrase"] = pp
    if s.get("win") == "expected":
        s["expect"] = sec
    return s
