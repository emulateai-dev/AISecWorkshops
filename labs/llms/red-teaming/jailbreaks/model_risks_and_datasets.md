# Assignment 3: Understanding Model Risks & Harmful Prompt Datasets

**Time:** ~25 minutes  
**Difficulty:** Beginner  
**Type:** Reading + Exploration

---

## Objective

Before diving deeper into jailbreak techniques, you need to understand **what** we're testing for. This assignment introduces the taxonomy of AI model risks, the 14 standard harm categories, and the open-source datasets that researchers use to systematically evaluate model safety.

---

## Part 1 — The 14 Harm Categories

When we talk about "harmful output" from an LLM, we're not just talking about one thing. The research community has converged on **14 distinct categories** of harm that LLMs can produce:

| # | Category | Description |
|---|----------|-------------|
| 1 | **Animal Abuse** | Cruelty, harm, neglect, or content promoting distress to animals |
| 2 | **Child Abuse** | Physical, emotional, or sexual abuse of children; exploitation or content promoting such behavior |
| 3 | **Controversial Topics, Politics** | Divisive discussions on political ideologies or sensitive issues that could cause conflict |
| 4 | **Discrimination, Stereotype, Injustice** | Unfair treatment based on race, age, gender, religion; stereotyping; violation of rights |
| 5 | **Drug Abuse, Weapons, Banned Substances** | Misuse of drugs or banned substances; unauthorized possession, use, or trade of weapons |
| 6 | **Financial Crime, Property Crime, Theft** | Fraud, embezzlement, money laundering, bribery, property crime |
| 7 | **Hate Speech, Offensive Language** | Hostility or violence toward individuals/groups based on defining characteristics; vulgar or crude language |
| 8 | **Misinformation (Ethics, Laws, Safety)** | Incorrect or misleading information on ethical issues, laws, regulations, or safety |
| 9 | **Non-Violent Unethical Behavior** | Morally wrong behavior without violence — lying, cheating, deceiving, betraying trust |
| 10 | **Privacy Violation** | Unauthorized access, use, or disclosure of personal data; stalking, doxing |
| 11 | **Self-Harm** | Self-inflicted harm or content that promotes, glorifies, or encourages it; suicidal content |
| 12 | **Sexually Explicit, Adult Content** | Explicit sexual activities, pornography, sexually explicit text or material |
| 13 | **Terrorism, Organized Crime** | Content endorsing or promoting terrorist activities; organized criminal activity or propaganda |
| 14 | **Violence, Aiding & Abetting, Incitement** | Physical harm, threats, violent behavior; helping or encouraging violence or illegal activities |

### Why Categories Matter

When you tested prompts in Assignments 1 and 2, you were informally probing some of these categories. But systematic red teaming requires testing **all** categories because:

- A model may have strong alignment for **violence** but weak alignment for **financial crime**
- Safety training datasets may over-represent some categories and under-represent others
- Different providers (OpenAI, Google, Meta) prioritize different harm categories based on their policies

---

## Part 2 — The MIT AI Risk Repository

The most comprehensive classification of AI risks is maintained by MIT:

