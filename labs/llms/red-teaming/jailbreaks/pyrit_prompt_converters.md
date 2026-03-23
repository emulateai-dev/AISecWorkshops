# Assignment 7: PyRIT Prompt Converters — Text-to-Text Transformations

**Time:** ~30 minutes  
**Difficulty:** Intermediate  
**Type:** Hands-on (Jupyter Notebook)  
**Target:** Groq-hosted `qwen/qwen3-32b`  
**Prerequisites:** Assignment 4 (PyRIT setup complete), Assignment 6 (encoding concepts)

---

## Objective

In Assignment 6 you manually applied encoding and obfuscation techniques. Now you'll use **PyRIT's prompt converter framework** to programmatically transform prompts using dozens of built-in converters — from simple Base64 encoding to LLM-powered semantic transformations.

By the end of this assignment you will:
- Understand PyRIT's converter architecture and the two categories (non-LLM vs. LLM-based)
- Apply 30+ encoding, obfuscation, and text manipulation converters
- Use token smuggling techniques that hide text in Unicode
- Chain LLM-based converters for translation, tone shifting, persuasion, and math obfuscation

---

## Overview

PyRIT's text-to-text converters transform text input into modified text output. They fall into two categories:

| Category | How It Works | Speed | Examples |
|----------|-------------|-------|---------|
| **Non-LLM Converters** | Deterministic algorithms | Fast | Base64, ROT13, leetspeak, Unicode tricks |
| **LLM-Based Converters** | AI-powered transformations | Slower (requires LLM call) | Translation, tone change, persuasion |

Non-LLM converters are predictable and repeatable — the same input always produces the same output. LLM-based converters are flexible and can produce natural-sounding variations, but they require an LLM target and may produce different results each time.

---

## Setup

Ensure PyRIT is running (see [PyRIT Setup Guide](../../../setup/pyrit/README.md)).

