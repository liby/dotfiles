# Claude Code settings.json env flags

Last verified against the CLI **2.1.163** native binary (diffed 2.1.160 -> 2.1.163; the 2.1.159 binary was already pruned from disk, so that step is covered by comparing this file's documented inventory against the 2.1.163 strings; previous baselines 2.1.150, 2.1.156, 2.1.159). Every flag in `dot_claude/settings.json` is present, referenced, and actively consumed; none appear in the 2.1.160 -> 2.1.163 removal set. None have graduated to unconditional defaults or have an equivalent top-level settings key (except `effortLevel`). Do not suggest removing any of them. The 2.1.160 -> 2.1.163 diff deprecated `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON` and the memory-write-survey family (see "New env flags observed" below) and graduated nothing to a default.

**What this file is for:** a guardrail against "cleaning up" `settings.json`. When you or an agent wonders whether a non-default env flag is still needed, safe to remove, or set to the wrong value, this file holds the verified answer and the why. It is not a CLI reverse-engineering encyclopedia.

**Cite stable anchors, not minified symbols.** Anchor every claim to something that survives a CLI update: the **env var name**, the GrowthBook **gate** (`tengu_*`), a settings key, a model id, or a log/effect string. Do NOT record minified JS function names (`bH`, `Ke3`, `rH6`, and the like): they are reassigned every build, so they neither grep nor explain. Describe the behavior instead; to re-verify after an update, re-grep the env var name.

Binaries live at `~/.local/share/claude/versions/<ver>` (Mach-O; strings greppable with `rg -a -o`, or `rtk proxy rg ...` when the rtk hook rewrites `rg` into `grep` and chokes on `{n,m}`). The `~/.local/bin/claude` symlink points at the running version and may be ahead after an auto-update, which also prunes all but the most recent few versions on disk.

## GrowthBook-gated flags (env override required)

Without the env var set to `"1"`, the feature depends on remote rollout status:

- `CLAUDE_CODE_NEW_INIT` (gate `tengu_slate_harbor_experiment`): env truthy forces on, else follows the gate rollout.
- `CLAUDE_CODE_FORK_SUBAGENT` (gate `tengu_copper_fox`): resolves to "env" when the var is truthy, else falls through to the gate rollout, then "disabled". The sibling `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON` was removed in 2.1.163 (present in 2.1.160), a sign the gate may be heading to default-on; our env `=1` forces it regardless. Re-check at next verify.
- `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES` (gate `tengu_agent_list_attach`): env truthy forces on, env falsy forces off, else gate-gated. Injects the agent-type list into the system prompt.

**Why env-forcing is mandatory here, not optional.** `DISABLE_TELEMETRY=1` (our setting) disables the GrowthBook fetch outright, so the "gate rollout" branch above is dead for this install: the env override is the only path that reaches these gates. Runtime proof (`/doctor`, 2.1.163): `isGrowthBookEnabled=false`, `growthBookLastFetched=never`, `telemetryDisabledBy=DISABLE_TELEMETRY`. Gates fall back to the binary's bundled snapshot (`growthBookFeaturesLoaded=228`), frozen at build time; per-gate `GrowthBookEnvOverride` still applies with telemetry off, which is exactly how the three flags above are forced on. Consequence: any server-side gradual rollout we do not explicitly env-force never reaches us, so the env inventory in this file IS our feature-flag delivery mechanism. Lever: unset `DISABLE_TELEMETRY` to restore live gates and auto-receive rollouts, at the cost of sending usage telemetry to Anthropic.

## `DISABLE_TELEMETRY=1`: deliberate keep, not a cleanup target

Kept on purpose; do not suggest removing or toggling it. It disables Anthropic usage telemetry and, in this build, is what disables the GrowthBook fetch (mechanism in the GrowthBook-gated flags section above). Decision recorded 2026-06-05: telemetry stays off for privacy, and the cost, no automatic gradual-rollout delivery, is accepted; gated features arrive via this file's env inventory instead. The flag-maintenance burden is the chosen price, not an oversight.

Not the same as `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: that bundle adds `DISABLE_AUTOUPDATER` and would kill auto-update (kept ON), so it is not a "stronger privacy" upgrade path. See the memory on `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`.

## Value format: truthy vs falsy parser

CLI parses each env flag with one of two helpers; setting the wrong format is a silent no-op. To tell which a flag uses, grep its env var name and read the surrounding call.

- truthy: `"1"` / `"true"` / `"yes"` / `"on"` map to true. Used by most flags.
- falsy: `"0"` / `"false"` / `"no"` / `"off"` map to true. Used by `CLAUDE_CODE_ATTRIBUTION_HEADER` and `ENABLE_CLAUDEAI_MCP_SERVERS`, so disabling them via `"0"` is correct.

## `attribution` section vs `CLAUDE_CODE_ATTRIBUTION_HEADER`

Both are active at different layers. The env var (falsy parser, so `"0"` disables) controls whether the attribution header is injected into the system prompt. The `attribution` section (`commit`, `pr` keys) controls the template strings. Keeping both is correct.

## Effort levels: `max` is the env-only ceiling

Valid levels are ordered `["low","medium","high","xhigh","max"]`: `max` is the top, one notch above `xhigh` (added with Opus 4.8 in 2.1.154). Opus 4.8 defaults to `high`. Confirmed in 2.1.159 that `max` genuinely applies to Opus 4.8: the effort capability gate whitelists `claude-opus-4-8`, so the `max` -> `high` downgrade does not fire.

- We set `CLAUDE_CODE_EFFORT_LEVEL=max` via env. The env parser accepts `max` (alias-resolved, then validated); `unset` / `auto` map to null, everything else is parsed through.
- `/effort` and the settings `effortLevel` field cap at `xhigh` (their schema omits `max`). `max` is reachable **only via env**. Do NOT "fix" `max` to `xhigh` thinking xhigh is the highest: `max` is higher.
- `xhigh` effort plus standing dynamic-workflow orchestration is the new **ultracode** mode.

## `CLAUDE_CODE_EFFORT_LEVEL` set via `env` (not `effortLevel`)

Env takes precedence over `effortLevel` and over `/effort` mid-session. On the current model's first launch, `effortLevel` in settings is shadowed by the model's hardcoded launch-default (the resolver keys off specific model ids) until session state "unpins"; env sidesteps that. Accepted trade-off: `/effort` can't override live, restart to change. No other env flag has an equivalent top-level settings key.

## `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`

No-op under the current model. The flag only takes effect when the active model id contains `opus-4-6` or `sonnet-4-6`; Opus 4.8 doesn't match, so it never participates. Kept for future 4.6-series use, do not remove. (Adaptive thinking is otherwise resolved per-model.)

## Internal process-to-process env: do NOT put these in settings

These look like user flags but are set by the CLI itself when spawning child processes (background sessions, `claude -p` print mode, crash-respawn). Setting them globally in `settings.json` `env` is a misuse: the parent's per-spawn logic gets overridden.

- `CLAUDE_CODE_RESUME_INTERRUPTED_TURN`: set by the CLI only on a retry / crash-respawn (attempt > 1). Read sites are in print mode and the bg crash-respawn restore path (log `[sessionRestore] Auto-resuming interrupted turn for bg crash-respawn`), none in the interactive REPL. Removed from our settings on 2026-05-29: a no-op interactively, and it risked false auto-resume on print/bg first-spawn.
- Set alongside it in the same per-spawn cleanup: `CLAUDE_CODE_SESSION_NAME`, `CLAUDE_BG_BACKEND`, `CLAUDE_BG_SESSION_PERMISSION_RULES`, `CLAUDE_BG_MEMORY_TOGGLED_OFF`.

## New env flags observed in 2.1.152 to 2.1.163 (not in our settings)

For reference; add only if a concrete need appears:

- `CLAUDE_CODE_DISABLE_AUTO_MEMORY`: disables auto-memory (`autoMemoryEnabled`, default `true`; the memory system under `~/.claude/projects/.../memory/`).
- `CLAUDE_CODE_DISABLE_CLAUDE_CODE_SKILL` / `CLAUDE_CODE_DISABLE_CLAUDE_API_SKILL`: skip registering the built-in claude-code / claude-api skills.
- `CLAUDE_CODE_FORCE_MID_CONVERSATION_SYSTEM`: forces mid-conversation system injection (renamed from `CLAUDE_CODE_MID_CONVERSATION_SYSTEM`; disabled under hipaa). Lean system prompt is the default for Opus 4.8 as of 2.1.154.
- `CLAUDE_PTY_ORPHAN_CHECK_MS`: PTY orphan-check interval in milliseconds, default 2000, non-windows only.
- `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT`: force the effort param on models that don't support it. `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` is deprecated (removed 06/01).
- `CLAUDE_CODE_ENABLE_AUTO_MODE` (2.1.158): provider-eligibility gate for auto mode (truthy). No-op on first-party / anthropicAws (auto mode is already available there); on Vertex/Bedrock/Foundry it is the required opt-in, Opus 4.7/4.8 only. Tested and abandoned here: the safety classifier runs on the same Opus model and hangs Bash on Vertex when the model is at capacity (claude-code issues #63873, #38537, #39259). Do not enable. See memory `vertex-provider`.
- `OTEL_LOG_TOOL_DETAILS` (2.1.157): adds tool-call detail to OTEL logs. Moot here (`DISABLE_TELEMETRY=1`).
- `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`: caps parallel tool execution, default 10. Raise only if agent-teams / parallel-subagent runs feel throttled.
- `CLAUDE_CODE_ENABLE_APPEND_SUBAGENT_PROMPT` (truthy): propagates a custom `appendSubagentSystemPrompt` suffix to nested subagents. Add only with a standing subagent instruction.
- `CLAUDE_CODE_INVESTIGATE_FIRST` (`additive` / `compact` / `off`): injects a root-cause-first behavior, gate `tengu_slate_harrier` (default off), hard-forced off for opus-4-7. Experimental and model-gated.
- `CLAUDE_CODE_REMOTE_HERMETIC_MODE` (2.1.163): remote-session isolation mode, part of the native Remote Control stack (we leave Remote Control off; it also needs feature-flag eval, which `DISABLE_TELEMETRY=1` disables).
- `CLAUDE_CODE_DISABLE_REFUSAL_FALLBACK` (2.1.163, gate `tengu_refusal_fallback_entry_recorded`): disables the model-refusal fallback path.
- `CLAUDE_CODE_DISABLE_MEMORY_BULK_INFLATE` (2.1.163, gate `tengu_memory_bulk_inflate`): auto-memory bulk-load toggle.
- `CLAUDE_CODE_OWNERSHIP_FRAME` (2.1.163): replaced `CLAUDE_CODE_FRAME_MODE` (removed).
- `CLAUDE_CODE_SUPPRESS_SESSION_ATTRIBUTION` (2.1.163): attribution-layer flag, distinct from `CLAUDE_CODE_ATTRIBUTION_HEADER` (which we set to `0`).

Removed since the 2.1.159 baseline (do not re-add): `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON`, `CLAUDE_CODE_FRAME_MODE`, `CLAUDE_CODE_FORCE_MEMORY_WRITE_SURVEY`, `CLAUDE_CODE_MEMORY_WRITE_SURVEY_TIMEOUT_MS`. None were in our settings.
