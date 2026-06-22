# Claude Code settings.json env flags

Current state: CLI **2.1.185**, main model `claude-opus-4-8[1m]` (switched back from Fable 5; `settings.json` `model` and `ANTHROPIC_DEFAULT_OPUS_MODEL` both pin `claude-opus-4-8`). On 2026-06-22 the whole file was re-verified flag-by-flag against the 2.1.185 binary, cross-checked against the on-disk 2.1.181 and 2.1.183. The last FULL inventory diff was 2.1.181 -> 2.1.183 -> 2.1.185 (2.1.170 and earlier are pruned from disk, so pre-2.1.181 coverage rests on this file's existing documented inventory; prior baselines 2.1.150, 2.1.156, 2.1.159, 2.1.163). The 2.1.181 -> 2.1.183 step added `CLAUDE_CODE_CONNECT_TIMEOUT_MS`, `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`, and `CLAUDE_CODE_WEBSEARCH_USE_CCR_PROXY`, and dropped `ANTHROPIC_FOUNDRY_AUTH_TOKEN`; 2.1.183 -> 2.1.185 changed no flag-shaped strings. **One previously-set flag lost its consumer:** `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES` and its gate `tengu_agent_list_attach` are gone (the agent-type list is now injected unconditionally), so the `=1` still in `settings.json` is a dead no-op and is the single flag safe to delete. Every OTHER flag in `dot_claude/settings.json` is present, referenced, and actively consumed; none has an equivalent top-level settings key (except `effortLevel`). Do not suggest removing any of them except the dead `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES`.

**What this file is for:** a guardrail against "cleaning up" `settings.json`. When you or an agent wonders whether a non-default env flag is still needed, safe to remove, or set to the wrong value, this file holds the verified answer and the why. It is not a CLI reverse-engineering encyclopedia.

**Cite stable anchors, not minified symbols.** Anchor every claim to something that survives a CLI update: the **env var name**, the GrowthBook **gate** (`tengu_*`), a settings key, a model id, or a log/effect string. Do NOT record minified JS function names (`bH`, `Ke3`, `rH6`, and the like): they are reassigned every build, so they neither grep nor explain. Describe the behavior instead; to re-verify after an update, re-grep the env var name.

Binaries live at `~/.local/share/claude/versions/<ver>` (Mach-O; strings greppable with `rg -a -o`, or `rtk proxy rg ...` when the rtk hook rewrites `rg` into `grep` and chokes on `{n,m}`). The `~/.local/bin/claude` symlink points at the running version and may be ahead after an auto-update, which also prunes all but the most recent few versions on disk.

## GrowthBook-gated flags (env override required)

Without the env var set to `"1"`, the feature depends on remote rollout status:

- `CLAUDE_CODE_NEW_INIT` (gate `tengu_slate_harbor_experiment`): env truthy forces on, else follows the gate rollout. Gate present through 2.1.185.
- `CLAUDE_CODE_FORK_SUBAGENT` (gate `tengu_copper_fox`): resolves to "env" when the var is truthy, else falls through to the gate rollout, then "disabled". Through 2.1.185 the gate default is still false, so env `=1` remains required; it has NOT graduated to default-on. The sibling `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON` was removed in 2.1.163 and stays absent.
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (gate `tengu_amber_flint`): env truthy forces on, else gate-gated. Subject to the same `DISABLE_TELEMETRY` consequence as the others (gate fetch dead), so our env `=1` is what enables agent teams. Set in `settings.json`.
- `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES` (gate `tengu_agent_list_attach`): **removed in 2.1.185** (already absent in 2.1.181/2.1.183). The agent-type list is now injected unconditionally with no env or gate guard (event `agent_listing_delta`; the running session's system prompt shows it on). The `=1` still in `settings.json` is a dead no-op, safe to delete.

**Why env-forcing is mandatory here, not optional.** `DISABLE_TELEMETRY=1` (our setting) disables the GrowthBook fetch outright, so the "gate rollout" branch above is dead for this install: the env override is the only path that reaches these gates. Runtime proof (`/doctor`, captured on 2.1.163): `isGrowthBookEnabled=false`, `growthBookLastFetched=never`, `telemetryDisabledBy=DISABLE_TELEMETRY`. The disable-fetch wiring and the `GrowthBookEnvOverride` path were re-confirmed in the 2.1.185 binary. Gates fall back to the binary's bundled snapshot (`growthBookFeaturesLoaded=228` was the 2.1.163 count; it is build-specific and has changed across releases), frozen at build time; per-gate `GrowthBookEnvOverride` still applies with telemetry off, which is exactly how the env-forced flags above are forced on. Consequence: any server-side gradual rollout we do not explicitly env-force never reaches us, so the env inventory in this file IS our feature-flag delivery mechanism. Lever: unset `DISABLE_TELEMETRY` to restore live gates and auto-receive rollouts, at the cost of sending usage telemetry to Anthropic.

## `DISABLE_TELEMETRY=1`: deliberate keep, not a cleanup target

Kept on purpose; do not suggest removing or toggling it. It disables Anthropic usage telemetry and, in this build, is what disables the GrowthBook fetch (mechanism in the GrowthBook-gated flags section above). Decision recorded 2026-06-05: telemetry stays off for privacy, and the cost, no automatic gradual-rollout delivery, is accepted; gated features arrive via this file's env inventory instead. The flag-maintenance burden is the chosen price, not an oversight.

Not the same as `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: that bundle adds `DISABLE_AUTOUPDATER` and would kill auto-update (kept ON), so it is not a "stronger privacy" upgrade path. See the memory on `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`.

## Value format: truthy vs falsy parser

CLI parses each env flag with one of two helpers; setting the wrong format is a silent no-op. To tell which a flag uses, grep its env var name and read the surrounding call.

- truthy: `"1"` / `"true"` / `"yes"` / `"on"` map to true. Used by most flags.
- falsy: `"0"` / `"false"` / `"no"` / `"off"` map to true. Used by `CLAUDE_CODE_ATTRIBUTION_HEADER` and `ENABLE_CLAUDEAI_MCP_SERVERS`, so disabling them via `"0"` is correct.

Three of our set flags do NOT use this clean two-parser model, so don't assume "not truthy means falsy":

- `CLAUDE_CODE_ENABLE_CFC` is tri-state (true / false / unset are all distinct; schema `triBool`, read via `=== true` and `=== false` branches). Our `=0` parses to false and hits the disable branch, so `0` is correct; a cold reader could wrongly "normalize" it to a truthy/falsy form.
- `DISABLE_ERROR_REPORTING` is a bare truthy read (`process.env.DISABLE_ERROR_REPORTING || ...`), not the `"0"`-aware falsy parser the other `DISABLE_*` flags use. Any non-empty value disables it, so `=0` would ALSO disable. Our `=1` is correct; never set it to `0` expecting it to re-enable.
- `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` is an integer (`parseInt`, must be > 0), not a boolean.

`ENABLE_PROMPT_CACHING_1H` is plain truthy and our `=1` is correct, but on Vertex only this plain flag applies; the `ENABLE_PROMPT_CACHING_1H_BEDROCK` sibling is bedrock-only, so do not add `_BEDROCK` here (see memory `vertex-provider`).

## `attribution` section vs `CLAUDE_CODE_ATTRIBUTION_HEADER`

Both are active at different layers. The env var (falsy parser, so `"0"` disables) controls whether the attribution header is injected into the system prompt. The `attribution` section (`commit`, `pr` keys) controls the template strings. Keeping both is correct.

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

## New env flags observed in 2.1.152 to 2.1.185 (not in our settings)

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
- `ANTHROPIC_DEFAULT_FABLE_MODEL` (2.1.170, binary-verified; siblings `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` ARE set, see their own section above): controls what the `fable` alias resolves to. Left unset because Fable is not the current main model. Per the model-config docs the `ANTHROPIC_DEFAULT_*_MODEL` family is also required on Vertex/Bedrock for the Fable 5 refusal-fallback (classifier-triggered `stop_reason: "refusal"` reroutes the session to Opus 4.8) to find the right regional model ids; relevant here because we run on Vertex (see memory `vertex-provider`). If Fable refusal-fallback misbehaves, set this before debugging deeper.
- `VERTEX_REGION_CLAUDE_FABLE_5` (2.1.170, binary-verified): per-model Vertex region override, same family as the existing `VERTEX_REGION_*` flags.
- `DISABLE_PROMPT_CACHING_FABLE` (2.1.170, binary-verified): disables prompt caching for Fable models only.
- `CLAUDE_CODE_SAFE_MODE` (2.1.170, binary-verified; also `--safe-mode`): starts without CLAUDE.md/skills/hooks/MCP. Diagnostic for "Fable refuses before I even typed anything" cases where loaded context trips a safety classifier (claude-code issue #66671).
- `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (2.1.170, binary-verified during the 2026-06-10 audit): env overrides for the auto-compact window and trigger percent; they interact with our `autoCompactWindow: 400000` setting and the statusline `COMPACT_RESERVE` math, and the statusline script reads neither.
- `CLAUDE_CODE_CONNECT_TIMEOUT_MS` (2.1.183, binary-verified; numeric ms, default 60000): overrides the request connect timeout (the "no response headers after Nms" abort). Raise only on a slow or proxied link.
- `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` (2.1.183, binary-verified; numeric ms, default 600000): ceiling on how long print / `claude -p` / background sessions wait for running background tasks. No effect in the interactive REPL.
- `CLAUDE_CODE_WEBSEARCH_USE_CCR_PROXY` / `CLAUDE_CODE_WEBFETCH_USE_CCR_PROXY` (truthy; WEBSEARCH new in 2.1.183, WEBFETCH present since at least 2.1.181): route WebSearch / WebFetch through the CCR proxy instead of hitting `ANTHROPIC_BASE_URL` directly.

Removed since the 2.1.159 baseline (do not re-add): `CLAUDE_CODE_FORK_SUBAGENT_DEFAULT_ON`, `CLAUDE_CODE_FRAME_MODE`, `CLAUDE_CODE_FORCE_MEMORY_WRITE_SURVEY`, `CLAUDE_CODE_MEMORY_WRITE_SURVEY_TIMEOUT_MS`. None were in our settings.
