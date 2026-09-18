# Oracle Non-Default Modes

## Model and effort

Use selection only for an explicit model, latest-model, or effort request. Inspect the installed version and its release-matched browser documentation/source when choosing an unfamiliar target or after an upgrade, option rejection, or picker-routing failure, then dry-run the exact command. Help may omit browser flags; omission alone does not prove removal.

An explicit model or latest-model request must pass `--browser-model-strategy select`. Without it the requested model is silently ignored while the preview still names it.

For an explicit latest-model + Pro request, use:

```bash
oracle --engine browser --browser-attach-running \
  --browser-model-strategy select --model latest --browser-thinking-time pro \
  -p "<task>" --file "<path-or-glob>"
```

Alias targets are release-specific; confirm the installed release's mapping after an upgrade instead of copying a historical one. For an effort-only request, retain `current` and add only the requested `--browser-thinking-time` value.

For a model-only request, pass `--browser-model-strategy select` and omit `--browser-thinking-time` unless an explicit value is needed to preserve a tier the user requested. Selection mode can inherit configured `browser.thinkingTime`, so omission alone does not prove preservation: establish the current tier and preserve it before submission, using the manual browser path if the CLI cannot establish that boundary.

Verify only the requested choices: model-selection evidence for a model constraint, and separate effort confirmation for an effort constraint. Pro selection fails closed. An unavailable requested selection is unresolved; do not quietly downgrade, switch to defaults, or claim a preview proves the UI selection. Manual fallback must verify the same requested choices visibly.

## Browser follow-up

Use repeated `--browser-follow-up "<message>"` options for planned turns in the root run. To continue later:

```bash
oracle --followup "<root-session-id>" -p "<message>"
```

Browser `--followup` reopens the parent's exact conversation, inherits its browser profile, configuration, and model, bypasses the picker, and disables Deep Research for the resumed turn; new model, effort, and other browser flags do not override it. If the requested selection differs from that configuration, including a later manual choice the user wants preserved, continue manually in the exact saved conversation and verify the choices before sending. Do not submit through the CLI and discover the ignored request afterward.

Set `--browser-archive never` on the root run when follow-up continuity is expected. Verify the completed root, the child's parent and saved conversation URL, the actual follow-up user turn, and a completed answer to that turn. Follow-ups normally skip model selection; do not require fresh-root picker evidence or infer that the model stayed unchanged from parent linkage alone.

Never guess a conversation from open tabs. If continuity is essential and the saved URL cannot be recovered, report the gap; otherwise start a fresh, self-contained root in the requested Project only after resolving the original run.

## Deep Research

Use `--browser-research deep` only when explicitly requested. Keep browser attach, Project, and any requested model route; omit `--browser-thinking-time` because Deep Research owns its effort flow. Do not combine it with `--browser-follow-up`. Require terminal completion, a non-empty report, and usable citations.

## Explicit API mode

After explicit API-billing consent, inspect current help and preflight only the requested model. Verify that `--route` matches the consented provider and pin that provider when billing or data boundaries differ. Run with explicit `--engine api` and `--model`; use the installed release's model-specific reasoning options, not browser thinking-time flags. Pro API runs detach by default: add `--wait`, or follow `oracle session <id>`; a returned ID is still pending.

API `--followup` applies to supported OpenAI or Azure Responses runs. Verify response/session lineage, requested model, and terminal output; browser picker and Project-URL gates do not apply. Never print credentials.
