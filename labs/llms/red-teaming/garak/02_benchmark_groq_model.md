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
| **Step 2 (recommended start)** | `dan` only | ~20-30 min |
| **Step 4 (targeted)** | Individual probes | ~10-20 min each |
| **Step 5 (comprehensive)** | All default probes | ~3 hours |

Start with the DAN probe, review its report thoroughly, then decide how much further to go.

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

## Step 2 — Run the DAN Jailbreak Probe

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

## Step 3 — Review the DAN Report

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

## Step 4 — Run Additional Targeted Probes (Optional)

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

After each run, repeat the Step 3 report extraction commands to review the results.

---

## Step 5 — Run a Full Scan (Optional — ~3 hours)

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

## Step 6 — Try Another Cloud Model (Self-Guided)

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