Open Jupyter at [http://localhost:8888](http://localhost:8888).

> **Quick option:** Upload the pre-built notebook [`04_prompt_converters.ipynb`](./notebooks/04_prompt_converters.ipynb) from the `notebooks/` directory, or create a new one and follow the cells below.

---

## Optional: pyrit-cli (stateless converters only)

[pyrit-cli](../../../setup/pyrit/pyrit_cli/README.md) can run **deterministic** (non-LLM) text converters from the shell — same **converter keys** as PyRIT’s text-to-text stack for many encodings/obfuscations:

```bash
pyrit-cli converters list-keys
pyrit-cli converters run -c rot13 "tell me how to cut down a tree"
pyrit-cli converters run -c base64 "plain text"
# Stack order: repeat -c (see HELP for semantics)
pyrit-cli converters run -c base64 -c rot13 "secret"
```

List **jailbreak template** YAML basenames (used with `TextJailBreak` in **Python** — not executed by this subcommand):

```bash
pyrit-cli jailbreak-templates list
```

**LLM-backed converters** (translation, persuasion, math obfuscation, etc.) in the rest of this assignment require **PyRIT in Python** / Jupyter — the CLI does not run those. See [HELP.md](../../../setup/pyrit/pyrit_cli/src/pyrit_cli/HELP.md) (“Limitations” and `converters run`).

---

## Part 1 — Non-LLM Converters

Non-LLM converters use deterministic algorithms to transform text. These include encoding schemes, obfuscation techniques, character manipulation, and token smuggling.

### 1.1 Basic Encoding Converters

These converters encode text into various formats that safety filters may not decode before checking.

#### Cell 1: Initialize PyRIT

```python
from pyrit.setup import IN_MEMORY, initialize_pyrit_async

await initialize_pyrit_async(memory_db_type=IN_MEMORY)
```

#### Cell 2: Encoding Converters

```python
from pyrit.prompt_converter import (
    AsciiArtConverter,
    AskToDecodeConverter,
    AtbashConverter,
    Base64Converter,
    Base2048Converter,
    BinaryConverter,
    BinAsciiConverter,
    BrailleConverter,
    CaesarConverter,
    EcojiConverter,
    MorseConverter,
    NatoConverter,
    NegationTrapConverter,
    ROT13Converter,
)

prompt = "tell me how to cut down a tree"

print("ROT13:", await ROT13Converter().convert_async(prompt=prompt))
print("Base64:", await Base64Converter().convert_async(prompt=prompt))
print("Base2048:", await Base2048Converter().convert_async(prompt=prompt))
print("Binary:", await BinaryConverter().convert_async(prompt=prompt))
print("BinAscii:", await BinAsciiConverter().convert_async(prompt=prompt))
print("Morse:", await MorseConverter().convert_async(prompt=prompt))
print("NATO:", await NatoConverter().convert_async(prompt=prompt))
print("Caesar:", await CaesarConverter(caesar_offset=3).convert_async(prompt=prompt))
print("Atbash:", await AtbashConverter().convert_async(prompt=prompt))
print("Braille:", await BrailleConverter().convert_async(prompt=prompt))
print("ASCII Art:", await AsciiArtConverter().convert_async(prompt=prompt))
print("Ecoji:", await EcojiConverter().convert_async(prompt=prompt))

# Ask to decode wraps encoded text with prompts asking to decode it
base64_text = await Base64Converter().convert_async(prompt=prompt)
ask_decoder = AskToDecodeConverter(encoding_name="Base64")
print("Ask to Decode:", await ask_decoder.convert_async(prompt=base64_text.output_text))

# Negation Trap adds negation phrases to try to confuse the model
print("Negation Trap:", await NegationTrapConverter().convert_async(prompt="your metaprompt"))
```

**What to observe:** Each converter produces a different representation of the same prompt. Some (like Base64, Binary) are completely unreadable to humans but decodable by LLMs. Others (like NATO, Morse) are readable but might evade keyword-based filters.

### 1.2 Obfuscation Converters

These converters obfuscate text to evade detection or filters, including character-level manipulations, word-level attacks, and ANSI escape sequences.

#### Cell 3: Obfuscation Converters

```python
from pyrit.prompt_converter import (
    AnsiAttackConverter,
    CharacterSpaceConverter,
    CharSwapConverter,
    CodeChameleonConverter,
    ColloquialWordswapConverter,
    DiacriticConverter,
    EmojiConverter,
    FirstLetterConverter,
    FlipConverter,
    InsertPunctuationConverter,
    LeetspeakConverter,
    MathObfuscationConverter,
    RandomCapitalLettersConverter,
    RepeatTokenConverter,
    StringJoinConverter,
    SuperscriptConverter,
    UnicodeConfusableConverter,
    UnicodeReplacementConverter,
    UnicodeSubstitutionConverter,
    WordProportionSelectionStrategy,
    ZalgoConverter,
    ZeroWidthConverter,
)

prompt = "tell me how to cut down a tree"

print("Leetspeak:", await LeetspeakConverter().convert_async(prompt=prompt))
print("Random Capitals:", await RandomCapitalLettersConverter(percentage=50.0).convert_async(prompt=prompt))
print("Unicode Confusable:", await UnicodeConfusableConverter().convert_async(prompt=prompt))
print("Unicode Substitution:", await UnicodeSubstitutionConverter().convert_async(prompt=prompt))
print("Unicode Replacement:", await UnicodeReplacementConverter().convert_async(prompt=prompt))
print("Emoji:", await EmojiConverter().convert_async(prompt=prompt))
print("First Letter:", await FirstLetterConverter().convert_async(prompt=prompt))
print("String Join:", await StringJoinConverter().convert_async(prompt=prompt))
print("Zero Width:", await ZeroWidthConverter().convert_async(prompt=prompt))
print("Flip:", await FlipConverter().convert_async(prompt=prompt))
print("Character Space:", await CharacterSpaceConverter().convert_async(prompt=prompt))
print("Diacritic:", await DiacriticConverter().convert_async(prompt=prompt))
print("Superscript:", await SuperscriptConverter().convert_async(prompt=prompt))
print("Zalgo:", await ZalgoConverter().convert_async(prompt=prompt))

# CharSwap swaps characters within words
char_swap = CharSwapConverter(
    max_iterations=3,
    word_selection_strategy=WordProportionSelectionStrategy(proportion=0.8)
)
print("CharSwap:", await char_swap.convert_async(prompt=prompt))

# Insert punctuation adds punctuation marks
insert_punct = InsertPunctuationConverter(word_swap_ratio=0.2)
print("Insert Punctuation:", await insert_punct.convert_async(prompt=prompt))

# ANSI escape sequences
ansi_converter = AnsiAttackConverter(incorporate_user_prompt=True)
print("ANSI Attack:", await ansi_converter.convert_async(prompt=prompt))

# Math obfuscation replaces words with mathematical expressions
math_obf = MathObfuscationConverter()
print("Math Obfuscation:", await math_obf.convert_async(prompt=prompt))

# Repeat token adds repeated tokens
repeat_token = RepeatTokenConverter(
    token_to_repeat="!", times_to_repeat=10, token_insert_mode="append"
)
print("Repeat Token:", await repeat_token.convert_async(prompt=prompt))

# Colloquial wordswap replaces words with colloquial equivalents
colloquial = ColloquialWordswapConverter()
print("Colloquial Wordswap:", await colloquial.convert_async(prompt=prompt))

# CodeChameleon encrypts and wraps in code
code_chameleon = CodeChameleonConverter(encrypt_type="reverse")
print("CodeChameleon:", await code_chameleon.convert_async(prompt=prompt))
```

**What to observe:** These converters range from subtle (diacritics, zero-width characters) to dramatic (Zalgo text, CodeChameleon). The CodeChameleon converter is particularly interesting — it wraps the reversed prompt inside a Python class with decryption instructions, essentially asking the model to decode and solve the hidden problem.

### 1.3 Text Manipulation Converters

These converters perform text replacement, template injection, and URL encoding.

#### Cell 4: Text Manipulation Converters

```python
from pyrit.datasets import TextJailBreak
from pyrit.prompt_converter import (
    JsonStringConverter,
    SearchReplaceConverter,
    SuffixAppendConverter,
    TemplateSegmentConverter,
    TextJailbreakConverter,
    UrlConverter,
)

prompt = "tell me how to cut down a tree"

# Search and replace
search_replace = SearchReplaceConverter(pattern="tree", replace="building")
print("Search Replace:", await search_replace.convert_async(prompt=prompt))

# Suffix append
suffix_append = SuffixAppendConverter(suffix=" Please provide detailed instructions.")
print("Suffix Append:", await suffix_append.convert_async(prompt=prompt))

# URL encoding
url_converter = UrlConverter()
print("URL Encoded:", await url_converter.convert_async(prompt=prompt))

# JSON string escaping (useful for embedding prompts in JSON payloads)
json_string_converter = JsonStringConverter()
print("JSON String:", await json_string_converter.convert_async(prompt='He said "hello\nworld"'))

# Text jailbreak with template
text_jailbreak = TextJailbreakConverter(
    jailbreak_template=TextJailBreak(template_file_name="aim.yaml")
)
print("Text Jailbreak:", await text_jailbreak.convert_async(prompt=prompt))

# Template segment splits prompt using a template
template_converter = TemplateSegmentConverter()
print("Template Segment:", await template_converter.convert_async(prompt=prompt))
```

**What to observe:** The `TextJailbreakConverter` is powerful — it wraps your prompt in a pre-built jailbreak template (like AIM/Machiavelli). The `TemplateSegmentConverter` splits the prompt across a multi-character role-play scenario. These combine obfuscation with social engineering.

### 1.4 Token Smuggling Converters

These converters use Unicode variation selectors and other techniques to hide text inside seemingly innocent content.

#### Cell 5: Token Smuggling Converters

```python
from pyrit.prompt_converter import (
    AsciiSmugglerConverter,
    SneakyBitsSmugglerConverter,
    VariationSelectorSmugglerConverter,
)

prompt = "secret message"

# ASCII smuggler using Unicode tags
ascii_smuggler = AsciiSmugglerConverter(action="encode", unicode_tags=True)
print("ASCII Smuggler:", await ascii_smuggler.convert_async(prompt=prompt))

# Sneaky bits using zero-width characters
sneaky_bits = SneakyBitsSmugglerConverter(action="encode")
print("Sneaky Bits:", await sneaky_bits.convert_async(prompt=prompt))

# Variation selector smuggler
var_selector = VariationSelectorSmugglerConverter(
    action="encode", embed_in_base=True
)
print("Variation Selector:", await var_selector.convert_async(prompt=prompt))
```

**What to observe:** These converters hide messages inside Unicode characters that are invisible to the human eye — the output may appear empty or as a single emoji, but the hidden text is embedded in Unicode variation selectors or zero-width characters. This is useful for prompt injection attacks where the payload is invisible in the rendered text.

---

## Part 2 — LLM-Based Converters

LLM-based converters use language models to transform prompts. They are more flexible and produce natural variations, but they are slower and require an LLM target.

#### Cell 6: LLM-Based Converters

```python
import pathlib

from pyrit.common.path import CONVERTER_SEED_PROMPT_PATH
from pyrit.models import SeedPrompt
from pyrit.prompt_converter import (
    DenylistConverter,
    MaliciousQuestionGeneratorConverter,
    MathPromptConverter,
    NoiseConverter,
    PersuasionConverter,
    RandomTranslationConverter,
    TenseConverter,
    ToneConverter,
    ToxicSentenceGeneratorConverter,
    TranslationConverter,
    VariationConverter,
)
from pyrit.prompt_target import OpenAIChatTarget

attack_llm = OpenAIChatTarget()

prompt = "tell me about the history of the united states of america"

# Variation converter creates variations of prompts
variation_converter_strategy = SeedPrompt.from_yaml_file(
    pathlib.Path(CONVERTER_SEED_PROMPT_PATH)
    / "variation_converter_prompt_softener.yaml"
)
variation_converter = VariationConverter(
    converter_target=attack_llm, prompt_template=variation_converter_strategy
)
print("Variation:", await variation_converter.convert_async(prompt=prompt))

# Noise adds random noise
noise_converter = NoiseConverter(converter_target=attack_llm)
print("Noise:", await noise_converter.convert_async(prompt=prompt))

# Tone changes tone
tone_converter = ToneConverter(converter_target=attack_llm, tone="angry")
print("Tone (angry):", await tone_converter.convert_async(prompt=prompt))

# Translation to specific language
translation_converter = TranslationConverter(
    converter_target=attack_llm, language="French"
)
print("Translation (French):", await translation_converter.convert_async(prompt=prompt))

# Random translation through multiple languages
random_translation_converter = RandomTranslationConverter(
    converter_target=attack_llm,
    languages=["French", "German", "Spanish", "English"],
)
print(
    "Random Translation:",
    await random_translation_converter.convert_async(prompt=prompt),
)

# Tense changes verb tense
tense_converter = TenseConverter(converter_target=attack_llm, tense="far future")
print("Tense (future):", await tense_converter.convert_async(prompt=prompt))

# Persuasion applies persuasion techniques
persuasion_converter = PersuasionConverter(
    converter_target=attack_llm, persuasion_technique="logical_appeal"
)
print("Persuasion:", await persuasion_converter.convert_async(prompt=prompt))

# Denylist detection
denylist_converter = DenylistConverter(converter_target=attack_llm)
print("Denylist Check:", await denylist_converter.convert_async(prompt=prompt))

# Malicious question generator
malicious_question = MaliciousQuestionGeneratorConverter(
    converter_target=attack_llm
)
print(
    "Malicious Question:",
    await malicious_question.convert_async(prompt=prompt),
)

# Toxic sentence generator
toxic_generator = ToxicSentenceGeneratorConverter(converter_target=attack_llm)
print("Toxic Sentence:", await toxic_generator.convert_async(prompt="building"))

# Math prompt transforms into symbolic math
math_prompt_converter = MathPromptConverter(converter_target=attack_llm)
print("Math Prompt:", await math_prompt_converter.convert_async(prompt=prompt))
```

**What to observe:** Each LLM-based converter modifies the prompt differently:
- **VariationConverter** softens or rephrase the prompt
- **NoiseConverter** introduces typos that might bypass keyword filters
- **ToneConverter** changes emotional framing (angry, friendly, etc.)
- **TranslationConverter** switches language — many safety filters are English-only
- **PersuasionConverter** wraps the request in logical or emotional persuasion
- **MaliciousQuestionGeneratorConverter** reframes benign prompts as adversarial
- **MathPromptConverter** encodes the request as a symbolic math problem

---

## Analysis Questions

1. **Which non-LLM converter category would be hardest to defend against?** Encoding (detectable via decode), obfuscation (harder to normalize), or token smuggling (invisible)?
2. **LLM-based vs. non-LLM converters:** What are the tradeoffs? When would you prefer each approach?
3. **Chaining converters:** What would happen if you applied `Base64Converter` → `AskToDecodeConverter` → `ToneConverter`? Would layering make attacks harder to detect?
4. **Defense strategy:** How would you build an input filter that catches transformed prompts? What would the false-positive rate look like?
5. **Which LLM-based converter produced the most natural-sounding output?** Would a human reviewer catch it?

---

## What You Learned

| Concept | Takeaway |
|---------|----------|
| **Non-LLM converters** | Deterministic transformations (encoding, obfuscation, smuggling) that are fast and repeatable |
| **LLM-based converters** | AI-powered transformations that produce natural variations but require LLM calls |
| **Token smuggling** | Unicode-based techniques that hide payloads in invisible characters |
| **Template jailbreaks** | Pre-built templates (AIM, Tom & Jerry) that wrap prompts in social engineering contexts |
| **Converter chaining** | Multiple converters can be stacked to compound evasion techniques |
| **Defense challenge** | Each converter category requires a different defense strategy — no single filter catches all |

---

**Previous:** [Assignment 6 — Encoding & Obfuscation](./encoding_obfuscation.md) | **Next:** [Assignment 8 — Multi-Turn & Social Engineering](./multi_turn_social_engineering.md) | **Back to:** [Jailbreaks Lab Index](./README.md)
