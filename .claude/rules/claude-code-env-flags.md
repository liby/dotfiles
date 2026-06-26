# Claude Code settings.json env flags

Current state: CLI **2.1.191** (running; last full flag-by-flag audit against **2.1.187**), main model `claude-opus-4-8[1m]` (switched back from Fable 5; `settings.json` `model` and `ANTHROPIC_DEFAULT_OPUS_MODEL` both pin `claude-opus-4-8`). On 2026-06-22 the whole file was re-verified flag-by-flag against the 2.1.185 binary; on 2026-06-24 the inventory was diffed 2.1.185 -> 2.1.187 (both on disk, with 2.1.186), and all set flags confirmed present. The last FULL inventory diff chain is 2.1.181 -> 2.1.183 -> 2.1.185 -> 2.1.187 (only 2.1.185 to 2.1.187 remain on disk; older coverage rests on this file's existing documented inventory; prior baselines 2.1.150, 2.1.156, 2.1.159, 2.1.163). The 2.1.181 -> 2.1.183 step added `CLAUDE_CODE_CONNECT_TIMEOUT_MS`, `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`, and `CLAUDE_CODE_WEBSEARCH_USE_CCR_PROXY`, and dropped `ANTHROPIC_FOUNDRY_AUTH_TOKEN`; 2.1.183 -> 2.1.185 changed no flag-shaped strings; 2.1.185 -> 2.1.187 added `CLAUDE_CHROME_CLASSIFIER_FLOOR`, `CLAUDE_CODE_DISABLE_LAUNCH_COMPOSER`, `CLAUDE_CODE_FORCE_STRIKETHROUGH`, and `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT`, and dropped `CLAUDE_CODE_CONNECT_TIMEOUT_MS` (added 2.1.183, gone by 2.1.187) plus the internal `CLAUDE_PROJECT_TOOL` — none of these in our settings. `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES` and its gate `tengu_agent_list_attach` are gone (the agent-type list is now injected unconditionally); its dead `=1` has since been deleted from `settings.json`. `ENABLE_TOOL_SEARCH` joined `settings.json` since the last audit (own section below). On 2026-06-26 (running CLI 2.1.191) `CLAUDE_CODE_ENABLE_AUTO_MODE=1` was added and `CLAUDE_CODE_ATTRIBUTION_HEADER=0` was removed (both verified against the 2.1.191 binary; see their sections); no full inventory re-diff was run for 2.1.187 -> 2.1.191. Later on 2026-06-26 (symlink now CLI 2.1.193): `CLAUDE_CODE_NO_FLICKER` was removed from `settings.json` (deliberate; the flag stays valid in-binary, we just no longer set it, so it moved to the "not in our settings" list below), and `attribution.sessionUrl: false` was added (see the attribution section). A 2.1.191 -> 2.1.193 binary flag-string diff (not a full flag-by-flag audit) found 7 added / 0 removed: `CLAUDE_CODE_SHOJI_ENGINE`, `CLAUDE_CODE_ENABLE_LAUNCH_COMPOSER`, `CLAUDE_CODE_COORDINATOR_PROPAGATE_NESTED_MEMORY`, `CLAUDE_CODE_DISABLE_NOTIFICATION_PRESENCE_CHECK`, `CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP`, `CLAUDE_BG_POST_CLEAR_RESPAWN`, `OTEL_LOG_ASSISTANT_RESPONSES`; none merged into settings. Every flag now in `dot_claude/settings.json` is present, referenced, and actively consumed; none has an equivalent top-level settings key (except `effortLevel`). Do not suggest removing any of them. On 2026-06-27 `permissions.defaultMode` switched `bypassPermissions` -> `auto`, bare `Bash` was removed from `permissions.allow` so shell routes to the auto-mode classifier, and the accepted-dialog flags `skipWorkflowUsageWarning: true` (pulled from destination drift; CLI auto-writes it on accepting the workflow-usage warning) and `skipAutoPermissionPrompt: true` (pre-accepts the auto-mode entry dialog, which otherwise fires once on the first `auto` session; a migration clears it whenever `defaultMode != "auto"`) were added alongside `skipDangerousModePermissionPrompt`; see the "Permission rules vs `defaultMode`" section below.

**What this file is for:** a guardrail against "cleaning up" `settings.json`. When you or an agent wonders whether a non-default env flag is still needed, safe to remove, or set to the wrong value, this file holds the verified answer and the why. It is not a CLI reverse-engineering encyclopedia.

**Cite stable anchors, not minified symbols.** Anchor every claim to something that survives a CLI update: the **env var name**, the GrowthBook **gate** (`tengu_*`), a settings key, a model id, or a log/effect string. Do NOT record minified JS function names (`bH`, `Ke3`, `rH6`, and the like): they are reassigned every build, so they neither grep nor explain. Describe the behavior instead; to re-verify after an update, re-grep the env var name.

Binaries live at `~/.local/share/claude/versions/<ver>` (Mach-O; strings greppable with `rg -a -o`). The `~/.local/bin/claude` symlink points at the running version and may be ahead after an auto-update, which also prunes all but the most recent few versions on disk.

## GrowthBook-gated flags (env override required)

Without the env var set to `"1"`, the feature depends on remote rollout status:

- `CLAUDE_CODE_NEW_INIT` (gate `tengu_slate_harbor_experiment`): env truthy forces on, else follows the gate rollout. Gate present through 2.1.185.
- `CLAUDE_CODE_FORK_SUBAGENT` (gate `tengu_copper_fox`): resolves to "env" when the var is truthy, else falls through to the gate rollout, then "disabled". Through 2.1.185 the gate default is still false, so env `=1` remains required; it has NOT graduated to default-on. The sibling `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON` was removed in 2.1.163 and stays absent.
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (gate `tengu_amber_flint`): env truthy forces on, else gate-gated. Subject to the same `DISABLE_TELEMETRY` consequence as the others (gate fetch dead), so our env `=1` is what enables agent teams. Set in `settings.json`.
- `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES` (gate `tengu_agent_list_attach`): **removed in 2.1.185** (already absent in 2.1.181/2.1.183). The agent-type list is now injected unconditionally with no env or gate guard (event `agent_listing_delta`; the running session's system prompt shows it on). Its dead `=1` has since been deleted from `settings.json`.

**Why env-forcing is mandatory here, not optional.** `DISABLE_TELEMETRY=1` (our setting) disables the GrowthBook fetch outright, so the "gate rollout" branch above is dead for this install: the env override is the only path that reaches these gates. Runtime proof (`/doctor`, captured on 2.1.163): `isGrowthBookEnabled=false`, `growthBookLastFetched=never`, `telemetryDisabledBy=DISABLE_TELEMETRY`. The disable-fetch wiring and the `GrowthBookEnvOverride` path were re-confirmed in the 2.1.185 binary. Gates fall back to the binary's bundled snapshot (`growthBookFeaturesLoaded=228` was the 2.1.163 count; it is build-specific and has changed across releases), frozen at build time; per-gate `GrowthBookEnvOverride` still applies with telemetry off, which is exactly how the env-forced flags above are forced on. Consequence: any server-side gradual rollout we do not explicitly env-force never reaches us, so the env inventory in this file IS our feature-flag delivery mechanism. Lever: unset `DISABLE_TELEMETRY` to restore live gates and auto-receive rollouts, at the cost of sending usage telemetry to Anthropic.

## `DISABLE_TELEMETRY=1`: deliberate keep, not a cleanup target

Kept on purpose; do not suggest removing or toggling it. It disables Anthropic usage telemetry and, in this build, is what disables the GrowthBook fetch (mechanism in the GrowthBook-gated flags section above). Decision recorded 2026-06-05: telemetry stays off for privacy, and the cost, no automatic gradual-rollout delivery, is accepted; gated features arrive via this file's env inventory instead. The flag-maintenance burden is the chosen price, not an oversight.

Not the same as `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: that bundle adds `DISABLE_AUTOUPDATER` and would kill auto-update (kept ON), so it is not a "stronger privacy" upgrade path.

## Value format: truthy vs falsy parser

CLI parses each env flag with one of two helpers; setting the wrong format is a silent no-op. To tell which a flag uses, grep its env var name and read the surrounding call.

- truthy: `"1"` / `"true"` / `"yes"` / `"on"` map to true. Used by most flags.
- falsy: `"0"` / `"false"` / `"no"` / `"off"` map to true. Used by `CLAUDE_CODE_ATTRIBUTION_HEADER` and `ENABLE_CLAUDEAI_MCP_SERVERS`, so `"0"` disables. We keep `ENABLE_CLAUDEAI_MCP_SERVERS=0`; `CLAUDE_CODE_ATTRIBUTION_HEADER=0` is parser-valid but deliberately NOT set, because `=0` breaks auto mode (see its section).

Several of our set flags do NOT use this clean two-parser model, so don't assume "not truthy means falsy":

- `CLAUDE_CODE_ENABLE_CFC` is tri-state (true / false / unset are all distinct; schema `triBool`, read via `=== true` and `=== false` branches). Our `=0` parses to false and hits the disable branch, so `0` is correct; a cold reader could wrongly "normalize" it to a truthy/falsy form.
- `DISABLE_ERROR_REPORTING` is a bare truthy read (`process.env.DISABLE_ERROR_REPORTING || ...`), not the `"0"`-aware falsy parser the other `DISABLE_*` flags use. Any non-empty value disables it, so `=0` would ALSO disable. Our `=1` is correct; never set it to `0` expecting it to re-enable.
- `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` is an integer (`parseInt`, must be > 0), not a boolean.

`ENABLE_PROMPT_CACHING_1H` is plain truthy and our `=1` is correct, but on Vertex only this plain flag applies; the `ENABLE_PROMPT_CACHING_1H_BEDROCK` sibling is bedrock-only, so do not add `_BEDROCK` here.

## `ENABLE_TOOL_SEARCH`: defer MCP tool schemas on the gateway

Verified against the 2.1.187 binary (2026-06-24). Claude Code defers MCP tool definitions by default (a schema loads only when its tool is used), but only on a first-party host. On a non-first-party `ANTHROPIC_BASE_URL` it loads every MCP tool schema upfront unless this flag forces deferral, and the force only lands if the gateway forwards `tool_reference` blocks.

- `sub` (first-party): deferral is already the default, so the flag is a no-op.
- `api` (Vertex gateway): set it so deferral still happens. Confirm in an api session that MCP tools report as deferred; a proxy that strips `tool_reference` leaves it inert.

Value: `1`/`true` both enable deferral (resolved identically, so `1` is fine and consistent with the other flags), `0`/`false` disable, `auto`/`auto:N` defer only when tool schemas exceed N% of context. Needs Opus 4.5+ / Sonnet 4.5+; the gateway serves Opus 4.8 / Sonnet 4.5.

## `CLAUDE_CODE_ENABLE_AUTO_MODE=1`: enabled (was abandoned)

Set in `settings.json` on 2026-06-26. Provider-eligibility gate for auto mode (truthy, added 2.1.158): no-op on first-party / anthropicAws (auto mode is available there by default), the required opt-in on Vertex/Bedrock/Foundry, Opus 4.7/4.8 only.

Previously abandoned, on a wrong diagnosis. The old note blamed the auto-mode safety classifier failing with `<model> is temporarily unavailable, so auto mode cannot determine the safety of <tool>` on a Vertex model-at-capacity hang. Per [issue #64585](https://github.com/anthropics/claude-code/issues/64585), that exact error is caused by `CLAUDE_CODE_ATTRIBUTION_HEADER=0` (which we used to set), not capacity; with the header env removed, the classifier works. Confirmed here on both subscription (first-party, where the flag is a no-op anyway) and API (Vertex, where this `=1` is the opt-in). A genuine model-at-capacity hang on Vertex, if it recurs, is a separate concern, not a reason to drop this flag.

## Permission rules vs `defaultMode`: evaluation order and the auto-mode classifier

Verified against 2.1.193. The runtime permission check runs rules in a fixed order and the mode short-circuit sits in the MIDDLE, not first. Stable anchors: the `behavior:"deny"|"ask"|"allow"` decision enum; the bypass branch returns `decisionReason:{type:"mode"}`; the classifier surfaces the strings `Allowed by auto mode classifier` / `denied by the Claude Code auto mode classifier`.

Order: (1) built-in deny; (2) user `deny` rules; (3) `ask` rules + the tool's own check, including the hardcoded `Dangerous rm operation` / `Dangerous rmdir operation` prompt; (4) mode short-circuit (`bypassPermissions` -> allow, `auto` -> classifier); (5) user `allow` rules; (6) otherwise auto runs the classifier, every other mode asks.

- **bypassPermissions still honors `deny` and `ask`** (checked at steps 1-3, before the bypass branch at 4). Bypass only flips the unmatched fallback from ask to allow. The `ask: Bash(*git push*)` rule prompting under the old `bypassPermissions` default was the live proof.
- **A broad `allow` list disables the auto-mode classifier.** The classifier runs only on calls matching NO allow/deny/ask rule (step 6). A bare tool name (`Bash`, `Read`, `Write`, `Edit`, `Agent`) matches everything for that tool and short-circuits at step 5, so in `auto` the tool behaves as in yolo. We removed bare `Bash` from `allow` on 2026-06-27 so shell routes to the classifier; bare `Read`/`Write`/`Edit` stay, so ordinary reads/edits auto-accept with no classifier call. EXCEPTION (confirmed live 2026-06-27): the tool's own check returns a `safetyCheck` decision that a broad allow rule cannot override, so edits to protected config/memory paths (automemory; `.claude/` per the live block; the binary gates on `r.endsWith(".md") && <protected-path>`) route to the classifier in `auto`, or always-ask when `classifierApprovable: false` (automemory writes, the `Dangerous rm operation` / `Dangerous rmdir operation` case). A `.claude/rules/*.md` edit this session hit this path and a transient `Stage 2 classifier error` fail-closed-blocked it; retry succeeded. The lever `autoMode.classifyAllShell: true` suspends ALL shell allow rules in auto but also overrides narrow `Bash(...)` allows, so removing the bare entry is preferred when you still want to fast-path specific commands later. `autoMode.{hard_deny,soft_deny,allow}` edit the classifier's own rule sections.
- **Classifier model + cost.** Model resolves via GrowthBook `tengu_auto_mode_config.modelByMainModel`; with `DISABLE_TELEMETRY=1` the live fetch is dead so it uses the bundled snapshot or the fallback chain. The cheaper-model downgrade fires only for fable-5/mythos-5 main models (gated on the unset `ANTHROPIC_DEFAULT_FABLE_MODEL`), so for Opus 4.8 the classifier resolves to the main model itself unless the bundled snapshot overrides it (not decodable from strings). Two-stage (fast stage 1, escalate to stage 2), prompt-cached (`classifierStage1CacheReadInputTokens`). Auto-mode token cost is proportional to the count of unmatched calls, which after removing bare `Bash` includes every non-deny/ask shell command.
- **Secret protection is split by tool.** `pre-bash-guard-secrets.sh` (Bash PreToolUse hook) is the reliable block for bash secret reads (`.env*`, `.npmrc`, ssh keys, `auth.json`, `gh auth token`, env dumps) and is the real enforcement; the `Bash(*secret*)` deny rules overlap it and their leading-`*` matching is unverified (binary confirms only trailing-`*` `Bash(npm run *)` wildcard matching). The hook does NOT cover the Read/Edit/Write tools, so for those the `Read(...)`/`Edit(...)`/`Write(...)` deny rules are the only guard. With bare `Read` allowed and `.env.production` / `~/.config/gcloud/*` denies declined (2026-06-27), the Read tool can read those unguarded in `auto`.

## `attribution` section vs `CLAUDE_CODE_ATTRIBUTION_HEADER`

Two independent layers. Only the `attribution` section is now active.

- `attribution` section (`commit: ""`, `pr: ""`): the layer that actually suppresses attribution. The settings schema reads *"Empty string hides attribution"*, so the empty strings blank the `Generated with [Claude Code]` / `Co-Authored-By` footer in commits and PR bodies. Kept.
- `attribution.sessionUrl: false` (added 2026-06-26): a separate boolean, NOT an empty-string template. The CLI checks `attribution?.sessionUrl === false` and omits the claude.ai session link from commits and PRs; `""` is a silent no-op here (the `=== false` check fails), so it must be boolean `false`. Sibling lever: the env `CLAUDE_CODE_SUPPRESS_SESSION_ATTRIBUTION` nulls the same link.
- `CLAUDE_CODE_ATTRIBUTION_HEADER` env (falsy parser): controls a separate system-prompt attribution-header block (its builder returns `""` when the flag is falsy-set). We used to set `=0` to empty that block, but `=0` breaks the auto-mode safety classifier ([issue #64585](https://github.com/anthropics/claude-code/issues/64585): `<model> is temporarily unavailable, so auto mode cannot determine the safety of <tool>`). Removed 2026-06-26; now unset.

Removing the env var does NOT reintroduce attribution in commits/PRs: the empty `attribution` templates still hide the footer. Do not re-add `CLAUDE_CODE_ATTRIBUTION_HEADER=0`: it re-breaks auto mode for zero attribution-suppression benefit.

## Effort levels: `max` is the env-only ceiling

Valid levels are ordered `["low","medium","high","xhigh","max"]`: `max` is the top, one notch above `xhigh` (added with Opus 4.8 in 2.1.154). Re-confirmed in 2.1.185 that `max` applies to the current main model **Opus 4.8**: the `max` capability gate (per-call env override `max_effort`, else a model-id list) whitelists `claude-opus-4-8`, so the `max` -> `high` downgrade does not fire. The same allow branch also names `claude-opus-4-7`, `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-fable-5`, and `claude-mythos-5`; the deny list covers claude-3-x, opus-4-0/4-1/4-5, sonnet-4-0/4-5, haiku-4-5. Opus 4.8's launch default is `high`; switching models resets session effort to that model's default (Fable 5 also `high`, Opus 4.7 `xhigh`), which the env var then overrides.

- We set `CLAUDE_CODE_EFFORT_LEVEL=max` via env. The env parser accepts `max` (alias-resolved, then validated); `unset` / `auto` map to null, everything else is parsed through.
- `/effort` and the settings `effortLevel` field cap at `xhigh` (their schema omits `max`, re-checked in 2.1.185). `max` is reachable **only via env**. Do NOT "fix" `max` to `xhigh` thinking xhigh is the highest: `max` is higher.
- **ultracode** mode resolves effort to `max` on models that pass the max gate (else `high`) plus standing dynamic-workflow orchestration (corrected 2026-06-10 from the 2.1.170 effort resolver; previously recorded as `xhigh`).

## `CLAUDE_CODE_EFFORT_LEVEL` set via `env` (not `effortLevel`)

Env takes precedence over `effortLevel` and over `/effort` mid-session. On the current model's first launch, `effortLevel` in settings is shadowed by the model's hardcoded launch-default (the resolver keys off specific model ids) until session state "unpins"; env sidesteps that. Accepted trade-off: `/effort` can't override live, restart to change. One more env/settings twin exists as of 2.1.170: `CLAUDE_CODE_AUTO_COMPACT_WINDOW` mirrors the `autoCompactWindow` settings key (we set the settings key only); no other flag in our inventory has one.

## `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`

No-op for the current MAIN model **Opus 4.8**: the flag's effect is `&&`-gated on the model id containing `opus-4-6` or `sonnet-4-6`, and `claude-opus-4-8` matches neither (Fable 5 also matches neither). But NOT dormant: `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6` plus the CLAUDE.md policy of `model: "sonnet"` subagents means sonnet-4-6 subagent calls run with this flag live — adaptive thinking off, and with `alwaysThinkingEnabled: true` they get forced manual thinking. Whether that combination is intentional for cheap subagents was never recorded (noted 2026-06-10); confirm intent before changing either side. (Adaptive thinking is otherwise resolved per-model. Fable 5 carries a server-side constraint, not a CLI one: an explicit `thinking: {type: "disabled"}` returns HTTP 400 on Fable 5 although Opus 4.x accepts it; per the 2.1.185 model-config docs the workaround is to omit the `thinking` param or send `{type: "adaptive"}`. The CLI knobs `MAX_THINKING_TOKENS=0` / `alwaysThinkingEnabled: false` DO take effect on any model — the earlier note that they "have no effect on Fable 5" was wrong.)

## `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL`: pinned alias targets

Both are SET and active. (An earlier revision listed `ANTHROPIC_DEFAULT_OPUS_MODEL` under "New env flags observed (not in our settings)" — that was stale once Opus became the main model again.) They pin what the `opus` / `sonnet` aliases resolve to, so a CLI update can't silently drift them:

- `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-8` pins the `opus` alias to an exact id. Opus 4.8 is the current main model, and on Vertex this is also the regional target the Fable 5 refusal-fallback reroutes to.
- `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6` pins the subagent default (CLAUDE.md mandates `model: "sonnet"` for cheap subagents); this is the id the `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` note above keys off.

Do not remove either: dropping one un-pins the alias and lets a CLI update change the main / subagent model under us. The sibling `ANTHROPIC_DEFAULT_FABLE_MODEL` stays unset (Fable is not the current main model).

## Internal process-to-process env: do NOT put these in settings

These look like user flags but are set by the CLI itself when spawning child processes (background sessions, `claude -p` print mode, crash-respawn). Setting them globally in `settings.json` `env` is a misuse: the parent's per-spawn logic gets overridden.

- `CLAUDE_CODE_RESUME_INTERRUPTED_TURN`: set by the CLI only on a retry / crash-respawn (attempt > 1). Read sites are in print mode and the bg crash-respawn restore path (log `[sessionRestore] Auto-resuming interrupted turn for bg crash-respawn`), none in the interactive REPL. Removed from our settings on 2026-05-29: a no-op interactively, and it risked false auto-resume on print/bg first-spawn.
- Set alongside it in the same per-spawn cleanup: `CLAUDE_CODE_SESSION_NAME`, `CLAUDE_BG_BACKEND`, `CLAUDE_BG_SESSION_PERMISSION_RULES`, `CLAUDE_BG_MEMORY_TOGGLED_OFF`.

## New env flags observed in 2.1.152 to 2.1.187 (not in our settings)

For reference; add only if a concrete need appears:

- `CLAUDE_CODE_DISABLE_AUTO_MEMORY`: disables auto-memory (`autoMemoryEnabled`, default `true`; the memory system under `~/.claude/projects/.../memory/`).
- `CLAUDE_CODE_DISABLE_CLAUDE_CODE_SKILL` / `CLAUDE_CODE_DISABLE_CLAUDE_API_SKILL`: skip registering the built-in claude-code / claude-api skills.
- `CLAUDE_CODE_FORCE_MID_CONVERSATION_SYSTEM`: forces mid-conversation system injection (renamed from `CLAUDE_CODE_MID_CONVERSATION_SYSTEM`; disabled under hipaa). Lean system prompt is the default for Opus 4.8 as of 2.1.154.
- `CLAUDE_PTY_ORPHAN_CHECK_MS`: PTY orphan-check interval in milliseconds, default 2000, non-windows only.
- `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT`: force the effort param on models that don't support it. `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` is deprecated (removed 06/01).- `OTEL_LOG_TOOL_DETAILS` (2.1.157): adds tool-call detail to OTEL logs. Moot here (`DISABLE_TELEMETRY=1`).
- `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`: caps parallel tool execution, default 10. Raise only if agent-teams / parallel-subagent runs feel throttled.
- `CLAUDE_CODE_ENABLE_APPEND_SUBAGENT_PROMPT` (truthy): propagates a custom `appendSubagentSystemPrompt` suffix to nested subagents. Add only with a standing subagent instruction.
- `CLAUDE_CODE_INVESTIGATE_FIRST` (`additive` / `compact` / `off`): injects a root-cause-first behavior, gate `tengu_slate_harrier` (default off), hard-forced off for opus-4-7. Experimental and model-gated.
- `CLAUDE_CODE_REMOTE_HERMETIC_MODE` (2.1.163): remote-session isolation mode, part of the native Remote Control stack (we leave Remote Control off; it also needs feature-flag eval, which `DISABLE_TELEMETRY=1` disables).
- `CLAUDE_CODE_DISABLE_REFUSAL_FALLBACK` (2.1.163, gate `tengu_refusal_fallback_entry_recorded`): disables the model-refusal fallback path.
- `CLAUDE_CODE_DISABLE_MEMORY_BULK_INFLATE` (2.1.163, gate `tengu_memory_bulk_inflate`): auto-memory bulk-load toggle.
- `CLAUDE_CODE_OWNERSHIP_FRAME` (2.1.163): replaced `CLAUDE_CODE_FRAME_MODE` (removed).
- `CLAUDE_CODE_SUPPRESS_SESSION_ATTRIBUTION` (2.1.163): attribution-layer flag, distinct from `CLAUDE_CODE_ATTRIBUTION_HEADER` (which we now leave unset, see its section).
- `ANTHROPIC_DEFAULT_FABLE_MODEL` (2.1.170, binary-verified; siblings `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` ARE set, see their own section above): controls what the `fable` alias resolves to. Left unset because Fable is not the current main model. Per the model-config docs the `ANTHROPIC_DEFAULT_*_MODEL` family is also required on Vertex/Bedrock for the Fable 5 refusal-fallback (classifier-triggered `stop_reason: "refusal"` reroutes the session to Opus 4.8) to find the right regional model ids; relevant here because we run on Vertex. If Fable refusal-fallback misbehaves, set this before debugging deeper.
- `VERTEX_REGION_CLAUDE_FABLE_5` (2.1.170, binary-verified): per-model Vertex region override, same family as the existing `VERTEX_REGION_*` flags.
- `DISABLE_PROMPT_CACHING_FABLE` (2.1.170, binary-verified): disables prompt caching for Fable models only.
- `CLAUDE_CODE_SAFE_MODE` (2.1.170, binary-verified; also `--safe-mode`): starts without CLAUDE.md/skills/hooks/MCP. Diagnostic for "Fable refuses before I even typed anything" cases where loaded context trips a safety classifier (claude-code issue #66671).
- `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (2.1.170, binary-verified during the 2026-06-10 audit): env overrides for the auto-compact window and trigger percent; they interact with our `autoCompactWindow: 400000` setting and the statusline `COMPACT_RESERVE` math, and the statusline script reads neither.
- `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` (2.1.183, binary-verified; numeric ms, default 600000): ceiling on how long print / `claude -p` / background sessions wait for running background tasks. No effect in the interactive REPL.
- `CLAUDE_CODE_WEBSEARCH_USE_CCR_PROXY` / `CLAUDE_CODE_WEBFETCH_USE_CCR_PROXY` (truthy; WEBSEARCH new in 2.1.183, WEBFETCH present since at least 2.1.181): route WebSearch / WebFetch through the CCR proxy instead of hitting `ANTHROPIC_BASE_URL` directly.
- `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` (2.1.187, binary-verified; numeric ms): aborts an MCP tool call that produces no output for that long. Raise it or set `0` for a tool expected to run silent for a while; relevant to our chrome-devtools / context7 MCPs if a call ever aborts mid-run.
- `CLAUDE_CODE_DISABLE_LAUNCH_COMPOSER` (2.1.187, truthy): disables the launch composer (the prompt-composer UI shown at startup).
- `CLAUDE_CODE_FORCE_STRIKETHROUGH` (2.1.187, truthy): forces strikethrough text rendering on terminals that do not advertise the capability.
- `CLAUDE_CHROME_CLASSIFIER_FLOOR` (2.1.187): numeric floor for a Chrome-integration safety classifier; exact effect not pinned, and no effect here since we do not use the Chrome integration.
- `CLAUDE_CODE_NO_FLICKER` (truthy): forces the virtualized-scrollback flicker-free renderer over the classic main-screen one (CLI auto-disables it where it misbehaves, e.g. Windows over SSH/ConPTY). Was SET in `settings.json`; removed 2026-06-26 (deliberate). Flag remains valid in-binary; re-add `=1` if flicker returns.

Removed since the 2.1.159 baseline (do not re-add): `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON`, `CLAUDE_CODE_FRAME_MODE`, `CLAUDE_CODE_FORCE_MEMORY_WRITE_SURVEY`, `CLAUDE_CODE_MEMORY_WRITE_SURVEY_TIMEOUT_MS`, and `CLAUDE_CODE_CONNECT_TIMEOUT_MS` (added 2.1.183, gone by 2.1.187). None were in our settings.
