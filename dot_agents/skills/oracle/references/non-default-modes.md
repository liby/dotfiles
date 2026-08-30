# Oracle Non-Default Modes

Load the matching section before a browser follow-up, Deep Research run, explicitly billed API run, or version/picker recovery.

## Browser follow-up

Use repeated `--browser-follow-up "<message>"` options for planned turns in the root run. To continue later:

```bash
oracle --followup "<root-session-id>" -p "<message>"
```

Add `--browser-archive never` when continuity is expected. A browser follow-up is valid when the verified GPT-5.6 Sol + Pro root completed, the child references that parent and its exact saved conversation URL, the conversation shows the follow-up message as its latest submitted user turn, and the child completes with a non-empty latest assistant answer to that turn. Command launch or child linkage alone is not lineage evidence. Its model selection is normally skipped and unverified; do not apply the fresh-root picker gate.

Never guess a conversation from open tabs. If continuity is essential and Oracle cannot recover the URL, stop and report the gap; otherwise start a fresh, self-contained root in the requested Project.

## Deep Research

Use `--browser-research deep` only when explicitly requested. Keep the browser, attach-running, `--model gpt-5.6-sol`, model-selection strategy, and Project route, but omit `--browser-thinking-time` because Deep Research owns its effort flow. Do not combine it with `--browser-follow-up`. Require terminal completion, a non-empty report, and usable citations.

## Explicit API mode

After explicit API-billing consent, inspect current help and preflight only the requested model. Verify that `--route` matches the provider covered by the consent and pin that provider with current CLI flags when billing or data boundaries differ. Run with explicit `--engine api` and `--model`. Pro API runs detach by default: add `--wait`, or inspect an already detached run with `oracle session <id>`; a returned session ID is still pending.

For an explicitly requested GPT-5.6 Pro API run, use `--model gpt-5.6-sol`, `--reasoning-mode pro`, and `--reasoning-effort max` through a consented OpenAI or Azure Responses route. Do not invent a combined Pro model slug or apply the API reasoning flags to browser mode.

API `--followup` applies to supported OpenAI or Azure Responses runs. Verify response/session lineage, the requested model, and terminal output; browser picker and conversation-URL gates do not apply. Avoid printing credentials, hardcoded provider catalogs, or arbitrary timeouts.

## Version boundary

Inspect the version, release, and exact-command dry run after install or upgrade, option rejection, or picker-routing failure. Browser flags may be intentionally hidden from help, so help omission alone does not prove removal; inspect the reviewed source when parsing or behavior differs. If the installed version and reviewed ref differ, re-identify the latest supported ChatGPT model and update the default model slug, expected target, provenance, and validator contract together. Do not assume a legacy Pro alias tracks the latest model, and do not add a compatibility branch without an observed caller.
