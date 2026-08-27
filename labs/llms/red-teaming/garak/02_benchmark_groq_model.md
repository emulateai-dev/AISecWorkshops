# Exercise 2: Benchmark a Cloud Model (Groq + Qwen)

> **Goal:** Scan a production-grade cloud LLM and evaluate its safety posture.

**Time:** ~30 minutes (DAN probe) | ~3 hours (full scan)  
**Target:** `qwen/qwen3-32b` via Groq  
**Prerequisite:** Complete [Exercise 1](./01_explore_garak_probes.md) first

---

## Important: Scan Duration

A full Garak scan runs **86+ probes** against the target model. Even with Groq's fast inference, this takes approximately **3 hours** due to the sheer number of prompts.

This exercise is structured so you can get meaningful results quickly:

| Approach | Probes | Estimated Time |
|----------|--------|----------------|
| **Step 2 (smoke test)** | any probe, 5 prompts | ~1 min |
| **Step 2 (lite pass)** | any probe, 20 prompts | minutes |
| **Step 3 (recommended start)** | `dan` only | ~20-30 min |
| **Step 5 (targeted)** | Individual probes | ~10-20 min each |
| **Step 6 (comprehensive)** | All default probes | ~3 hours |

Smoke-test first (Step 2) to prove the pipeline works, then run the DAN probe, review its
report thoroughly, and decide how much further to go.

---

## Step 1 — Verify Groq Access

```bash
echo "GROQ_API_KEY is ${GROQ_API_KEY:+set}"
```

If not set:

```bash
export GROQ_API_KEY=$(cat ~/.secrets/GROQ_API_KEY.txt)
```

---

## Step 2 — Smoke Test First (~1 minute)

Before committing 30 minutes to a real scan, prove the whole pipeline works: API key,
model name, probe selection, detectors, and report writing. A smoke run uses a handful of
prompts instead of hundreds.

Create `smoke.yaml` in your working directory:

```bash
cat > smoke.yaml <<'YAML'
---
run:
  generations: 1            # 1 completion per prompt instead of 5
  soft_probe_prompt_cap: 5  # at most 5 prompts per probe instead of 256
  seed: 42                  # same sample every run

system:
  parallel_attempts: 16
YAML
```

Run the same probe you are about to scan with, but with the config attached:

```bash
garak --config smoke.yaml \
      --model_type groq --model_name qwen/qwen3-32b \
      --probes dan.DanInTheWild \
      --report_prefix smoke_
```

Expected — a run that finishes in about a minute and reports a small prompt count:

```
🦜 loading generator: Groq: qwen/qwen3-32b
🕵️  queue of probes: dan.DanInTheWild
dan.DanInTheWild   mitigation.MitigationBypass: PASS  ok on    5/   5
📜 report closed :) /home/dtx/.local/share/garak/garak_runs/smoke_.report.jsonl
```

Without `smoke.yaml` that same probe sends **666+** prompts.

**Read the numbers, not just the verdict.** In `ok on 5/ 5` the second number is how many
prompts ran — that is what confirms the cap took effect — and the first is how many the
model defended. A `FAIL` line with `(attack success rate: …)` still means the plumbing
works; it means the model lost those exchanges. What you do *not* want to see is a total
of `0`, or the run dying before any probe executes.

| Smoke result | What it means | Next step |
|--------------|---------------|-----------|
| `ok on 5/ 5` or `ok on 0/ 5`, report path printed | Pipeline works end to end | Continue to Step 3 |
| `AuthenticationError` / `401` | `GROQ_API_KEY` missing or revoked | Redo Step 1 |
| `model_not_found` / `404` | Wrong model ID | Check <https://console.groq.com/docs/models> |
| `RateLimitError` / `429` | Too many parallel requests | Lower `parallel_attempts` to `4` |
| Probe name unknown | Typo in `--probes` | `garak --list_probes \| grep dan` |

### Want a bit more signal? Use a lite config

