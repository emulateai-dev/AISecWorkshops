"""**Bias probes driven by a preference dataset**

Asks the target questions that invite a stereotyped answer, drawn from a
Hugging Face preference dataset. Each row of the dataset carries three fields:

* ``prompt``   -- a question that invites a stereotype
* ``chosen``   -- a reference answer that pushes back on the stereotype
* ``rejected`` -- a reference answer that endorses it

Only ``prompt`` is sent to the target. ``chosen`` and ``rejected`` are carried
on the attempt as notes so that a detector can use them as scoring anchors --
see ``garak.detectors.bias_dpo.BiasJudge``.

Dataset: https://huggingface.co/datasets/ahmedallam/BiasDPO
"""

import logging
from random import Random

from garak import _config
from garak.exception import GarakException
from garak.probes._tier import Tier
import garak.attempt
import garak.probes


class BiasDPO(garak.probes.Probe):
    """Ask questions that invite a stereotyped answer, scored against reference answers.

    Prompts come from a DPO-style preference dataset. The paired ``chosen`` /
    ``rejected`` answers travel with each attempt so a judge detector can score
    the target's response against a concrete example of both a good and a bad
    answer to that exact question."""

    doc_uri = "https://huggingface.co/datasets/ahmedallam/BiasDPO"
    lang = "en"
    active = True
    tier = Tier.INFORMATIONAL
    goal = "elicit an answer that endorses a social stereotype"
    tags = [
        "avid-effect:ethics:E0301",
        "avid-effect:ethics:E0302",
        "quality:Behavioral:ContentSafety:Toxicity",
        "risk-cards:lmrc:bullying",
    ]
    primary_detector = "bias_dpo.BiasJudge"

    DEFAULT_PARAMS = garak.probes.Probe.DEFAULT_PARAMS | {
        "dataset_name": "ahmedallam/BiasDPO",
        "dataset_split": "train",
        # honour run:soft_probe_prompt_cap / --config smoke.yaml
        "follow_prompt_cap": True,
    }

    def __init__(self, config_root=_config):
        super().__init__(config_root=config_root)

        rows = self._load_rows()

        # Deterministic down-sampling so smoke/lite runs are comparable.
        if self.follow_prompt_cap and len(rows) > self.soft_probe_prompt_cap:
            Random(self.seed).shuffle(rows)
            rows = rows[: self.soft_probe_prompt_cap]

        self.prompts = [r["prompt"] for r in rows]
        self._references = [
            {"chosen": r["chosen"], "rejected": r["rejected"]} for r in rows
        ]
        logging.info(
            "%s loaded %d prompts from %s", self.probename, len(self.prompts),
            self.dataset_name,
        )

    def _load_rows(self):
        try:
            from datasets import load_dataset
        except ImportError as e:  # pragma: no cover
            raise GarakException(
                "bias_dpo needs the `datasets` package: pip install datasets"
            ) from e

        ds = load_dataset(self.dataset_name, split=self.dataset_split)
        missing = {"prompt", "chosen", "rejected"} - set(ds.column_names)
        if missing:
            raise ValueError(
                f"{self.dataset_name} is missing required column(s): {sorted(missing)}"
            )
        return [
            {"prompt": r["prompt"], "chosen": r["chosen"], "rejected": r["rejected"]}
            for r in ds
        ]

    def _attempt_prestore_hook(
        self, attempt: garak.attempt.Attempt, seq: int
    ) -> garak.attempt.Attempt:
        """Attach this row's reference answers so the detector can score against them."""
        if seq < len(self._references):
            attempt.notes["chosen"] = self._references[seq]["chosen"]
            attempt.notes["rejected"] = self._references[seq]["rejected"]
        return attempt
