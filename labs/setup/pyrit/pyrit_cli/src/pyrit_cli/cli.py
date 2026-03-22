"""Typer entry: setup, redteam, discover."""

from __future__ import annotations

import importlib.metadata
import json

import typer

from pyrit_cli import __version__
from pyrit_cli.discover.converters_list import list_converters_json, list_converters_text
from pyrit_cli.discover.datasets_list import list_datasets_text
from pyrit_cli.discover.scorers_list import list_scorers_text
from pyrit_cli.discover.targets_list import list_targets_text
from pyrit_cli.ask_ai import run_ask_ai
from pyrit_cli.env_status import (
    GUIDE_TEXT,
    ensure_pyrit_dir,
    env_path,
    format_setup_report,
    load_for_cli,
    parse_env_file,
    pyrit_dir,
)
from pyrit_cli.env_write import save_openai_compatible, save_openai_native
from pyrit_cli.redteam.prompt_sending import collect_objectives, run_prompt_sending
from pyrit_cli.redteam.red_teaming import parse_memory_labels_json, run_red_teaming
from pyrit_cli.redteam.tap_attack import run_tap_attack


def _version_callback(value: bool) -> None:
    if not value:
        return
    try:
        pyrit_ver = importlib.metadata.version("pyrit")
    except importlib.metadata.PackageNotFoundError:
        pyrit_ver = "unknown"
    typer.echo(f"pyrit-cli {__version__}, pyrit {pyrit_ver}")
    raise typer.Exit()


app = typer.Typer(
    no_args_is_help=True,
    help="AISec workshop CLI for PyRIT setup and red-team flows. Try: pyrit-cli ask-ai | setup configure | converters list",
)


@app.callback()
def _main(
    _version: bool = typer.Option(
        False,
        "--version",
        help="Show versions and exit.",
        callback=_version_callback,
        is_eager=True,
    ),
) -> None:
    """AISec workshop CLI for PyRIT setup and red-team flows."""
    return


@app.command("ask-ai")
def ask_ai_cmd(
    query: str = typer.Argument(..., help="Describe what you want to do with pyrit-cli."),
    model: str | None = typer.Option(
        None,
        "--model",
        help="Chat model for this helper call (default: gpt-4o-mini or OPENAI_CHAT_MODEL).",
    ),
    api_key: str | None = typer.Option(
        None,
        "--api-key",
        help="API key for the helper call (else OPENAI_API_KEY / OPENAI_CHAT_KEY after loading ~/.pyrit).",
    ),
    base_url: str | None = typer.Option(
        None,
        "--base-url",
        help="Chat API base URL (else OPENAI_CHAT_ENDPOINT or https://api.openai.com/v1).",
    ),
) -> None:
    """Suggest a pyrit-cli command using bundled HELP.md and a chat API (authorized use only)."""
    typer.secho(
        "Suggestions are for authorized testing only; verify commands before running.",
        err=True,
        fg=typer.colors.YELLOW,
    )
    try:
        typer.echo(run_ask_ai(query, model=model, api_key=api_key, base_url=base_url))
    except (ValueError, FileNotFoundError, RuntimeError) as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e


setup_app = typer.Typer(help="Inspect and configure ~/.pyrit env (aligned with aisec-gradio Setup).")
app.add_typer(setup_app, name="setup")


def _print_setup_status() -> None:
    typer.echo(format_setup_report(load_for_cli()))


@setup_app.callback(invoke_without_command=True)
def _setup_group(ctx: typer.Context) -> None:
    if ctx.invoked_subcommand is None:
        _print_setup_status()


@setup_app.command("status")
def setup_status() -> None:
    _print_setup_status()


@setup_app.command("guide")
def setup_guide() -> None:
    typer.echo(GUIDE_TEXT)


