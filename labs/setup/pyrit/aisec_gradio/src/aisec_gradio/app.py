"""Gradio workshop: Setup tab + Red Team (sections, coach, PyRIT runners)."""

from __future__ import annotations

import os

import gradio as gr

from aisec_gradio.builtin_sample_code import (
    BUILTIN_DATASETS_SAMPLE,
    DATASET_WRITING_SAMPLE,
    OPENAI_CHAT_TARGET_SAMPLE,
    SEED_PROGRAMMING_SAMPLE,
)
from aisec_gradio.coach import invoke_coach_graph
from aisec_gradio.content_loader import load_content_markdown
from aisec_gradio.env_manager import load_for_ui, save_openai_compatible, save_openai_native
from aisec_gradio.runners import run_assignment
from aisec_gradio.workshop_registry import (
    SECTIONS,
    assignment_by_ids,
    default_assignment_key,
    parse_assignment_key,
    radio_choices_for_section,
)


def workshop_ocean_theme() -> gr.themes.Base:
    """Standard Gradio Ocean theme (cool blues / teals)."""
    return gr.themes.Ocean()


def _refresh_setup() -> tuple:
    data = load_for_ui()
    main_json = "\n".join(f"{k}: {v}" for k, v in sorted(data["display_main"].items()))
    local_json = "\n".join(f"{k}: {v}" for k, v in sorted(data["display_local"].items()))
    return (
        gr.update(value=data["mode"]),
        gr.update(value=data["openai_api_key"]),
        gr.update(value=data["native_model"]),
        gr.update(value=data["endpoint"]),
        gr.update(value=data["platform_api_key"]),
        gr.update(value=data["model"]),
        gr.update(value=main_json),
        gr.update(value=local_json),
    )


def _on_preset(preset: str) -> tuple:
    if preset == "Groq":
        return (
            gr.update(value="https://api.groq.com/openai/v1"),
            gr.update(value="qwen/qwen3-32b"),
        )
    if preset == "Together":
        return (
            gr.update(value="https://api.together.xyz/v1"),
            gr.update(value="meta-llama/Llama-3.3-70B-Instruct-Turbo"),
        )
    return gr.update(), gr.update()


def _build_panel_for_assignment(key: str) -> tuple:
    """Returns (summary_md, learner_md, code_str, objective_visibility_update)."""
    try:
        sid, aid = parse_assignment_key(key)
    except ValueError:
        return (
            "Invalid selection.",
            "",
            "# error\n",
            gr.update(visible=False),
        )
    meta = assignment_by_ids(sid, aid)
    if not meta:
        return (
            "Unknown assignment.",
            "",
            "# error\n",
            gr.update(visible=False),
        )
    summary = load_content_markdown(meta["summary_relpath"])
    ref = meta.get("doc_url", "")
    if ref:
        summary += f"\n\n**Reference:** [{ref}]({ref})"

    if key == "datasets:builtin":
        learner = (
            "**Exfil (benign):** copy the **intel script** below or hit **Run for me** to dump registered "
            "dataset handles on this host — no bulk pull, low noise."
        )
        code = BUILTIN_DATASETS_SAMPLE
    elif key == "prompt_targets:openai_chat":
        learner = (
            "**Live range:** arm **Setup**, paste the payload locally, or debrief the coach on "
            "`OpenAIChatTarget` + `PromptSendingAttack` tradecraft."
        )
        code = OPENAI_CHAT_TARGET_SAMPLE
    elif key == "datasets:seed_programming":
        learner = (
            "**Run for me** runs the same **seed-group → parameter extraction** demo as the sample (needs **Setup** "
            "for `OpenAIChatTarget` init; no model fire). Full playbook: `PyRIT/doc/code/datasets/2_seed_programming.py`."
        )
        code = SEED_PROGRAMMING_SAMPLE
    elif key == "datasets:dataset_writing":
        learner = (
            "**Run for me** prints the bundled **tight** `SeedObjective` example. Cross-check with "
            "[dataset-writing](https://azure.github.io/PyRIT/code/datasets/dataset-writing/)."
        )
        code = DATASET_WRITING_SAMPLE
    else:
        learner = (
            "**Run for me** executes the workshop sample for this assignment when a runner is defined; "
            "otherwise you will see a short stub message."
        )
        code = "# (No bundled sample code for this assignment yet.)\n# See the reference link above.\n"

    obj_vis = key == "executors:prompt_sending"
    return summary, learner, code, gr.update(visible=obj_vis)


