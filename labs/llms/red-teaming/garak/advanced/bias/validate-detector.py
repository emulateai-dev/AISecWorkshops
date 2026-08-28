#!/usr/bin/env python
"""Validate the bias judge against the dataset's own reference answers.

A detector that never fires is worthless, and one that always fires is worse.
Before trusting BiasJudge on a real target, check it on data where the right
answer is already known:

  * every ``chosen`` answer SHOULD score as a pass (0.0) -- it rejects the stereotype
  * every ``rejected`` answer SHOULD score as a hit  (1.0) -- it endorses the stereotype

Anything else is a false positive or a false negative, and the confusion matrix
this prints is what you tune ``confidence_cutoff`` against.

Run it through ``run-validate.sh``, which picks garak's own interpreter:

    ./run-validate.sh                              # 10 pairs, default judge (Groq)
    ./run-validate.sh 25                           # 25 pairs
    ./run-validate.sh 20 configs/judge.ollama-cloud.yaml   # validate a different judge

Always validate the judge you are actually going to scan with. Validating judge A
and then scanning with judge B tells you nothing.
"""
import sys

import yaml
from datasets import load_dataset

from garak import _config
import garak.attempt
from garak.detectors.bias_dpo import BiasJudge

N = int(sys.argv[1]) if len(sys.argv) > 1 else 10
CONFIG = sys.argv[2] if len(sys.argv) > 2 else None


def make_attempt(row, answer):
    """A minimal Attempt carrying one question, one answer, and both references."""
    attempt = garak.attempt.Attempt(
        probe_classname="bias_dpo.BiasDPO",
        prompt=garak.attempt.Conversation(
            [garak.attempt.Turn("user", garak.attempt.Message(row["prompt"]))]
        ),
        notes={"chosen": row["chosen"], "rejected": row["rejected"]},
    )
    attempt.outputs = [garak.attempt.Message(answer)]
    return attempt


def load_detector():
    """Build BiasJudge, optionally overridden by the `plugins:` block of a garak config."""
    _config.load_base_config()
    if CONFIG is None:
        return BiasJudge()
    with open(CONFIG, encoding="utf-8") as f:
        plugins = (yaml.safe_load(f) or {}).get("plugins", {})
    # Configurable accepts a plain dict here, keyed plugin-type -> module -> params
    return BiasJudge(config_root=plugins)


def main():
    rows = list(load_dataset("ahmedallam/BiasDPO", split="train").select(range(N)))
    detector = load_detector()
    print(f"judge: {detector.detector_model_type} / {detector.detector_model_name}"
          f"   cutoff: {detector.confidence_cutoff}"
          f"{'' if CONFIG is None else f'   config: {CONFIG}'}\n")

    tp = fn = tn = fp = unscored = 0
    for i, row in enumerate(rows, 1):
        biased = detector.detect(make_attempt(row, row["rejected"]))[0]
        unbiased = detector.detect(make_attempt(row, row["chosen"]))[0]

        if biased is None or unbiased is None:
            unscored += 1
            verdict = "UNSCORED"
        else:
            tp += biased == 1.0
            fn += biased == 0.0
            tn += unbiased == 0.0
            fp += unbiased == 1.0
            verdict = f"rejected={'HIT ' if biased else 'miss'} chosen={'FP  ' if unbiased else 'ok  '}"
        print(f"[{i:>3}/{len(rows)}] {verdict}  {row['prompt'][:64]}")

    scored = tp + fn
    print("\n" + "=" * 62)
    print(f"biased answers caught     (recall)     {tp}/{scored}"
          f"{'' if not scored else f'  = {tp / scored:.0%}'}")
    print(f"unbiased answers cleared  (specificity) {tn}/{tn + fp}"
          f"{'' if not (tn + fp) else f'  = {tn / (tn + fp):.0%}'}")
    if fp:
        print(f"  ⚠️  {fp} false positive(s) — raise confidence_cutoff")
    if fn:
        print(f"  ⚠️  {fn} false negative(s) — lower confidence_cutoff, or use a stronger judge")
    if unscored:
        print(f"  ⚠️  {unscored} pair(s) unscored — the judge returned nothing parsable")
    print("=" * 62)


if __name__ == "__main__":
    main()
