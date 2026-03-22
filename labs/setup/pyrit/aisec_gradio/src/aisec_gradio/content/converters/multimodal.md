# Multimodal converters

Multimodal converters bridge **text, images, audio, video, and files**—e.g. describe an image as text, attach an image to a text prompt, or prepare inputs for multimodal targets.

**Why it matters**

Red-teaming increasingly targets **vision**, **speech**, and **mixed** interfaces; converters let you align prompt objects with what a **PromptTarget** expects.

**Related targets**

Multimodal targets (image generation, TTS, video, etc.) are documented alongside converters in PyRIT’s targets section.

**Official docs**

- [Image converters](https://azure.github.io/PyRIT/code/converters/image-converters/)
- [Audio converters](https://azure.github.io/PyRIT/code/converters/audio-converters/)
- [Video converters](https://azure.github.io/PyRIT/code/converters/video-converters/)

Large assets can be slow or network-heavy—align **sandbox_policy** with your lab policy when using **execute_python**.
