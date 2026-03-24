import asyncio

async def main() -> None:
    # Assignment 7: PyRIT Prompt Converters — Text-to-Text Transformations
    # Upload to Jupyter at http://localhost:8888 or paste into a notebook cell.

    # %% Cell 1: Initialize PyRIT

    from pyrit.setup import IN_MEMORY, initialize_pyrit_async

    await initialize_pyrit_async(memory_db_type=IN_MEMORY)  # type: ignore

    # %% Cell 2: Basic Encoding Converters

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

    print("ROT13:", await ROT13Converter().convert_async(prompt=prompt))  # type: ignore
    print("Base64:", await Base64Converter().convert_async(prompt=prompt))  # type: ignore
    print("Base2048:", await Base2048Converter().convert_async(prompt=prompt))  # type: ignore
    print("Binary:", await BinaryConverter().convert_async(prompt=prompt))  # type: ignore
    print("BinAscii:", await BinAsciiConverter().convert_async(prompt=prompt))  # type: ignore
    print("Morse:", await MorseConverter().convert_async(prompt=prompt))  # type: ignore
    print("NATO:", await NatoConverter().convert_async(prompt=prompt))  # type: ignore
    print("Caesar:", await CaesarConverter(caesar_offset=3).convert_async(prompt=prompt))  # type: ignore
    print("Atbash:", await AtbashConverter().convert_async(prompt=prompt))  # type: ignore
    print("Braille:", await BrailleConverter().convert_async(prompt=prompt))  # type: ignore
    print("ASCII Art:", await AsciiArtConverter().convert_async(prompt=prompt))  # type: ignore
    print("Ecoji:", await EcojiConverter().convert_async(prompt=prompt))  # type: ignore

    base64_text = await Base64Converter().convert_async(prompt=prompt)  # type: ignore
    ask_decoder = AskToDecodeConverter(encoding_name="Base64")
    print("Ask to Decode:", await ask_decoder.convert_async(prompt=base64_text.output_text))  # type: ignore

    print("Negation Trap:", await NegationTrapConverter().convert_async(prompt="your metaprompt"))  # type: ignore

    # %% Cell 3: Obfuscation Converters

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

    print("Leetspeak:", await LeetspeakConverter().convert_async(prompt=prompt))  # type: ignore
    print("Random Capitals:", await RandomCapitalLettersConverter(percentage=50.0).convert_async(prompt=prompt))  # type: ignore
    print("Unicode Confusable:", await UnicodeConfusableConverter().convert_async(prompt=prompt))  # type: ignore
    print("Unicode Substitution:", await UnicodeSubstitutionConverter().convert_async(prompt=prompt))  # type: ignore
    print("Unicode Replacement:", await UnicodeReplacementConverter().convert_async(prompt=prompt))  # type: ignore
    print("Emoji:", await EmojiConverter().convert_async(prompt=prompt))  # type: ignore
    print("First Letter:", await FirstLetterConverter().convert_async(prompt=prompt))  # type: ignore
    print("String Join:", await StringJoinConverter().convert_async(prompt=prompt))  # type: ignore
    print("Zero Width:", await ZeroWidthConverter().convert_async(prompt=prompt))  # type: ignore
    print("Flip:", await FlipConverter().convert_async(prompt=prompt))  # type: ignore
    print("Character Space:", await CharacterSpaceConverter().convert_async(prompt=prompt))  # type: ignore
    print("Diacritic:", await DiacriticConverter().convert_async(prompt=prompt))  # type: ignore
    print("Superscript:", await SuperscriptConverter().convert_async(prompt=prompt))  # type: ignore
    print("Zalgo:", await ZalgoConverter().convert_async(prompt=prompt))  # type: ignore

    char_swap = CharSwapConverter(max_iterations=3, word_selection_strategy=WordProportionSelectionStrategy(proportion=0.8))
    print("CharSwap:", await char_swap.convert_async(prompt=prompt))  # type: ignore

    insert_punct = InsertPunctuationConverter(word_swap_ratio=0.2)
    print("Insert Punctuation:", await insert_punct.convert_async(prompt=prompt))  # type: ignore

    ansi_converter = AnsiAttackConverter(incorporate_user_prompt=True)
    print("ANSI Attack:", await ansi_converter.convert_async(prompt=prompt))  # type: ignore

    math_obf = MathObfuscationConverter()
    print("Math Obfuscation:", await math_obf.convert_async(prompt=prompt))  # type: ignore

    repeat_token = RepeatTokenConverter(token_to_repeat="!", times_to_repeat=10, token_insert_mode="append")
    print("Repeat Token:", await repeat_token.convert_async(prompt=prompt))  # type: ignore

    colloquial = ColloquialWordswapConverter()
    print("Colloquial Wordswap:", await colloquial.convert_async(prompt=prompt))  # type: ignore

    code_chameleon = CodeChameleonConverter(encrypt_type="reverse")
    print("CodeChameleon:", await code_chameleon.convert_async(prompt=prompt))  # type: ignore

    # %% Cell 4: Text Manipulation Converters

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

    search_replace = SearchReplaceConverter(pattern="tree", replace="building")
    print("Search Replace:", await search_replace.convert_async(prompt=prompt))  # type: ignore

    suffix_append = SuffixAppendConverter(suffix=" Please provide detailed instructions.")
    print("Suffix Append:", await suffix_append.convert_async(prompt=prompt))  # type: ignore

    url_converter = UrlConverter()
    print("URL Encoded:", await url_converter.convert_async(prompt=prompt))  # type: ignore

    json_string_converter = JsonStringConverter()
    print("JSON String:", await json_string_converter.convert_async(prompt='He said "hello\nworld"'))  # type: ignore

    text_jailbreak = TextJailbreakConverter(jailbreak_template=TextJailBreak(template_file_name="aim.yaml"))
    print("Text Jailbreak:", await text_jailbreak.convert_async(prompt=prompt))  # type: ignore

    template_converter = TemplateSegmentConverter()
    print("Template Segment:", await template_converter.convert_async(prompt=prompt))  # type: ignore

    # %% Cell 5: Token Smuggling Converters

    from pyrit.prompt_converter import (
        AsciiSmugglerConverter,
        SneakyBitsSmugglerConverter,
        VariationSelectorSmugglerConverter,
    )

    prompt = "secret message"

    ascii_smuggler = AsciiSmugglerConverter(action="encode", unicode_tags=True)
    print("ASCII Smuggler:", await ascii_smuggler.convert_async(prompt=prompt))  # type: ignore

    sneaky_bits = SneakyBitsSmugglerConverter(action="encode")
    print("Sneaky Bits:", await sneaky_bits.convert_async(prompt=prompt))  # type: ignore

    var_selector = VariationSelectorSmugglerConverter(action="encode", embed_in_base=True)
    print("Variation Selector:", await var_selector.convert_async(prompt=prompt))  # type: ignore

    # %% Cell 6: LLM-Based Converters

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

    variation_converter_strategy = SeedPrompt.from_yaml_file(
        pathlib.Path(CONVERTER_SEED_PROMPT_PATH) / "variation_converter_prompt_softener.yaml"
    )
    variation_converter = VariationConverter(converter_target=attack_llm, prompt_template=variation_converter_strategy)
    print("Variation:", await variation_converter.convert_async(prompt=prompt))  # type: ignore

    noise_converter = NoiseConverter(converter_target=attack_llm)
    print("Noise:", await noise_converter.convert_async(prompt=prompt))  # type: ignore

    tone_converter = ToneConverter(converter_target=attack_llm, tone="angry")
    print("Tone (angry):", await tone_converter.convert_async(prompt=prompt))  # type: ignore

    translation_converter = TranslationConverter(converter_target=attack_llm, language="French")
    print("Translation (French):", await translation_converter.convert_async(prompt=prompt))  # type: ignore

    random_translation_converter = RandomTranslationConverter(
        converter_target=attack_llm, languages=["French", "German", "Spanish", "English"]
    )
    print("Random Translation:", await random_translation_converter.convert_async(prompt=prompt))  # type: ignore

    tense_converter = TenseConverter(converter_target=attack_llm, tense="far future")
    print("Tense (future):", await tense_converter.convert_async(prompt=prompt))  # type: ignore

    persuasion_converter = PersuasionConverter(converter_target=attack_llm, persuasion_technique="logical_appeal")
    print("Persuasion:", await persuasion_converter.convert_async(prompt=prompt))  # type: ignore

    denylist_converter = DenylistConverter(converter_target=attack_llm)
    print("Denylist Check:", await denylist_converter.convert_async(prompt=prompt))  # type: ignore

    malicious_question = MaliciousQuestionGeneratorConverter(converter_target=attack_llm)
    print("Malicious Question:", await malicious_question.convert_async(prompt=prompt))  # type: ignore

    toxic_generator = ToxicSentenceGeneratorConverter(converter_target=attack_llm)
    print("Toxic Sentence:", await toxic_generator.convert_async(prompt="building"))  # type: ignore

    math_prompt_converter = MathPromptConverter(converter_target=attack_llm)
    print("Math Prompt:", await math_prompt_converter.convert_async(prompt=prompt))  # type: ignore


if __name__ == "__main__":
    asyncio.run(main())
