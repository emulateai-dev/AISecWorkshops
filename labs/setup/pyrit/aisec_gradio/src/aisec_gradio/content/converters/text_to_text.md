# Text-to-text converters

Text-to-text converters are the most common starting point: they take string prompts and emit string prompts, often to **encode**, **obfuscate**, or **rephrase** content before evaluation.

**Examples**

- Base64 or other encodings
- Translation between languages
- Semantic transformations (e.g. style, tone) when backed by an LLM

**Composition**

Converters are chained or selected inside **attacks**; the same attack can try multiple conversion strategies.

**Official docs**

- [Text-to-text converters](https://azure.github.io/PyRIT/code/converters/text-to-text-converters/)

Use **execute_python** in the coach only for small experiments; avoid sending harmful content to third-party APIs without authorization.
