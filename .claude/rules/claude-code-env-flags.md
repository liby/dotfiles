# Claude Code settings.json env flags

All env flags in `dot_claude/settings.json` were verified against CLI 2.1.150 binary. Every flag is present, referenced, and actively consumed. None have graduated to unconditional defaults or have equivalent top-level settings keys (except `effortLevel`). Do not suggest removing any of them.

## GrowthBook-gated flags (env override required)

Without the env var set to `"1"`, the feature depends on remote rollout status:

- `CLAUDE_CODE_NEW_INIT` (gate: `tengu_slate_harbor_experiment`)
- `CLAUDE_CODE_FORK_SUBAGENT` (gate: `tengu_copper_fox`)

## Value format: `mH()` (truthy) vs `tK()` (falsy)

CLI uses two parsers. Setting the wrong format is a silent no-op:

- `mH()` truthy: `"1"` / `"true"` / `"yes"` / `"on"` -> true. Used by most flags.
- `tK()` falsy: `"0"` / `"false"` / `"no"` / `"off"` -> true. Used by `CLAUDE_CODE_ATTRIBUTION_HEADER` and `ENABLE_CLAUDEAI_MCP_SERVERS` (disabling via `"0"` is correct).

## `attribution` section vs `CLAUDE_CODE_ATTRIBUTION_HEADER`

Both are active at different layers. The env var (`tK` check) controls whether the attribution header is injected into the system prompt. The `attribution` section (`commit`, `pr` keys) controls the template strings. Keeping both is correct.

## `CLAUDE_CODE_EFFORT_LEVEL` set via `env` (not `effortLevel`)

Env takes precedence over `effortLevel` and over `/effort` mid-session. On the current model's first launch, `effortLevel` in settings is shadowed by the model's hardcoded launch-default (CLI's `UhH()` resolver has a `q ? K` branch keyed on specific model IDs) until session state "unpins". Env sidesteps that. Accepted trade-off: `/effort` can't override live; restart to change. No other env flag has an equivalent top-level settings key.

## `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`

No-op under current model (CLI hardcodes the env to only apply when model contains `opus-4-6` or `sonnet-4-6`). Kept for future 4.6-series use; do not remove.
