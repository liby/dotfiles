---
paths:
  - ".chezmoitemplates/claude/settings.json"
  - "modify_dot_claude.json"
  - "dot_claude/modify_private_settings.json"
  - "dot_claude/CLAUDE.md"
  - "dot_claude/output-styles/**/*"
  - "dot_claude/hooks/**/*"
  - "dot_claude/scripts/executable_statusline.sh"
---

# Claude Code settings

This is not a settings reference. Keep only repository-specific decisions that cannot be recovered from the managed configuration, its owning code, or the [environment variable](https://code.claude.com/docs/en/env-vars), [settings](https://code.claude.com/docs/en/settings), and [sandbox](https://code.claude.com/docs/en/sandboxing) references.

Revalidate runtime-dependent evidence after upgrades.

## Ownership

Keep `~/.claude/settings.json` and `~/.claude.json` partially managed so Claude Code's runtime-owned state survives chezmoi applies. Do not replace their modifiers with complete templates or move `model` and `effortLevel` into the managed fragment; `chezmoi re-add` cannot reconcile these targets.

Keep main-conversation language and terminology defaults in `dot_claude/output-styles/natural-technical-writing.md`, with `keep-coding-instructions: true` so the built-in engineering instructions remain active. Keep operating and artifact contracts in `dot_claude/CLAUDE.md`. Non-fork subagents use separate system prompts, so the style treats their reports as working material before the main conversation reuses them.

## Session retention and unattended runs

- `cleanupPeriodDays=99999` intentionally retains transcripts for a practically indefinite period.
- `CLAUDE_CODE_RETRY_WATCHDOG=1` keeps unattended sessions waiting through retryable capacity errors. Keep `fallbackModel` unset while the watchdog is on: the watchdog exists to wait for the requested model, while a fallback would silently downgrade the runs it protects.

## Privacy and feature delivery

`DISABLE_TELEMETRY=1` also disables server-side feature-flag fetching. Keep `CLAUDE_CODE_FORK_SUBAGENT=1` and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` as explicit opt-ins because both workflows are intentionally enabled here.

Do not consolidate the separate privacy controls into `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`; it would also disable automatic updates.

## Auto mode and file protection

- Keep bare `Bash` out of `permissions.allow`. Sandboxed Bash remains auto-approved, while commands that run outside the sandbox still use the regular auto-mode decision.
- Keep `Bash(herdr:*)` and `Bash(oracle:*)` globally allowed because their panes or sessions can continue after the invoking Skill's turn, when frontmatter preapproval no longer applies. Keep `Bash(snow:*)` globally allowed for the standing direct-command and native-SSO execution path owned by [Shared agent execution](../../.github/CONCEPTS.md#shared-agent-execution). Do not mirror same-turn Git or other host-CLI commands globally unless a current-version reproducer shows that Claude denies the matching Skill grant. Their sandbox exclusions remain separately necessary for Herdr control, Oracle browser control, and native Snowflake SSO.
- Do not mirror `excludedCommands` into `permissions.allow`: sandbox placement and permission approval are independent decisions. `chezmoi`, `docker`, and direct `codex` stay on the regular auto-mode path; Git and plugin commands receive narrower Skill or plugin approvals. The companion filename exclusion is intentionally broad enough to match expanded plugin paths and must not become a spoofable global allow rule.
- `Read`, `Edit`, and `Write` stay broadly allowed for routine file work, so their path deny rules are the file-tool boundary. The Bash secret hook supplies the command-layer checks; keep both surfaces aligned when adding sensitive paths.

## Search tools

- `Grep` stays out of `permissions.deny` while `Glob` stays in: the structured Grep tool has no CLI flag or shell-quoting surface, which is where the corrupted `rg --replace` output and silent zero-result searches came from, while `fd` remains the file-discovery route. `pre-bash-policy.sh` blocks the `rg` flag misuse that survives on the Bash path.
- `USE_BUILTIN_RIPGREP=0` points the Grep tool at the system ripgrep so it and Bash `rg` share one engine version.

## Models, context, and statusline

- Keep the Opus and Sonnet aliases pinned while the gateway serves those exact model IDs; otherwise its aliases lag the first-party route. Because the pins also stop CLI upgrades from advancing first-party sessions, re-check them whenever a new model generation ships rather than treating either pin as permanent.
- `autoCompactWindow` is a compaction threshold, not evidence of the active model's context size. Verify the effective budget from runtime status or the model picker before changing the model or threshold.
- `precomputeCompactionEnabled=true` builds the compaction summary in the background before the threshold is reached, removing the foreground stall. It defaults to false, so the explicit value is what enables it, and it only applies while auto-compact is on; it must move together with any change that disables auto-compact.
- `dot_claude/scripts/executable_statusline.sh` owns its compact-window parser and denominator calculation. Update and test both when changing `autoCompactWindow` or adding support for another compact override.

## Integrations

- `CLAUDE_CODE_ENABLE_CFC=0` explicitly disables automatic Claude in Chrome wiring; it does not govern the separately permitted `chrome-devtools` MCP tools. Keep the explicit false value because unset restores automatic eligibility.
- Keep `CLAUDE_CODE_DISABLE_CRON=1` with the bare `ScheduleWakeup` deny while local scheduling is retired. The environment variable removes `/loop` and the Cron tools, but Claude Code 2.1.252 still registers `ScheduleWakeup` eagerly. Cloud Routines are account-owned and unaffected. Remove the deny only after a cleanly restarted session and a resumed session, both with the environment flag enabled, cannot create, retain, or execute a scheduled wakeup through any exposed scheduling surface.
- `disableClaudeAiConnectors=true` is the source of truth for blocking auto-fetched claude.ai connectors; explicitly configured MCP servers remain available.
- `disableBundledSkills=true` keeps the repository-managed skill registry authoritative. Keep the separate `disableWorkflows` setting unset because `ultracode` depends on dynamic workflows.
- `ENABLE_TOOL_SEARCH=1` forces MCP tool deferral through the custom gateway. Re-test after gateway changes because the gateway must preserve `tool_reference` blocks.

## Sandbox

- Treat `excludedCommands` entries as deliberate command shapes, not universal wrapper-aware policies. Environment or wrapper prefixes can keep a command sandboxed; do not broaden a matcher without an observed failure. The companion filename glob intentionally accepts spoofable names only to match literal and expanded plugin paths, which is why it is never globally pre-approved.
- Extra write paths are limited to development tool caches and stores, plus `~/.codex`, which sandboxed tools that manage Codex state (e.g. `gh skill update --agent codex --scope user`) write into; codex itself runs excluded and no longer needs it. `~/.oracle` exists for sandboxed parents of oracle such as the skill-validator smoke, whose oracle dry-run chmods `~/.oracle/sessions`; direct `oracle` commands run excluded and never needed it. Sandboxed writes to `~/.codex/config.toml` are a side effect of this entry; the file stays chezmoi-managed, so treat unexplained drift there as suspect. Add a path only after an observed sandbox denial, and do not widen access to a whole home or source tree.
- Keep the rendered `getconf DARWIN_USER_TEMP_DIR` entry in `sandbox.filesystem.allowWrite`: bare macOS `mktemp` resolves that per-user directory, which Claude's built-in allowlist omits. Removing it makes `mktemp` fail with `Operation not permitted`. Re-test only with an isolated `CLAUDE_CONFIG_DIR`, because merged user settings make an in-place removal test false-pass; keep the rendered `T/` path rather than a `/var/folders` ancestor.
- Add allowed domains only after observed sandbox traffic: every entry widens egress for all sandboxed commands, while excluded commands never consult the list. Keep `network.strictAllowlist` unset so a novel host prompts instead of failing deterministically; promote repeatedly approved hosts from runtime-owned state into `allowedDomains`. The setting is OR-merged, so another managed scope can still force strict mode.
- `allowUnixSockets` permits the two GPG agent sockets used for signing and SSH authentication. `allowLocalBinding=true` emits three seatbelt rules, not one: bind and inbound on any local port, plus outbound to `localhost:*`. Sandboxed clients of a local server therefore depend on this same entry, so do not narrow it to the server side. `com.apple.trustd.agent` supports macOS certificate verification for Go-based CLIs; it is absent from the fixed built-in mach-lookup list, so this explicit entry is the only thing granting it short of `enableWeakerNetworkIsolation`, which the sandbox schema itself labels a security reduction. Add entries only after an observed failure.

## Worktrees and runtime-owned state

- `worktree.baseRef="head"` makes isolated sessions include local commits and feature-branch state instead of starting from the upstream default branch.
- Keep `CLAUDE_CODE_EFFORT_LEVEL` unset so `/effort` remains the session-level control; the environment variable overrides both `/effort` and the persisted setting.
