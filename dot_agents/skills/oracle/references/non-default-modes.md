# Oracle Non-Default Modes

## Model and effort

Use selection only for an explicit model, latest-model, or effort request. Inspect the installed version and its release-matched browser documentation/source when choosing an unfamiliar target or after an upgrade, option rejection, or picker-routing failure, then dry-run the exact command. Help may omit browser flags; omission alone does not prove removal.

An explicit model or latest-model request must pass `--browser-model-strategy select`. Without it the requested model is silently ignored while the preview still names it. The generic Pro aliases (`gpt-5-pro`, `gpt-5.1-pro`, `gpt-5.2-pro`, `gpt-5.4-pro`) all select GPT-5.6 Sol, so only `gpt-5.5-pro` pins GPT-5.5. A resolved `pro` effort, including the automatic `pro` a Pro model selects, or a Pro model with `extended` fails closed; another requested effort still submits when its selection is unavailable and records `unverified`, so require `verified=yes` with `already-selected` or `switched` before accepting it. An unavailable model fails the run instead.

For an explicit latest-model + Pro request, use:

```bash
oracle --engine browser --browser-attach-running --browser-approval-wait 30m \
  --browser-model-strategy select --model latest --browser-thinking-time pro \
  -p "<task>" --file "<path-or-glob>"
```

For an effort-only request, retain `current` and add only the requested `--browser-thinking-time` value.

For a model-only request, omit `--browser-thinking-time` unless an explicit value is needed to preserve a tier the user requested. Selection mode can inherit configured `browser.thinkingTime`, so omission alone does not prove preservation: establish the current tier and preserve it before submission, using the manual browser path if the CLI cannot establish that boundary.

Verify only the requested choices: model-selection evidence for a model constraint, and separate effort confirmation for an effort constraint. Pro selection fails closed. An unavailable requested selection is unresolved; do not quietly downgrade, switch to defaults, or claim a preview proves the UI selection. Manual fallback must verify the same requested choices visibly.

## Browser follow-up

Use repeated `--browser-follow-up "<message>"` options for planned turns in the root run. To continue later:

```bash
oracle --followup "<root-session-id>" -p "<message>"
```

Browser `--followup` reopens the parent's exact conversation, inherits its browser profile, configuration, and model, bypasses the picker, and disables Deep Research for the resumed turn; new model, effort, and other browser flags do not override it. An existing Work conversation cannot be resumed as an ordinary Chat, so a follow-up needs a Chat conversation; start a new one when the root is Work. If the requested selection differs from that configuration, including a later manual choice the user wants preserved, continue manually in the exact saved conversation and verify the choices before sending. Do not submit through the CLI and discover the ignored request afterward.

`--browser-follow-up` turns carry no attachments, so a file a later turn needs must be in the root `--file` or a new `oracle --followup <id> -p "<message>" --file "<path>"`.

Set `--browser-archive never` on the root run when follow-up continuity is expected. Verify the completed root, the child's parent and saved conversation URL, the actual follow-up user turn, and a completed answer to that turn. Follow-ups normally skip model selection; do not require fresh-root picker evidence or infer that the model stayed unchanged from parent linkage alone.

Never guess a conversation from open tabs. If continuity is essential and the saved URL cannot be recovered, report the gap; otherwise start a fresh, self-contained root in the requested Project only after resolving the original run.

## Deep Research

Use `--browser-research deep` only when explicitly requested. Keep browser attach, Project, any requested model route, and any requested `--browser-thinking-time`; Deep Research uses the same effort picker and does not suppress an explicit selection. Do not combine it with `--browser-follow-up`. The main page cannot see the sandbox iframe, so a `--live`/`--harvest` completion signal or placeholder text (`called tool`, `planning`, the planning panel) is not the report; re-attach to the same research rather than starting a new one, and treat a re-attach timeout as pending, not failed. Require terminal completion, a non-empty report, and usable citations.

## Explicit API mode

After explicit API-billing consent, inspect current help and preflight only the requested model. Verify that `--route` matches the consented provider and pin that provider when billing or data boundaries differ. Run with explicit `--engine api` and `--model`; use the installed release's model-specific reasoning options, not browser thinking-time flags. Name the model in the billing consent and do not inherit the default `gpt-5.5-pro`, because API billing consent is not Pro consent. `--search` defaults on, so pass `--search off` unless the consultation may send the prompt to the search tool. Supply the key through `envchain <namespace> oracle --engine api ...`, and stop for the user to `envchain --set` when no namespace exists. A binary `--file` is UTF-8-decoded into `input_text`, so convert non-text inputs to reliable text, and confirm a parent session logged a `resp_` id before continuing it. Pro API runs detach by default: add `--wait`, or follow `oracle session <id>`; a returned ID is still pending.

API `--followup` applies to supported OpenAI or Azure Responses runs. Verify response/session lineage, requested model, and terminal output; browser picker and Project-URL gates do not apply. Never print credentials.