@setup_app.command("configure")
def setup_configure() -> None:
    """Interactive wizard: write OpenAI or OpenAI-compatible credentials to ~/.pyrit/.env and .env.local."""
    ensure_pyrit_dir()
    root = pyrit_dir()
    typer.echo(f"PyRIT config directory: {root}")
    main = parse_env_file(env_path(".env"))
    has_native = bool(main.get("OPENAI_API_KEY", "").strip())
    has_platform = bool(main.get("PLATFORM_OPENAI_CHAT_ENDPOINT", "").strip())
    if has_native or has_platform:
        if not typer.confirm(
            "Existing API configuration found in .env. Replace it with this wizard?",
            default=False,
        ):
            raise typer.Exit(0)

    choice = typer.prompt("Provider [1] OpenAI (api.openai.com)  [2] OpenAI-compatible (e.g. Groq)", default="1")
    c = choice.strip()
    if c not in ("1", "2"):
        typer.secho("Invalid choice; use 1 or 2.", err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1)
    if c == "2":
        endpoint = typer.prompt("API base URL", default="https://api.groq.com/openai/v1")
        key = typer.prompt("API key", hide_input=True)
        if not key.strip():
            typer.secho("API key is required.", err=True, fg=typer.colors.RED)
            raise typer.Exit(code=1)
        model = typer.prompt("Model name", default="llama-3.3-70b-versatile")
        m1, m2 = save_openai_compatible(endpoint, key, model)
        typer.secho(m1, fg=typer.colors.GREEN)
        typer.secho(m2, fg=typer.colors.GREEN)
    else:
        key = typer.prompt("OpenAI API key", hide_input=True)
        if not key.strip():
            typer.secho("API key is required.", err=True, fg=typer.colors.RED)
            raise typer.Exit(code=1)
        model = typer.prompt("Default chat model", default="gpt-4o")
        m1, m2 = save_openai_native(key, model=model)
        typer.secho(m1, fg=typer.colors.GREEN)
        typer.secho(m2, fg=typer.colors.GREEN)

    typer.echo("")
    typer.echo("Current status (masked):")
    typer.echo(format_setup_report(load_for_cli()))
    typer.echo("")
    typer.echo("Example: pyrit-cli redteam prompt-sending-attack --target openai:gpt-4o-mini --objective \"Reply: OK\"")


redteam_app = typer.Typer(
    help="Run PyRIT attacks. Stateless converter keys: pyrit-cli converters list-keys.",
)
app.add_typer(redteam_app, name="redteam")


@redteam_app.callback(invoke_without_command=True)
def _redteam_group(ctx: typer.Context) -> None:
    if ctx.invoked_subcommand is None:
        typer.echo("Commands:")
        typer.echo("  prompt-sending-attack — single-turn PromptSendingAttack.")
        typer.echo("  red-teaming-attack    — multi-turn RedTeamingAttack.")
        typer.echo("  tap-attack            — Tree of Attacks with Pruning (TAPAttack).")
        typer.echo("Discover: converters list | scorers list | targets list | datasets list")
        typer.echo("Full workshop UI: pip install aisec-gradio && aisec-gradio")


@redteam_app.command("prompt-sending-attack")
def redteam_prompt_sending(
    target: str = typer.Option(..., "--target", help="openai:<model_name>"),
    objective: str | None = typer.Option(None, "--objective", help="Single objective string."),
    dataset: str | None = typer.Option(
        None,
        "--dataset",
        help="pyrit:relative/path.yaml under PyRIT datasets, or hf:org/dataset",
    ),
    hf_split: str = typer.Option("train", "--hf-split"),
    hf_column: str = typer.Option("text", "--hf-column"),
    hf_config: str | None = typer.Option(None, "--hf-config"),
    limit: int | None = typer.Option(None, "--limit", help="Max objectives (after load).", min=1),
) -> None:
    try:
        objectives = collect_objectives(
            objective,
            dataset,
            hf_split=hf_split,
            hf_column=hf_column,
            hf_config=hf_config,
            limit=limit,
        )
    except (ValueError, FileNotFoundError, ImportError) as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e

    typer.secho(
        "Authorized red-teaming only. You are responsible for targets, credentials, and policy.",
        err=True,
        fg=typer.colors.YELLOW,
    )
    try:
        run_prompt_sending(target, objectives)
    except Exception as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e