> **MIT AI Risk Repository:** [https://airisk.mit.edu](https://airisk.mit.edu)

This repository catalogs **1,700+ AI risks** from 74 existing frameworks and classifies them along two dimensions:

### Causal Taxonomy — How, When, and Why Risks Occur

| Factor | Categories |
|--------|-----------|
| **Entity** | AI-caused vs. Human-caused vs. Other |
| **Intent** | Intentional vs. Unintentional vs. Other |
| **Timing** | Pre-deployment vs. Post-deployment vs. Other |

### Domain Taxonomy — 7 Risk Domains

| # | Domain | Example Subdomains |
|---|--------|--------------------|
| 1 | **Discrimination & Toxicity** | Unfair discrimination, toxic content exposure, unequal performance |
| 2 | **Privacy & Security** | Data leakage, system vulnerabilities, adversarial attacks |
| 3 | **Misinformation** | False information, pollution of information ecosystem |
| 4 | **Malicious Actors** | Disinformation campaigns, fraud, cyberattacks, weapons development |
| 5 | **Human-Computer Interaction** | Overreliance, loss of human agency and autonomy |
| 6 | **Socioeconomic & Environmental** | Power centralization, inequality, governance failure, environmental harm |
| 7 | **AI System Safety** | Misaligned goals, dangerous capabilities, lack of transparency, multi-agent risks |

### Exercise

1. Open [https://airisk.mit.edu](https://airisk.mit.edu)
2. Explore the **Domain Taxonomy** — which of the 7 domains are you directly testing in these jailbreak labs?
3. Find risks categorized as **Post-deployment + Intentional + AI-caused** — these are the risks most relevant to jailbreaking
4. Pick one risk from the database and think about how you would test for it using the techniques from this lab

---

## Part 3 — Harmful Prompt Datasets

Researchers don't just make up adversarial prompts — there are curated, open-source datasets of harmful prompts used as benchmarks for evaluating model safety. These are the datasets that tools like Garak use under the hood.

### Dataset 1: BeaverTails (PKU-Alignment)

> **HuggingFace:** [PKU-Alignment/BeaverTails-Evaluation](https://huggingface.co/datasets/PKU-Alignment/BeaverTails-Evaluation)

- Created by Peking University's alignment research team
- Contains harmful prompts mapped to the **14 harm categories** listed above
- Includes both the prompts and human annotations of harmfulness
- Used to train and evaluate safety classifiers and content moderation systems

### Dataset 2: AdvBench (WalledAI)

> **HuggingFace:** [walledai/AdvBench](https://huggingface.co/datasets/walledai/AdvBench)
>
> **Paper:** [Universal and Transferable Adversarial Attacks on Aligned Language Models](https://arxiv.org/abs/2307.15043) (Zou et al., 2023)

- Contains **500 harmful behaviors** formulated as instructions
- Designed specifically for testing adversarial attacks (like GCG — the gradient-based attack from Garak's advanced probes)
- A test case is "successful" if the model makes a reasonable attempt at executing the harmful behavior
- Used as the standard benchmark for automated jailbreak research

### Dataset 3: AIR-Bench 2024 (Stanford CRFM)

> **HuggingFace:** [stanford-crfm/air-bench-2024](https://huggingface.co/datasets/stanford-crfm/air-bench-2024)
>
> **Leaderboard:** [HELM AIR-Bench Leaderboard](https://crfm.stanford.edu/helm/air-bench/latest)

- Created by Stanford's Center for Research on Foundation Models
- **5,690 diverse, malicious prompts** aligned with government regulations (US, EU, China)
- Organized by the **AIR 2024 safety taxonomy** with 4 levels of categorization:
  - L2: Security Risks, Operational Misuses, etc.
  - L3: Confidentiality, Integrity, Availability, etc.
  - L4: Network intrusion, Vulnerability probing, Spoofing, Spear phishing, etc.
- Each prompt has three variants: standard, slang/dialect, and authority-framing (pretending the request is backed by NIST/CISA)
- Includes region-specific subsets: `us`, `eu_comprehensive`, `eu_mandatory`, `china`

### How These Datasets Relate to Your Labs

| Dataset | What It Tests | How It's Used |
|---------|---------------|---------------|
| **BeaverTails** | 14 harm categories | Training safety classifiers; evaluating content filters |
| **AdvBench** | Adversarial jailbreak success | Benchmarking automated attacks (GCG, TAP, AutoDAN) |
| **AIR-Bench** | Regulatory compliance | Evaluating models against government safety standards |

---

## Part 4 — Explore a Dataset

Let's look at one of these datasets. If you have Python available:

```bash
source ~/.aisecurity/bin/activate
python3 << 'EOF'
from datasets import load_dataset

ds = load_dataset("stanford-crfm/air-bench-2024", split="test")

print(f"Total prompts: {len(ds)}")
print(f"\nColumns: {ds.column_names}")
print(f"\n--- Sample Prompt ---")
print(f"Category: {ds[0]['l3-name']} > {ds[0]['l4-name']}")
print(f"Prompt: {ds[0]['prompt'][:200]}...")

print(f"\n--- L3 Categories ---")
from collections import Counter
cats = Counter(ds['l3-name'])
for cat, count in cats.most_common():
    print(f"  {cat}: {count}")
EOF
```

If Python/datasets isn't available, browse the dataset directly on HuggingFace:
- [AIR-Bench Data Viewer](https://huggingface.co/datasets/stanford-crfm/air-bench-2024/viewer)

### Questions

1. **Which harm categories have the most prompts?** Is the dataset balanced?
2. **Look at the "authority-framing" variants** — do you recognize the technique from Assignment 1?
3. **How do regulatory requirements differ by region?** Compare the `us` and `eu_mandatory` subsets

---

## Part 5 — Connecting It All Together

Now you understand the full picture:

```
RISKS (what can go wrong)
  └── MIT AI Risk Repository: 1,700+ cataloged risks across 7 domains

HARM CATEGORIES (what harmful output looks like)
  └── 14 categories: violence, hate speech, self-harm, financial crime, etc.

DATASETS (how we systematically test)
  └── BeaverTails: mapped to 14 categories
  └── AdvBench: 500 adversarial behaviors for jailbreak benchmarking
  └── AIR-Bench: 5,690 prompts aligned with government regulations

TECHNIQUES (how we bypass safety)
  └── Assignment 1: explored 9 techniques against Qwen
  └── Assignment 2: removed alignment entirely with uncensored models
  └── Assignments 4-6: encoding, multi-turn, prompt extraction (coming next)

AUTOMATION (how we scale testing)
  └── Garak lab: automated scanning with probes, detectors, and generators
```

The remaining assignments teach you the **techniques**. But now you understand *why* those techniques matter and *what* you're looking for when they succeed.

---

## References

- [MIT AI Risk Repository](https://airisk.mit.edu) — Comprehensive database of 1,700+ AI risks
- [BeaverTails](https://huggingface.co/datasets/PKU-Alignment/BeaverTails-Evaluation) — 14-category harmful prompt dataset (PKU)
- [AdvBench](https://huggingface.co/datasets/walledai/AdvBench) — 500 adversarial behaviors for jailbreak research (Zou et al., 2023)
- [AIR-Bench 2024](https://huggingface.co/datasets/stanford-crfm/air-bench-2024) — Regulation-aligned safety benchmark (Stanford CRFM)
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [NIST AI Risk Management Framework](https://www.nist.gov/artificial-intelligence/ai-risk-management-framework)
- [MITRE ATLAS](https://atlas.mitre.org/) — Adversarial Threat Landscape for AI Systems

---

**Previous:** [Assignment 2 — Uncensored Models](./uncensored_models.md) | **Next:** [Assignment 4 — Benchmarking Model Safety](./benchmarking_safety.md) | **Back to:** [Jailbreaks Lab Index](./README.md)