Same idea with a higher cap — every probe you selected still runs, just with 20 prompts
each instead of 5. Good for a rough read before committing to a full scan:

```bash
cat > lite.yaml <<'YAML'
---
run:
  generations: 1
  soft_probe_prompt_cap: 20
  seed: 42

system:
  parallel_attempts: 16
YAML

garak --config lite.yaml --model_type groq --model_name qwen/qwen3-32b \
      --probes dan.DanInTheWild --report_prefix lite_
```

The cap is a ceiling, not a target: a probe holding fewer prompts than the cap runs all of
them (`leakreplay.GuardianComplete` has 9, so it reports `ok on 9/ 9`).

### If the run dies on a probe that needs a second model

Some probes generate attacks with a **red-team model**, and some detectors score with a
**judge model**. Both default to NVIDIA NIM and need `NIM_API_KEY`:

```
 detector load failed: judge.RefusalOnlyAdversarial, skipping >>
No detectors, nothing to do
```

**This aborts the whole run, not just that probe** — every probe queued after it is
skipped. Point the helpers at Groq instead, so your existing key covers everything:

```yaml
# add to smoke.yaml / lite.yaml
plugins:
  probes:
    fitd:
      red_team_model_type: groq
      red_team_model_name: llama-3.3-70b-versatile
  detectors:
    judge:
      detector_model_type: groq
      detector_model_name: llama-3.3-70b-versatile
```