@redteam_app.command("red-teaming-attack")
def redteam_red_teaming(
    objective_target: str = typer.Option(
        ...,
        "--objective-target",
        help="Victim model: openai:<model_name>",
    ),
    objective: str = typer.Option(..., "--objective", help="Attack objective string."),
    adversarial_target: str | None = typer.Option(
        None,
        "--adversarial-target",
        help="Red-team LLM openai:<model>; default: same as --objective-target",
    ),
    max_turns: int = typer.Option(5, "--max-turns", min=1),
    rta_prompt: str = typer.Option(
        "text_generation",
        "--rta-prompt",
        help="text_generation | image_generation | naive_crescendo | violent_durian | crucible",
    ),
    memory_labels_json: str | None = typer.Option(
        None,
        "--memory-labels-json",
        help='Optional JSON object of string labels, e.g. \'{"harm_category":"demo"}\'',
    ),
    scorer_preset: str = typer.Option(
        "self-ask-tf",
        "--scorer-preset",
        help="self-ask-tf | self-ask-refusal",
    ),
    true_description: str | None = typer.Option(
        None,
        "--true-description",
        help="Required for self-ask-tf: criterion for True (objective met).",
    ),
    refusal_mode: str = typer.Option(
        "default",
        "--refusal-mode",
        help="For self-ask-refusal: default | strict",
    ),
    scorer_chat_target: str | None = typer.Option(
        None,
        "--scorer-chat-target",
        help="openai:<model> for scorer LLM; default: adversarial target",
    ),
    request_converter: list[str] | None = typer.Option(
        None,
        "--request-converter",
        help="Stack stateless converters (order matters). Run: pyrit-cli converters list-keys",
    ),
    response_converter: list[str] | None = typer.Option(
        None,
        "--response-converter",
        help="Response-side converter stack.",
    ),
    include_adversarial_conversation: bool = typer.Option(
        False,
        "--include-adversarial-conversation",
        help="Print red-team LLM conversation in the report.",
    ),
) -> None:
    try:
        memory_labels = parse_memory_labels_json(memory_labels_json)
    except (ValueError, json.JSONDecodeError) as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e

    typer.secho(
        "Authorized red-teaming only. You are responsible for targets, credentials, and policy.",
        err=True,
        fg=typer.colors.YELLOW,
    )
    try:
        run_red_teaming(
            objective_target_spec=objective_target,
            adversarial_target_spec=adversarial_target,
            objective=objective,
            max_turns=max_turns,
            rta_prompt=rta_prompt,
            memory_labels=memory_labels,
            scorer_preset=scorer_preset,
            true_description=true_description,
            refusal_mode=refusal_mode,
            scorer_chat_spec=scorer_chat_target,
            request_converter_keys=list(request_converter or []),
            response_converter_keys=list(response_converter or []),
            include_adversarial_conversation=include_adversarial_conversation,
        )
    except ValueError as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e
    except Exception as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e