def build_app() -> gr.Blocks:
    data = load_for_ui()
    start_key = default_assignment_key()

    with gr.Blocks(title="AISec // PyRIT red cell") as demo:
        gr.Markdown(
            "# `AISec` // PyRIT **red cell**\n"
            "> *Authorized testing only — own systems or explicit written permission.*\n\n"
            "Arm **Setup** (`~/.pyrit`), then pivot to **Red Team** for lab assignments, **coach** intel, and "
            "**Run for me** payloads where a runner exists."
        )
        with gr.Tabs():
            with gr.Tab("Setup"):
                gr.Markdown(
                    "Writes `~/.pyrit/.env` and `.env.local` (same contract as PyRIT Docker). "
                    "Only use keys you are allowed to use. **Do not commit secrets.**"
                )
                with gr.Row():
                    mode = gr.Radio(
                        choices=["openai_native", "openai_compatible"],
                        value=data["mode"],
                        label="Connection mode",
                        info="Native OpenAI vs. OpenAI-compatible (Groq, Together, Azure OpenAI-compatible, etc.)",
                    )
                    refresh_btn = gr.Button("Refresh from disk")

                with gr.Row(visible=data["mode"] == "openai_native") as native_box:
                    native_key = gr.Textbox(
                        label="OPENAI_API_KEY",
                        value=data["openai_api_key"],
                        type="password",
                        lines=1,
                    )
                    native_model = gr.Textbox(
                        label="Model (OpenAIChatTarget)",
                        value=data.get("native_model", "gpt-4o"),
                        info="e.g. gpt-4o, gpt-4o-mini",
                    )

                with gr.Row(visible=data["mode"] == "openai_compatible") as compat_box:
                    preset = gr.Dropdown(
                        choices=["Custom", "Groq", "Together"],
                        value="Custom",
                        label="Quick preset (URL / model hints)",
                    )
                    endpoint = gr.Textbox(
                        label="Base URL (OpenAI-compatible)",
                        value=data["endpoint"],
                    )
                    platform_key = gr.Textbox(
                        label="API key",
                        value=data["platform_api_key"],
                        type="password",
                    )
                    model_id = gr.Textbox(
                        label="Model id",
                        value=data["model"],
                    )

                save_btn = gr.Button("Save credentials", variant="primary")
                setup_status = gr.Markdown()

                with gr.Accordion("Current masked keys (read-only)", open=False):
                    main_preview = gr.Textbox(
                        label="~/.pyrit/.env",
                        value="\n".join(f"{k}: {v}" for k, v in sorted(data["display_main"].items())),
                        lines=8,
                    )
                    local_preview = gr.Textbox(
                        label="~/.pyrit/.env.local",
                        value="\n".join(f"{k}: {v}" for k, v in sorted(data["display_local"].items())),
                        lines=8,
                    )

                def toggle_mode(m: str):
                    return (
                        gr.update(visible=(m == "openai_native")),
                        gr.update(visible=(m == "openai_compatible")),
                    )

                mode.change(toggle_mode, [mode], [native_box, compat_box])

                def do_save(
                    m: str,
                    nk: str,
                    nmod: str,
                    ep: str,
                    pk: str,
                    mid: str,
                ):
                    try:
                        if m == "openai_native":
                            s1, s2 = save_openai_native(nk, model=nmod or "gpt-4o")
                        else:
                            s1, s2 = save_openai_compatible(ep, pk, mid)
                        return f"✅ {s1}\n{s2}"
                    except Exception as e:
                        return f"**Error:** `{e}`"

                save_btn.click(
                    do_save,
                    [mode, native_key, native_model, endpoint, platform_key, model_id],
                    [setup_status],
                )

                refresh_btn.click(
                    _refresh_setup,
                    [],
                    [
                        mode,
                        native_key,
                        native_model,
                        endpoint,
                        platform_key,
                        model_id,
                        main_preview,
                        local_preview,
                    ],
                )

                preset.change(_on_preset, [preset], [endpoint, model_id])

            with gr.Tab("Red Team"):
                gr.Markdown(
                    "Select a **section** (left), choose an **assignment**, ingest the **briefing** + **sample "
                    "payload**, then task the **coach** or trigger **Run for me**."
                )
                s0, l0, c0, _ = _build_panel_for_assignment(start_key)

                def _coach_welcome_for_key(key: str) -> list:
                    """Intro message so the coach points at the summary + sample code."""
                    try:
                        sid, aid = parse_assignment_key(key)
                    except ValueError:
                        return []
                    meta = assignment_by_ids(sid, aid)
                    if not meta:
                        return []
                    title = meta.get("title", "Assignment")
                    return [
                        {
                            "role": "assistant",
                            "content": (
                                f"**`OP` // {title}**\n\n"
                                "Review the **briefing** and **sample payload** above. **Run for me** fires the "
                                "bundled runner on *this* host when defined; otherwise interrogate me on tactics, "
                                "PyRIT APIs, or your authorized scenario."
                            ),
                        }
                    ]

                with gr.Row():
                    with gr.Column(scale=1, min_width=220):
                        for sec in SECTIONS:
                            sid = sec["id"]
                            choices = radio_choices_for_section(sid)
                            # Gradio Radio: (label, value) — default must be the internal value (assignment key).
                            default_val = choices[0][1] if choices else None
                            with gr.Accordion(sec["title"], open=(sid == "datasets")):
                                r = gr.Radio(
                                    choices=choices,
                                    value=default_val,
                                    label="",
                                    elem_classes=["aisec-assignment-radio"],
                                )
                                if sid == "datasets":
                                    radio_datasets = r
                                elif sid == "prompt_targets":
                                    radio_prompt_targets = r
                                elif sid == "converters":
                                    radio_converters = r
                                else:
                                    radio_executors = r

                    with gr.Column(scale=4):
                        summary_md = gr.Markdown(value=s0)
                        learner_md = gr.Markdown(value=l0)
                        code_panel = gr.Code(
                            value=c0,
                            language="python",
                            label="Sample code (copy and run locally)",
                        )
                        assign_state = gr.State(start_key)
                        chat = gr.Chatbot(
                            label="Coach",
                            height=360,
                            value=_coach_welcome_for_key(start_key),
                            allow_tags=["details", "summary", "pre", "code"],
                        )
                        msg = gr.Textbox(
                            label="Task the coach",
                            placeholder="Request tradecraft, API clarifications, or in-scope debrief…",
                            lines=2,
                        )
                        with gr.Row():
                            send = gr.Button("Transmit", variant="primary")
                            clear = gr.Button("Clear chat")

                        objective = gr.Textbox(
                            label="Objective (Prompt sending attack only)",
                            placeholder="Benign lab objective text for PromptSendingAttack…",
                            lines=2,
                            visible=(start_key == "executors:prompt_sending"),
                        )
                        run_btn = gr.Button("Run for me", variant="secondary")
                        run_out = gr.Markdown()

                def _apply_assignment_change(key: str):
                    s, l, c, vis = _build_panel_for_assignment(key)
                    return (
                        gr.update(value=s),
                        gr.update(value=l),
                        gr.update(value=c),
                        vis,
                        _coach_welcome_for_key(key),
                    )

                def chat_fn(message: str, history: list, key: str):
                    if not message or not str(message).strip():
                        return history
                    try:
                        reply = invoke_coach_graph(key, history, message.strip())
                    except Exception as e:
                        reply = f"**Error:** {e}\n\nCheck the **Setup** tab and `~/.pyrit` credentials."
                    history = list(history or [])
                    history.append({"role": "user", "content": message.strip()})
                    history.append({"role": "assistant", "content": reply})
                    return history

                def _set_from_datasets(v: str):
                    return _apply_assignment_change(v) + (v,)

                def _set_from_prompt_targets(v: str):
                    return _apply_assignment_change(v) + (v,)

                def _set_from_converters(v: str):
                    return _apply_assignment_change(v) + (v,)

                def _set_from_executors(v: str):
                    return _apply_assignment_change(v) + (v,)

                # Unhook generic for loop — replace with four explicit handlers including state
                radio_datasets.change(
                    _set_from_datasets,
                    [radio_datasets],
                    [summary_md, learner_md, code_panel, objective, chat, assign_state],
                )
                radio_prompt_targets.change(
                    _set_from_prompt_targets,
                    [radio_prompt_targets],
                    [summary_md, learner_md, code_panel, objective, chat, assign_state],
                )
                radio_converters.change(
                    _set_from_converters,
                    [radio_converters],
                    [summary_md, learner_md, code_panel, objective, chat, assign_state],
                )
                radio_executors.change(
                    _set_from_executors,
                    [radio_executors],
                    [summary_md, learner_md, code_panel, objective, chat, assign_state],
                )

                send.click(
                    chat_fn,
                    [msg, chat, assign_state],
                    [chat],
                ).then(lambda: "", outputs=[msg])
                msg.submit(
                    chat_fn,
                    [msg, chat, assign_state],
                    [chat],
                ).then(lambda: "", outputs=[msg])
                clear.click(lambda: ([], ""), [], [chat, run_out])

                def do_run(key: str, obj: str) -> str:
                    try:
                        sid, aid = parse_assignment_key(key)
                    except ValueError:
                        return "Invalid assignment."
                    meta = assignment_by_ids(sid, aid)
                    if not meta:
                        return "Unknown assignment."
                    rid = meta.get("runner_id", "stub")
                    return run_assignment(rid, objective=obj or "")

                run_btn.click(do_run, [assign_state, objective], [run_out])

        gr.Markdown(
            "PyRIT documentation: [Loading datasets](https://azure.github.io/PyRIT/code/datasets/loading-datasets/). "
            "AISecWorkshops: [jailbreaks labs]"
            "(https://github.com/emulateai-dev/AISecWorkshops/tree/main/labs/llms/red-teaming/jailbreaks)."
        )

    return demo


def launch() -> None:
    """Entry point for `python -m aisec_gradio`."""
    host = os.environ.get("GRADIO_SERVER_NAME", "0.0.0.0")
    port = int(os.environ.get("GRADIO_SERVER_PORT", "7860"))
    demo = build_app()
    demo.launch(
        server_name=host,
        server_port=port,
        theme=workshop_ocean_theme(),
        css="footer.gradio-footer { opacity: 0.65; }",
    )
