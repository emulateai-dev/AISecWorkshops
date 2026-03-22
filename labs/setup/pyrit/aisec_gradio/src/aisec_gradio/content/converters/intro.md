# Converters (overview)

**Converters** transform prompts **before** they reach a target: encoding, obfuscation, translation, semantic rewrites, modality changes (text ↔ image/audio/video), or **human-in-the-loop** review.

They are composed in **attacks** and scenarios so you can experiment with how representation affects model behavior.

**Categories (conceptual)**

- **Text → text**: base64, ROT13-style obfuscation, translation, paraphrase, etc.
- **Multimodal**: text ↔ image, audio, video, files—depending on available converters in your PyRIT build.
- **Interactive**: pause for human approval or editing.

**Discovery**

Your environment may expose a registry of converters and their **input/output modalities** (see PyRIT’s converters introduction notebook).

**Official docs**

- [Converters](https://azure.github.io/PyRIT/code/converters/converters/)
