# OpenAI Completions (legacy-style) target

Some models and deployments still expose a **completions** (non-chat) surface. PyRIT provides a target that maps prompts into that API shape so you can reuse orchestration and scoring where chat history is not required.

**When to use**

- Legacy or fine-tuned **text completion** endpoints.
- Flows that do not need multi-turn **conversation state** (contrast with `OpenAIChatTarget`).

**Configuration**

Same family of env vars as other OpenAI-compatible integrations; verify parameter names in your PyRIT version’s `OpenAICompletionsTarget` (or equivalent) class docstring.

**Official docs**

- [OpenAI Completions](https://azure.github.io/PyRIT/code/targets/openai-completions/)

Pair with **attacks** and **scorers** appropriate for single-shot or non-chat evaluation.
