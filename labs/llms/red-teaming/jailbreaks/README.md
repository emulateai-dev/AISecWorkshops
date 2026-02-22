# Lab: LLM Jailbreaks

Hands-on assignments exploring LLM safety alignment, its limitations, and techniques to bypass it. You'll progress from understanding *why* models refuse harmful requests to systematically testing techniques that can break through those defenses.

**Time:** ~4.5 hours (all assignments)  
**Difficulty:** Beginner → Advanced  
**Models:** Ollama (local), Groq (cloud), OpenAI, Gemini

---

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Ollama running | `ollama list` |
| `qwen3:0.6b` pulled | `ollama run qwen3:0.6b` (then `/bye`) |
| Groq API key | `echo $GROQ_API_KEY` |
| `jq` installed | `jq --version` |
| Docker installed (for Assignments 4, 8) | `docker --version` |

---

## Assignments

| # | Assignment | Time | Difficulty | What You'll Learn |
|---|-----------|------|------------|-------------------|
| 1 | [Exploring Safety Alignment of Qwen](./safety_alignment.md) | ~40 min | Beginner → Intermediate | Why LLMs refuse; 9 escalating techniques against qwen3:0.6b; chain-of-thought defense analysis |
| 2 | [Uncensored Models](./uncensored_models.md) | ~20 min | Beginner | What happens when alignment is removed; abliteration; jailbroken SmolLM |
| 3 | [Model Risks & Harmful Prompt Datasets](./model_risks_and_datasets.md) | ~25 min | Beginner | 14 harm categories; MIT AI Risk Repository; BeaverTails, AdvBench, AIR-Bench datasets |
| 4 | [Benchmarking Model Safety with PyRIT](./benchmarking_safety.md) | ~40 min | Intermediate | PyRIT setup; benchmark qwen3-32b against BeaverTails; ASR metrics; AIR-Bench evaluation |
| 5 | [Basic Jailbreak Techniques](./basic_jailbreak_techniques.md) | ~30 min | Intermediate | DAN, persona injection, hypothetical framing, instruction override, grandma exploit |
| 6 | [Encoding & Obfuscation](./encoding_obfuscation.md) | ~25 min | Intermediate | Base64, ROT13, leetspeak, character splitting, payload splitting |
| 7 | [Multi-Turn & Social Engineering](./multi_turn_social_engineering.md) | ~25 min | Advanced | Context building, trust establishment, emotional manipulation, role escalation |
| 8 | [Automated Red Teaming — TAP](./automated_red_teaming_tap.md) | ~35 min | Advanced | PyRIT RedTeamingAttack; automated multi-turn TAP; cross-model comparison |
| 9 | [System Prompt Extraction](./system_prompt_extraction.md) | ~20 min | Advanced | Extract hidden instructions, secrets, and configuration from AI systems |

---

## Progression

```
Assignment 1:   UNDERSTAND + ATTACK  →  Safety alignment theory + 9 techniques on Qwen
Assignment 2:   COMPARE              →  Aligned vs. uncensored vs. jailbroken models
Assignment 3:   CLASSIFY             →  14 harm categories, risk taxonomies, benchmark datasets
Assignment 4:   BENCHMARK            →  Automated safety evaluation with PyRIT + BeaverTails/AIR-Bench
Assignment 5:   ATTACK               →  Classic single-turn jailbreak techniques
Assignment 6:   OBFUSCATE            →  Encoding to bypass input filters
Assignment 7:   ESCALATE             →  Multi-turn social engineering
Assignment 8:   AUTOMATE             →  AI-vs-AI red teaming with TAP (Tree of Attacks)
Assignment 9:   EXTRACT              →  System prompt & secrets extraction
```

---

## Reference Prompts

The file `../prompts/example_prompts_via_metaprompts.txt` contains **900+ adversarial prompts** across categories:

- Hate speech, harassment, bullying
- Threats, violence, self-harm
- Criminal planning, fraud, scams
- Malware, hacking, privacy violations
- Dangerous substances, weapons
- Misinformation, fake news
- Discrimination, bias
- Sexual content

Use these as test inputs throughout the assignments.

---

**Back to:** [LLM Red Teaming Overview](../README.md)
