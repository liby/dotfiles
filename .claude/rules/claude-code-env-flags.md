# Claude Code settings.json env flags

This file is the guardrail against cleanup passes on `dot_claude/settings.json`, covering the env flags plus the non-obvious plain settings (`attribution`, `permissions` + auto mode, the `skip*` dialog flags). Every env flag set there is verified present in the CLI binary and actively consumed; several look wrong to a cold reader, and a few break things when normalized to a more conventional form. Before removing or changing one, read its section here. Flags without a section (`CLAUDE_AUTO_BACKGROUND_TASKS`, `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR`, `MCP_CONNECTION_NONBLOCKING`, and the self-describing disable toggles) are deliberate too. Official reference: [settings docs](https://code.claude.com/docs/en/settings).

## Maintenance protocol

- Record conclusions, not changelog: no CLI-version audit chains, no inventory of upstream flags we do not set, no model-version narrative. Git history carries provenance.
- Cite stable anchors: env var name, GrowthBook gate (`tengu_*`), settings key, or a log/effect string. Never minified JS symbols; they reshuffle every build, so they neither grep nor explain.
- Re-verify a claim by grepping the env name in the binary: `rg -a -o` over `~/.local/share/claude/versions/<ver>` (Mach-O). The `~/.local/bin/claude` symlink tracks the newest installed version; auto-update prunes older ones.

## `DISABLE_TELEMETRY=1` and GrowthBook gating

`DISABLE_TELEMETRY=1` is a deliberate privacy keep, not a cleanup target, and its side effect shapes this whole file: it kills the GrowthBook fetch (`/doctor` shows `isGrowthBookEnabled=false`, `growthBookLastFetched=never`), so feature gates resolve from the binary's build-time snapshot and server-side rollouts never reach this install. The per-gate env override (`GrowthBookEnvOverride`) still works, which makes the env inventory in `settings.json` our feature delivery mechanism; that maintenance burden is the chosen price. Lever: unset `DISABLE_TELEMETRY` to restore live rollouts, at the cost of usage telemetry. Not interchangeable with `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: that bundle adds `DISABLE_AUTOUPDATER`, and auto-update stays ON here.

Gated flags forced on this way:

- `CLAUDE_CODE_NEW_INIT=1` (gate `tengu_slate_harbor_experiment`)
- `CLAUDE_CODE_FORK_SUBAGENT=1` (gate `tengu_copper_fox`)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (gate `tengu_amber_flint`)

## Value formats: the wrong format is a silent no-op

Most flags use a truthy parser (`1`/`true`/`yes`/`on`); some use a falsy parser (`0`/`false`/`no`/`off` mean disable). Grep the env name and read the call site when unsure. Traps in our inventory:

- `ENABLE_CLAUDEAI_MCP_SERVERS=0`: falsy parser; `0` is the correct disable value.
- `CLAUDE_CODE_ENABLE_CFC=0`: tri-state (`true` / `false` / unset are all distinct); `0` hits the explicit disable branch. Do not normalize.
- `DISABLE_ERROR_REPORTING=1`: bare truthy read; ANY non-empty value disables, so `=0` would also disable. Never flip to `0` expecting a re-enable.
- `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=125000`: integer via `parseInt`, must be > 0.
- `ENABLE_PROMPT_CACHING_1H=1`: plain truthy, and the flag that applies on Vertex. Do not add the `_BEDROCK` sibling (bedrock-only).

## `ENABLE_TOOL_SEARCH=1`: defer MCP tool schemas on a gateway

On a non-first-party `ANTHROPIC_BASE_URL` the CLI loads every MCP tool schema upfront unless this flag forces deferral (first-party already defers by default; the flag is a no-op there). The force only lands if the gateway forwards `tool_reference` blocks, so after a gateway change confirm MCP tools still report as deferred. Values: `1`/`true` enable, `0`/`false` disable, `auto:N` defers when schemas exceed N% of context. Needs Opus 4.5+ / Sonnet 4.5+ class models.

## `CLAUDE_CODE_EFFORT_LEVEL=max`: the env-only ceiling

Levels: `low < medium < high < xhigh < max`. `/effort` and the `effortLevel` settings key cap at `xhigh` (their schema omits `max`), so `max` is reachable only via this env var. Do NOT "fix" `max` to `xhigh`; `max` is higher.

- `max` capability is gated by a model-id allowlist in the binary (per-call env override `max_effort`); on a non-allowlisted model it silently downgrades to `high`. Re-grep the allowlist when switching main models. ultracode resolves effort to `max` on allowlisted models, `high` otherwise.
- Env instead of `effortLevel` because env outranks the settings key, the model's launch-default shadowing on first run, and `/effort` mid-session. Accepted trade-off: changing effort requires a restart.
- Only two settings/env twins exist in our inventory: `effortLevel` <-> `CLAUDE_CODE_EFFORT_LEVEL` (we set the env, per above) and `autoCompactWindow` <-> `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (we set the settings key).

## `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL`: alias pins

They pin what the `opus` / `sonnet` aliases resolve to (current values live in `settings.json`), so a CLI update cannot silently drift the main or subagent model. The sonnet pin is what CLAUDE.md's `model: "sonnet"` subagent mandate lands on. Do not remove either. On Vertex the `ANTHROPIC_DEFAULT_*_MODEL` family also supplies the regional ids the refusal-fallback reroute needs ([model config docs](https://code.claude.com/docs/en/model-config)); if a Fable model becomes the main model again, set `ANTHROPIC_DEFAULT_FABLE_MODEL` alongside.

## Auto mode: opt-in flag, permission evaluation, classifier

### `CLAUDE_CODE_ENABLE_AUTO_MODE=1`

Eligibility gate for `defaultMode: "auto"`: no-op on first-party, required opt-in on Vertex/Bedrock/Foundry, model-gated in the binary (re-check when switching main model). Once abandoned on a misdiagnosis: the classifier error `<model> is temporarily unavailable, so auto mode cannot determine the safety of <tool>` was caused by `CLAUDE_CODE_ATTRIBUTION_HEADER=0` ([#64585](https://github.com/anthropics/claude-code/issues/64585)), not Vertex capacity. If that error recurs, check the attribution section before touching this flag.

### Permission rules vs `defaultMode: "auto"`

The permission check runs in fixed order with the mode short-circuit in the middle: (1) built-in deny; (2) user `deny`; (3) `ask` rules plus the tool's own check, including the hardcoded `Dangerous rm operation` / `Dangerous rmdir operation` prompt; (4) mode short-circuit (`bypassPermissions` -> allow, `auto` -> classifier); (5) user `allow`; (6) fallback: `auto` runs the classifier, other modes ask.

- `bypassPermissions` still honors `deny` and `ask` (steps 1-3 run first); bypass only flips the unmatched fallback to allow.
- A bare tool name in `allow` matches everything for that tool and short-circuits before the classifier, making `auto` behave like yolo for that tool. Bare `Bash` is deliberately absent from `allow` so shell routes to the classifier; bare `Read`/`Write`/`Edit` stay, so ordinary file ops cost no classifier call. Exception: a tool's own `safetyCheck` (protected config/memory `.md` paths, e.g. under `.claude/`) beats broad allow rules; those route to the classifier or always-ask, and a transient classifier error fails closed. Retry the edit.
- Classifier: model resolves via gate `tengu_auto_mode_config` (bundled snapshot here); two-stage with prompt caching; token cost scales with the number of rule-unmatched calls. `autoMode.classifyAllShell: true` would suspend ALL shell allow rules including narrow `Bash(...)` ones, so keeping bare `Bash` out of `allow` is the finer lever. `autoMode.{hard_deny,soft_deny,allow}` edit the classifier's own rule sections.
- Secret protection is split by tool. The `pre-bash-guard-secrets.sh` PreToolUse hook is the real enforcement for Bash (`.env*`, `.npmrc`, ssh keys, `auth.json`, `gh auth token`, env dumps); the `Bash(*...*)` deny rules overlap it, and their leading-`*` matching is unverified (only trailing-`*` wildcards are confirmed in the binary). The hook does NOT cover Read/Edit/Write, so the `Read(...)`/`Edit(...)`/`Write(...)` deny rules are the only guard there; paths outside them (e.g. `.env.production`, `~/.config/gcloud/*`; adding those denies was proposed and declined) are readable without a prompt in `auto`.
- `skipAutoPermissionPrompt`, `skipWorkflowUsageWarning`, `skipDangerousModePermissionPrompt`: pre-accepted one-time dialogs, not cruft. The CLI manages some itself, e.g. a migration clears `skipAutoPermissionPrompt` whenever `defaultMode != "auto"`.

### `attribution`: two independent layers

- `commit: ""` / `pr: ""`: per the settings schema, empty string hides the `Generated with [Claude Code]` / `Co-Authored-By` footer in commits and PR bodies.
- `sessionUrl: false`: must be boolean `false` (the CLI checks `=== false`); `""` here is a silent no-op. Hides the claude.ai session link. Env sibling: `CLAUDE_CODE_SUPPRESS_SESSION_ATTRIBUTION`.
- `CLAUDE_CODE_ATTRIBUTION_HEADER` stays UNSET. It is falsy-parsed and `=0` empties a system-prompt attribution block, but `=0` also breaks the auto-mode classifier ([#64585](https://github.com/anthropics/claude-code/issues/64585)). The empty `attribution` templates already hide commit/PR attribution, so setting it buys nothing and re-breaks auto mode.

## Internal per-spawn env: never put in settings

The CLI sets these itself when spawning child processes (background sessions, `claude -p`, crash-respawn); putting them in `settings.json` `env` overrides that per-spawn logic. Known set: `CLAUDE_CODE_RESUME_INTERRUPTED_TURN` (globalizing it risks false auto-resume on first spawn), `CLAUDE_CODE_SESSION_NAME`, `CLAUDE_BG_BACKEND`, `CLAUDE_BG_SESSION_PERMISSION_RULES`, `CLAUDE_BG_MEMORY_TOGGLED_OFF`.

## Deliberately absent: do not (re-)add

- `CLAUDE_CODE_ATTRIBUTION_HEADER=0`: breaks auto mode; see the attribution section.
- `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES=1`: flag and gate were deleted from the binary; the agent-type list is injected unconditionally now.
- `CLAUDE_CODE_NO_FLICKER=1`: flicker-free renderer, removed deliberately while still valid in the binary. Re-add only if flicker returns.
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: kills auto-update; see the DISABLE_TELEMETRY / GrowthBook section.

## Diagnostic levers (unset, worth remembering)

- `CLAUDE_CODE_SAFE_MODE=1` / `--safe-mode`: start without CLAUDE.md/skills/hooks/MCP. First triage for "model refuses at startup" ([#66671](https://github.com/anthropics/claude-code/issues/66671)).
- `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` (ms): aborts an MCP call that stays silent that long; suspect it if a chrome-devtools / context7 call dies mid-run. `0` disables.
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` and `CLAUDE_CODE_AUTO_COMPACT_WINDOW`: auto-compact trigger overrides; the statusline script's context math reads neither.