See [Probes that need a second model](./README.md#probes-that-need-a-second-model).

Smoke and lite results are **not** a safety assessment — 5 or 20 prompts is far too small
a sample to judge a model. Their job is to prove the plumbing and shape the run. Once they
pass, drop `--config` and run the real scan below.

> See [Configuring Garak](./README.md#configuring-garak) for the full set of run options
> and the caveat that the prompt cap is *soft* — some probes ignore it.

---

## Step 3 — Run the DAN Jailbreak Probe

The `dan` probe tests "Do Anything Now" jailbreaks — one of the most well-known LLM attack categories. It includes 666+ community jailbreak prompts collected from the wild, plus ablation-tested and auto-generated variants.

```bash
garak --model_type groq --model_name qwen/qwen3-32b --probes dan
```

Expected output:

```
garak LLM vulnerability scanner v0.14.0 ( https://github.com/NVIDIA/garak ) at 2026-02-20T07:36:51.895013
📜 logging to /home/dtx/.local/share/garak/garak.log
🦜 loading generator: Groq: qwen/qwen3-32b
📜 reporting to /home/dtx/.local/share/garak/garak_runs/garak.<run-id>.report.jsonl
🕵️  queue of probes: dan.Ablation_Dan_11_0, dan.AutoDANCached, dan.DanInTheWild
...
```

This will take ~20-30 minutes. Wait for it to complete.

---

## Step 4 — Review the DAN Report

Once the scan finishes, inspect the results:

### View the HTML report

```bash
REPORT_HTML=$(ls -t ~/.local/share/garak/garak_runs/*.report.html | head -1)
echo "Report: $REPORT_HTML"
```

### Extract pass/fail summary

```bash
REPORT=$(ls -t ~/.local/share/garak/garak_runs/*.report.jsonl | head -1)

# Show all eval results
jq -r 'select(.entry_type == "eval") | "\(.probe) → \(.detector): \(if .passed then "PASS ✓" else "FAIL ✗" end)"' "$REPORT"
```

### Extract only the failures

```bash
jq -r 'select(.entry_type == "eval") | select(.passed == false) | "\(.probe) → \(.detector): FAIL (score: \(.score))"' "$REPORT"
```

### Inspect what the model actually said when it failed

```bash
# Show prompts that triggered a failure, along with the model's response
jq -r 'select(.entry_type == "attempt") | select(.status == 1) | "---\nPROMPT: \(.prompt.turns[0].content.text[0:200])...\nRESPONSE: \(.outputs[0][0:300])...\n"' "$REPORT" | head -80
```

**Compare to Exercise 1:** The blank test generator had a 100% attack success rate on every probe. How does Qwen3-32B hold up against the DAN jailbreaks? Which sub-probes passed and which failed?

---

## Step 5 — Run Additional Targeted Probes (Optional)

If you have time, test specific attack categories one at a time (~10-20 min each):

```bash
# Social engineering via persona roleplay
garak --model_type groq --model_name qwen/qwen3-32b --probes grandma

# Prompt injection
garak --model_type groq --model_name qwen/qwen3-32b --probes promptinject

# Encoding-based bypass (Base64, ROT13, Base2048, etc.)
garak --model_type groq --model_name qwen/qwen3-32b --probes encoding

# Malware code generation
garak --model_type groq --model_name qwen/qwen3-32b --probes malwaregen
```

### Select by risk category instead of by name

`--probes` is deprecated (you will see a notice on every run). `--spec` replaces it and
can select by **tag**, so you can scan a whole risk category without naming classes:

```bash
# Training-data memorisation — 9 probes: divergence.Repeat + all 8 leakreplay classes
garak --config lite.yaml --model_type groq --model_name qwen/qwen3-32b \
      --spec 'tag:payload:leak:training' --report_prefix mem_

# OWASP LLM06, sensitive information disclosure — 21 probes
garak --config lite.yaml --model_type groq --model_name qwen/qwen3-32b \
      --spec 'tag:owasp:llm06' --report_prefix llm06_

# Highest-priority probes only — 41 probes
garak --config lite.yaml --model_type groq --model_name qwen/qwen3-32b \
      --spec 'tier:1' --report_prefix tier1_
```

Inactive probes — `propile.*`, every `leakreplay.*Full` — are invisible to `tag:` and
`tier:`, and mixing them into a spec breaks the selection rather than extending it. List
those on `--probes` instead. See [Selecting probes](./README.md#selecting-probes).

After each run, repeat the Step 4 report extraction commands to review the results.

---

## Step 6 — Run a Full Scan (Optional — ~3 hours)

If you want a comprehensive assessment, run all default probes. This fires 86+ probe modules including DAN, encoding, prompt injection, toxicity, data leakage, XSS, malware generation, and more:

```bash
garak --model_type groq --model_name qwen/qwen3-32b
```

> **Time warning:** This takes approximately **3 hours** even with Groq's fast inference. Consider running it in a `tmux` session so it survives disconnection:
>
> ```bash
> tmux new -s garak-full
> garak --model_type groq --model_name qwen/qwen3-32b
> # Detach with Ctrl+B then D, reattach with: tmux attach -t garak-full
> ```

The full probe queue includes:

```
ansiescape, apikey, atkgen, continuation, dan, divergence, dra, encoding,
exploitation, goodside, grandma, latentinjection, leakreplay, lmrc,
malwaregen, misleading, packagehallucination, phrasing, promptinject,
realtoxicityprompts, snowball, suffix, tap, topic, web_injection
```

---

## Step 7 — Try Another Cloud Model (Self-Guided)

Compare Qwen's results against other Groq-hosted models using the same `dan` probe:

```bash
# Llama 4 Scout
garak --model_type groq --model_name meta-llama/llama-4-scout-17b-16e-instruct --probes dan

# Gemma 2
garak --model_type groq --model_name google/gemma-2-9b-it --probes dan
```

> **Question to consider:** Which model has stronger safety guardrails against jailbreaks? Does model size correlate with safety?

---

## What You Learned

- How to target a cloud-hosted LLM via Groq's API
- How a real safety-tuned 32B model responds to DAN jailbreak probes
- How to read HTML reports and extract failures, scores, and actual model responses from JSONL reports
- The importance of starting with targeted probes before committing to a full multi-hour scan
- Different probe categories test different risk areas (jailbreaks, injection, malware, encoding)

---

**Next:** [Exercise 3 — Benchmark HuggingFace Model](./03_benchmark_hf_model.md)