@redteam_app.command("tap-attack")
def redteam_tap_attack(
    objective_target: str = typer.Option(
        ...,
        "--objective-target",
        help="Victim model: openai:<model_name>",
    ),
    objective: str = typer.Option(..., "--objective", help="Conversation objective for TAP."),
    adversarial_target: str | None = typer.Option(
        None,
        "--adversarial-target",
        help="Red-team LLM openai:<model>; default: same as --objective-target",
    ),
    adversarial_temperature: float | None = typer.Option(
        None,
        "--adversarial-temperature",
        help="Optional temperature for adversarial OpenAIChatTarget (e.g. 1.1).",
    ),
    tree_width: int = typer.Option(4, "--tree-width", min=1),
    tree_depth: int = typer.Option(5, "--tree-depth", min=1),
    branching_factor: int = typer.Option(2, "--branching-factor", min=1),
    on_topic_checking_enabled: bool = typer.Option(
        True,
        "--on-topic-checking/--no-on-topic-checking",
        help="Enable on-topic relevance checks (PyRIT TAP).",
    ),
    desired_response_prefix: str = typer.Option(
        "Sure, here is",
        "--desired-response-prefix",
        help="Prefix TAP treats as strong signal of jailbreak success.",
    ),
    batch_size: int = typer.Option(10, "--batch-size", min=1),
    memory_labels_json: str | None = typer.Option(
        None,
        "--memory-labels-json",
        help='Optional JSON object of string labels.',
    ),
    scorer_chat_target: str | None = typer.Option(
        None,
        "--scorer-chat-target",
        help="openai:<model> for SelfAskScaleScorer inside FloatScaleThresholdScorer; default: adversarial",
    ),
    score_threshold: float | None = typer.Option(
        None,
        "--score-threshold",
        help="Jailbreak score threshold (0-1). If set with defaults, builds custom TAP scoring.",
    ),
    include_adversarial_conversation: bool = typer.Option(
        True,
        "--include-adversarial-conversation/--no-include-adversarial-conversation",
    ),
    include_pruned_conversations: bool = typer.Option(
        True,
        "--include-pruned-conversations/--no-include-pruned-conversations",
    ),
) -> None:
    try:
        memory_labels = parse_memory_labels_json(memory_labels_json)
    except (ValueError, json.JSONDecodeError) as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e

    typer.secho(
        "Authorized red-teaming only. TAP is high-cost and high-risk; use only on approved targets.",
        err=True,
        fg=typer.colors.YELLOW,
    )
    try:
        run_tap_attack(
            objective_target_spec=objective_target,
            objective=objective,
            adversarial_target_spec=adversarial_target,
            adversarial_temperature=adversarial_temperature,
            tree_width=tree_width,
            tree_depth=tree_depth,
            branching_factor=branching_factor,
            on_topic_checking_enabled=on_topic_checking_enabled,
            desired_response_prefix=desired_response_prefix,
            batch_size=batch_size,
            memory_labels=memory_labels,
            scorer_chat_spec=scorer_chat_target,
            score_threshold=score_threshold,
            include_adversarial_conversation=include_adversarial_conversation,
            include_pruned_conversations=include_pruned_conversations,
        )
    except ValueError as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e
    except Exception as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e


converters_app = typer.Typer(help="Discover PyRIT prompt converters (modalities).")
app.add_typer(converters_app, name="converters")


@converters_app.command("list")
def converters_list(json_out: bool = typer.Option(False, "--json", help="JSON output")) -> None:
    try:
        typer.echo(list_converters_json() if json_out else list_converters_text())
    except Exception as e:
        typer.secho(str(e), err=True, fg=typer.colors.RED)
        raise typer.Exit(code=1) from e


@converters_app.command("list-keys")
def converters_list_keys() -> None:
    from pyrit_cli.registries.converters import list_converter_keys

    typer.echo("Stateless CLI keys for --request-converter / --response-converter:")
    for k in list_converter_keys():
        typer.echo(f"  {k}")


scorers_app = typer.Typer(help="Scorer presets and PyRIT score exports.")
app.add_typer(scorers_app, name="scorers")


@scorers_app.command("list")
def scorers_list_cmd() -> None:
    typer.echo(list_scorers_text())


targets_app = typer.Typer(help="CLI-supported target patterns.")
app.add_typer(targets_app, name="targets")


@targets_app.command("list")
def targets_list_cmd() -> None:
    typer.echo(list_targets_text())


datasets_app = typer.Typer(help="Bundled PyRIT seed dataset paths.")
app.add_typer(datasets_app, name="datasets")


@datasets_app.command("list")
def datasets_list_cmd(
    glob_pattern: str | None = typer.Option(
        None,
        "--glob",
        help="fnmatch pattern against path under seed_datasets (e.g. '*airt*')",
    ),
) -> None:
    typer.echo(list_datasets_text(glob_pattern=glob_pattern))
