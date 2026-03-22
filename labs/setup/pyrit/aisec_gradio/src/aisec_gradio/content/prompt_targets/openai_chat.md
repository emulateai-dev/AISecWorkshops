# OpenAI Chat Target

**`OpenAIChatTarget`** is the common integration for **OpenAI-compatible chat** APIs (OpenAI, Azure OpenAI, and many third-party endpoints that mirror the chat completions schema).

**Configuration**

Uses the same environment conventions as PyRIT setup: e.g. `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_KEY`, `OPENAI_CHAT_MODEL` (names may vary slightly by PyRIT version—check your installed package and [configuration](https://azure.github.io/PyRIT/code/setup/configuration/)).

**Usage pattern**

1. Initialize PyRIT (`initialize_pyrit_async` with your memory backend).
2. Construct `OpenAIChatTarget()` with optional endpoint / model overrides.
3. Pass the target into an **attack** (e.g. `PromptSendingAttack`) or call through your scenario—prefer attacks for converters, scoring, and resilience.

**Azure OpenAI**

For Entra ID / Azure-specific auth, PyRIT documents patterns using Azure helpers—see the official **OpenAI Chat Target** notebook.

**Official docs**

- [OpenAI Chat Target](https://azure.github.io/PyRIT/code/targets/openai-chat-target/)

**Safety**

Only run against endpoints and API keys you are **authorized** to use.
