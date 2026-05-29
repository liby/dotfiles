# Claude Code settings.json env flags

Env flags in `dot_claude/settings.json` were last verified against the CLI **2.1.156** native binary (diffed across 2.1.152 to 2.1.156; previous baseline 2.1.150). Every flag in `settings.json` is present, referenced, and actively consumed. None have graduated to unconditional defaults or have an equivalent top-level settings key (except `effortLevel`). Do not suggest removing any of them.

Binaries live at `~/.local/share/claude/versions/<ver>` (Mach-O, JS strings greppable with `rg -a -o`). The `~/.local/bin/claude` symlink may point ahead of the running session's version after an auto-update, which also prunes all but the most recent few versions on disk.

## GrowthBook-gated flags (env override required)

Without the env var set to `"1"`, the feature depends on remote rollout status:

- `CLAUDE_CODE_NEW_INIT` (gate: `tengu_slate_harbor_experiment`) — `Ke3(){return xH(process.env.CLAUDE_CODE_NEW_INIT)||L_("tengu_slate_harbor_experiment",!1)}`
- `CLAUDE_CODE_FORK_SUBAGENT` (gate: `tengu_copper_fox`) — resolver returns `"env"` when the var is truthy, else falls through to gate rollout then `"disabled"`
- `CLAUDE_CODE_AGENT_LIST_IN_MESSAGES` (gate: `tengu_agent_list_attach`) — env truthy forces on, env falsy forces off, else gate-gated. This is what injects the agent-type list into the system prompt.

## Value format: `mH()`/`xH()` (truthy) vs `tK()`/`VK()` (falsy)

CLI uses two parsers. Setting the wrong format is a silent no-op:

- truthy (`xH`/`mH`): `"1"` / `"true"` / `"yes"` / `"on"` -> true. Used by most flags.
- falsy (`VK`/`tK`): `"0"` / `"false"` / `"no"` / `"off"` -> true. Used by `CLAUDE_CODE_ATTRIBUTION_HEADER` and `ENABLE_CLAUDEAI_MCP_SERVERS` (disabling via `"0"` is correct).

## `attribution` section vs `CLAUDE_CODE_ATTRIBUTION_HEADER`

Both are active at different layers. The env var (`tK` check) controls whether the attribution header is injected into the system prompt. The `attribution` section (`commit`, `pr` keys) controls the template strings. Keeping both is correct.

## Effort levels: `max` is the env-only ceiling

Valid levels in 2.1.156 are ordered `["low","medium","high","xhigh","max"]` — `max` is the top, one notch above the newer `xhigh` (added with Opus 4.8 in 2.1.154). Opus 4.8 defaults to `high`.

- We set `CLAUDE_CODE_EFFORT_LEVEL=max` via env. Parser `hx()` accepts `max` (appears 92x in the binary, alias-mapped via `T67[_]??_` then validated); `OVH()` only maps `unset`/`auto` to null, everything else is parsed.
- `/effort` and the settings `effortLevel` field cap at `xhigh` (one zod schema is `["low","medium","high","xhigh"]).optional().catch(...)`). `max` is reachable **only via env**. Do NOT "fix" `max` to `xhigh` thinking xhigh is the highest — `max` is higher.
- `xhigh` effort plus standing dynamic-workflow orchestration is the new **ultracode** mode.

## `CLAUDE_CODE_EFFORT_LEVEL` set via `env` (not `effortLevel`)

Env takes precedence over `effortLevel` and over `/effort` mid-session. On the current model's first launch, `effortLevel` in settings is shadowed by the model's hardcoded launch-default (CLI's `UhH()` resolver has a `q ? K` branch keyed on specific model IDs) until session state "unpins". Env sidesteps that. Accepted trade-off: `/effort` can't override live; restart to change. No other env flag has an equivalent top-level settings key.

## `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`

No-op under the current model. 2.1.156 gates it as `xH(process.env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING)&&(j.includes("opus-4-6")||j.includes("sonnet-4-6"))` — Opus 4.8 doesn't match, so the flag never participates. Kept for future 4.6-series use; do not remove. (Adaptive thinking is now resolved per-model via `am6(model)`.)

## Internal process-to-process env — do NOT put these in settings

These look like user flags but are set by the CLI itself when spawning child processes (background sessions, `claude -p` print mode, crash-respawn). Setting them globally in `settings.json` `env` is a misuse: the parent's per-spawn logic gets overridden.

- `CLAUDE_CODE_RESUME_INTERRUPTED_TURN` — set by `if(this.attempt>1&&T)w.CLAUDE_CODE_RESUME_INTERRUPTED_TURN="1"` (only on retry/crash-respawn). All read sites are in `print.ts` and `[sessionRestore] Auto-resuming interrupted turn for bg crash-respawn` — none in the interactive REPL. Removed from our settings on 2026-05-29: it was a no-op interactively and risked false auto-resume on print/bg first-spawn.
- Siblings in the same spawn cleanup list (`delete A.<name>`): `CLAUDE_CODE_SESSION_NAME`, `CLAUDE_BG_BACKEND`, `CLAUDE_BG_SESSION_PERMISSION_RULES`, `CLAUDE_BG_MEMORY_TOGGLED_OFF`.

## New env flags observed in 2.1.152 to 2.1.156 (not in our settings)

For reference; add only if a concrete need appears:

- `CLAUDE_CODE_DISABLE_AUTO_MEMORY` — disables auto-memory (`autoMemoryEnabled`, default `true`; this is the memory system under `~/.claude/projects/.../memory/`).
- `CLAUDE_CODE_DISABLE_CLAUDE_CODE_SKILL` / `CLAUDE_CODE_DISABLE_CLAUDE_API_SKILL` — skip registering the built-in claude-code / claude-api skills (`if(!xH(...)){registerClaudeCodeSkill()}`).
- `CLAUDE_CODE_FORCE_MID_CONVERSATION_SYSTEM` — forces mid-conversation system injection (renamed from `CLAUDE_CODE_MID_CONVERSATION_SYSTEM`; disabled under hipaa). Lean system prompt is the default for Opus 4.8 as of 2.1.154.
- `CLAUDE_PTY_ORPHAN_CHECK_MS` — PTY orphan-check interval, `Number(...)||2000` ms, non-windows only.
- `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` — force the effort param on models that don't support it. `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` is deprecated (removed 06/01).
