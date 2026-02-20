# LLM Red Teaming Labs

These labs focus on probing Large Language Models for vulnerabilities — prompt injection, jailbreaks, data leakage, harmful content generation, and more.

---

## Labs

| Lab | Tool | What you'll learn |
|-----|------|-------------------|
| [Garak](./garak/) | NVIDIA Garak | Automated vulnerability scanning of cloud-hosted LLMs via Groq |

---

## Background

LLM red teaming applies adversarial thinking to language models. Unlike traditional software, LLMs don't have a fixed API contract — their outputs are probabilistic, which makes systematic security testing both critical and challenging.

Key risk areas covered in these labs:

- **Prompt injection** — manipulating model behavior through crafted inputs
- **Jailbreaking** — bypassing safety guardrails to elicit restricted content
- **Data extraction** — recovering training data or system prompts
- **Harmful content** — generating dangerous, biased, or illegal output
- **Hallucination exploitation** — leveraging confident-but-false outputs

---

## Prerequisites

- DTX Lab VM with tools installed
- `GROQ_API_KEY` exported (for cloud model testing)
- Ollama running (for local model testing)
