---
paths:
  - ".chezmoitemplates/claude-settings.json"
  - "dot_config/claude-code/gateway-settings.json"
  - "dot_claude/modify_settings.json"
  - "dot_claude/CLAUDE.md"
  - "dot_claude/hooks/**/*"
  - "dot_claude/scripts/executable_statusline.sh"
  - "dot_zsh/functions/claude"
---

# Claude Code settings

This rule records only repository-specific intent and non-obvious interactions for the managed Claude Code settings. The [environment variable reference](https://code.claude.com/docs/en/env-vars), [settings reference](https://code.claude.com/docs/en/settings), and [sandbox reference](https://code.claude.com/docs/en/sandboxing) own current syntax, defaults, and compatibility history.

Add an entry only when a value would otherwise look removable, its literal form matters, or multiple settings must change together. Revalidate runtime-dependent conclusions after upgrades. Do not record minified symbols, internal gate names, call-site counts, or version history unless a live compatibility boundary depends on them.

## Ownership

`.chezmoitemplates/claude-settings.json` owns each top-level subtree it declares. `dot_claude/modify_settings.json` preserves undeclared live state and seeds `model` and `effortLevel` only when absent. `chezmoi re-add ~/.claude/settings.json` is a no-op; do not convert this target back to a plain source file.

## Session retention and unattended runs

- `cleanupPeriodDays=99999` intentionally retains transcripts for a practically indefinite period.
- `CLAUDE_CODE_RETRY_WATCHDOG=1` keeps unattended sessions waiting through retryable capacity errors instead of stopping at the normal retry limit.

## Privacy and feature delivery

`DISABLE_TELEMETRY=1` also disables server-side feature-flag fetching. Keep `CLAUDE_CODE_FORK_SUBAGENT=1` and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` as explicit opt-ins because both workflows are intentionally enabled here.

Do not consolidate the separate privacy controls into `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`; it would also disable automatic updates.

## Auto mode and file protection

- `permissions.defaultMode="auto"` delegates actions not already decided by explicit rules or sandbox auto-allow to the classifier.
- Keep bare `Bash` out of `permissions.allow`. Sandboxed Bash remains auto-approved, while commands that run outside the sandbox still use the regular auto-mode decision.
- `Read`, `Edit`, and `Write` stay broadly allowed for routine file work, so their path deny rules are the file-tool boundary. The Bash secret hook supplies the command-layer checks; keep both surfaces aligned when adding sensitive paths.
- Empty `attribution.commit` and `attribution.pr` values suppress generated Git attribution. `attribution.sessionUrl` stays the boolean `false` to suppress session links.

## Models, context, and statusline

- `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` pin the aliases used by the main session and `model: "sonnet"` subagents, preventing CLI upgrades from moving either workload implicitly.
- `autoCompactWindow` is a compaction threshold, not evidence of the active model's context size. Verify the effective budget from runtime status or the model picker before changing the model or threshold.
- `dot_claude/scripts/executable_statusline.sh` owns its compact-window parser and denominator calculation. Update and test both when changing `autoCompactWindow` or adding support for another compact override.

## Integrations and gateway behavior

- `dot_config/claude-code/gateway-settings.json` is loaded only for gateway sessions. Keep `apiKeyHelper` out of the shared settings because it takes precedence over subscription authentication. The `claude-gateway` envchain namespace supplies the gateway configuration, while the helper reads the token directly from the macOS Keychain so it does not enter the Claude process environment.
- `CLAUDE_CODE_ENABLE_CFC=0` explicitly disables automatic Claude in Chrome wiring; it does not govern the separately permitted `chrome-devtools` MCP tools. Keep the explicit false value because unset restores automatic eligibility.
- `disableClaudeAiConnectors=true` is the source of truth for blocking auto-fetched claude.ai connectors; explicitly configured MCP servers remain available.
- `disableBundledSkills=true` keeps the repository-managed skill registry authoritative. Keep the separate `disableWorkflows` setting unset because `ultracode` depends on dynamic workflows.
- `ENABLE_PROMPT_CACHING_1H=1` requests the one-hour cache used by this provider setup.
- `ENABLE_TOOL_SEARCH=1` forces MCP tool deferral through the custom gateway. Re-test after gateway changes because the gateway must preserve `tool_reference` blocks.

## Sandbox

- Keep `sandbox.enabled` and `sandbox.failIfUnavailable` enabled so a missing sandbox fails at startup instead of silently running every Bash command on the host.
- Exclusions are an accepted convenience trade-off. The sandbox exists to contain unknown behavior, but the everyday CLIs listed here cannot finish a sandboxed run without an open-ended series of write-path, domain, and Mach-service holes that is never exhaustive and not worth the upkeep. For these trusted daily tools we give up sandbox protection and let their own guardrails take over. `git:*` is the exception: it works sandboxed and is excluded only to keep Git on the regular auto-mode decision path.
- excludedCommands pattern grammar (verified against the 2.1.212 binary; docs show only examples): `cmd:*` is a prefix match on the command plus arguments; a pattern with a bare `*` is a whitespace-normalized glob over the whole command string; anything else is exact. Compound commands are split into subcommands with env-assignment and wrapper prefixes stripped, and one matching subcommand unsandboxes the entire command — so the companion filename glob is spoofable by any script named `codex-companion.mjs` (accepted trade-off to cover both its literal `${CLAUDE_PLUGIN_ROOT}` and expanded invocations with one entry).
- Extra write paths are limited to development tool caches and stores, plus `~/.codex`, which sandboxed tools that manage Codex state (e.g. `gh skill update --agent codex --scope user`) write into; codex itself runs excluded and no longer needs it. Sandboxed writes to `~/.codex/config.toml` are a side effect of this entry; the file stays chezmoi-managed, so treat unexplained drift there as suspect. Add a path only after an observed sandbox denial, and do not widen access to a whole home or source tree.
- Keep the rendered `getconf DARWIN_USER_TEMP_DIR` entry in `sandbox.filesystem.allowWrite`. The sandbox write allowlist covers only built-in static paths, Claude's own session temp directory, and configured entries, and nothing in it resolves the Darwin per-user temp directory ([sandbox-runtime defaults](https://github.com/anthropic-experimental/sandbox-runtime/blob/cf24a43eba92c9ab4140c380d11ca55771be9db2/src/sandbox/sandbox-utils.ts#L360-L375), [hardening decision](https://github.com/anthropic-experimental/sandbox-runtime/pull/182)), while bare macOS `mktemp` resolves `_CS_DARWIN_USER_TEMP_DIR` before `$TMPDIR` ([`mktemp(1)`](https://keith.github.io/xcode-man-pages/mktemp.1.html)); removing the entry therefore fails bare `mktemp` with `Operation not permitted`. Re-verify only with the entry absent from every loaded settings scope, e.g. a child `claude` with an isolated `CLAUDE_CONFIG_DIR` and explicit `--settings`; user-scope settings merge into a child session's sandbox even under `--setting-sources project,local`, so an in-place check false-passes. Keep only the rendered per-machine `T/` path; never widen it to a `/var/folders` ancestor.
- Allowed domains cover the source hosts, package registries, and Claude endpoints used by local development. Add domains from observed traffic, not anticipated convenience, and only for consumers that actually run sandboxed: entries here widen egress for every sandboxed command, and tools running via excludedCommands never consult this list.
- `allowLocalBinding=true` permits local test servers. The two GPG agent sockets permit signing and SSH authentication. `com.apple.trustd.agent` permits macOS certificate verification used by Go-based CLIs; add another Mach service only after an observed sandbox failure requires it.

## Worktrees and runtime-owned state

- `worktree.baseRef="head"` makes isolated sessions include local commits and feature-branch state instead of starting from the upstream default branch.
- Keep `model` and `effortLevel` as CLI-owned seed values. Do not move them into the managed fragment.
- Keep `CLAUDE_CODE_EFFORT_LEVEL` unset so `/effort` remains the session-level control; the environment variable overrides both `/effort` and the persisted setting.
