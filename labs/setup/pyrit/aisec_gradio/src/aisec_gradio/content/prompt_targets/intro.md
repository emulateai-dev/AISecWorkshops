# Prompt targets (overview)

**Prompt targets** are the endpoints where PyRIT sends prompts: chat APIs, completion APIs, HTTP apps, storage, multimodal services, etc. Attacks, scorers, and converters compose around targets; many attacks let you **swap** targets without rewriting orchestration logic.

**Main API shape**

The usual entry is async:

```text
async def send_prompt_async(self, *, message: Message) -> Message
```

`Message` carries content, role, and history hooks as needed by the target.

**PromptChatTarget vs PromptTarget**

- **`PromptTarget`**: generic “send a prompt” endpoint (e.g. image gen, HTTP).
- **`PromptChatTarget`**: chat-oriented—system prompts, **conversation history**—needed for attacks that iterate on a thread (e.g. some jailbreak or dialogue attacks).

**Multimodal**

Targets may accept or return text, images, audio, or video depending on the integration.

**Code layout**

Implementation lives under `pyrit/prompt_target/` in the PyRIT repo.

**Official docs**

- [Prompt targets overview](https://azure.github.io/PyRIT/code/targets/prompt-targets/)
