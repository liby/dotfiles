---
paths:
  - ".chezmoitemplates/claude-settings.json"
  - "dot_claude/modify_private_settings.json"
  - "dot_claude/CLAUDE.md"
  - "dot_claude/hooks/**/*"
  - "dot_claude/scripts/executable_statusline.sh"
---

# Claude Code settings

This rule records only repository-specific intent and non-obvious interactions for the managed Claude Code settings. The [environment variable reference](https://code.claude.com/docs/en/env-vars), [settings reference](https://code.claude.com/docs/en/settings), and [sandbox reference](https://code.claude.com/docs/en/sandboxing) own current syntax, defaults, and compatibility history.

Add an entry only when a value would otherwise look removable, its literal form matters, or multiple settings must change together. Revalidate runtime-dependent conclusions after upgrades. Do not record minified symbols, internal gate names, call-site counts, or version history unless a live compatibility boundary depends on them.

## Ownership

`.chezmoitemplates/claude-settings.json` owns its declared top-level subtrees. `dot_claude/modify_private_settings.json` preserves undeclared state, seeds missing `model` and `effortLevel` values, and keeps the target at `0600`. Keep this target partially managed; `chezmoi re-add ~/.claude/settings.json` is a no-op.

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

## Search tools

- `Grep` stays out of `permissions.deny` while `Glob` stays in: the structured Grep tool has no CLI flag or shell-quoting surface, which is where the corrupted `rg --replace` output and silent zero-result searches came from, while `fd` remains the file-discovery route. `pre-bash-policy.sh` blocks the `rg` flag misuse that survives on the Bash path.
- `USE_BUILTIN_RIPGREP=0` points the Grep tool at the system ripgrep so it and Bash `rg` share one engine version.

## Models, context, and statusline

- `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` pin the aliases used by the main session and `model: "sonnet"` subagents, preventing CLI upgrades from moving either workload implicitly.
- `autoCompactWindow` is a compaction threshold, not evidence of the active model's context size. Verify the effective budget from runtime status or the model picker before changing the model or threshold.
- `dot_claude/scripts/executable_statusline.sh` owns its compact-window parser and denominator calculation. Update and test both when changing `autoCompactWindow` or adding support for another compact override.

## Integrations

- `CLAUDE_CODE_ENABLE_CFC=0` explicitly disables automatic Claude in Chrome wiring; it does not govern the separately permitted `chrome-devtools` MCP tools. Keep the explicit false value because unset restores automatic eligibility.
- `disableClaudeAiConnectors=true` is the source of truth for blocking auto-fetched claude.ai connectors; explicitly configured MCP servers remain available.
- `disableBundledSkills=true` keeps the repository-managed skill registry authoritative. Keep the separate `disableWorkflows` setting unset because `ultracode` depends on dynamic workflows.
- `ENABLE_PROMPT_CACHING_1H=1` requests the one-hour cache used by this provider setup.
- `ENABLE_TOOL_SEARCH=1` forces MCP tool deferral through the custom gateway. Re-test after gateway changes because the gateway must preserve `tool_reference` blocks.

## Sandbox

- Keep `sandbox.enabled` and `sandbox.failIfUnavailable` enabled so a missing sandbox fails at startup instead of silently running every Bash command on the host.
- `excludedCommands` bypasses the sandbox for trusted CLIs that would otherwise need broad, unstable exceptions. `git:*` keeps direct Git commands on the regular auto-mode path.
- `excludedCommands` uses prefix matching for `cmd:*`, a whitespace-normalized whole-command glob for a bare `*`, and exact matching otherwise. In 2.1.214, direct `git ...` and leading `NAME=value git ...` match `git:*`; `env ... git ...`, loops, wrappers, and Claude-internal calls can remain sandboxed. The companion filename glob intentionally accepts spoofable names to match literal and expanded plugin paths.
- Extra write paths are limited to development tool caches and stores, plus `~/.codex`, which sandboxed tools that manage Codex state (e.g. `gh skill update --agent codex --scope user`) write into; codex itself runs excluded and no longer needs it. Sandboxed writes to `~/.codex/config.toml` are a side effect of this entry; the file stays chezmoi-managed, so treat unexplained drift there as suspect. Add a path only after an observed sandbox denial, and do not widen access to a whole home or source tree.
- Keep the rendered `getconf DARWIN_USER_TEMP_DIR` entry in `sandbox.filesystem.allowWrite`. The sandbox write allowlist covers only built-in static paths, Claude's own session temp directory, and configured entries, and nothing in it resolves the Darwin per-user temp directory ([sandbox-runtime defaults](https://github.com/anthropic-experimental/sandbox-runtime/blob/cf24a43eba92c9ab4140c380d11ca55771be9db2/src/sandbox/sandbox-utils.ts#L360-L375), [hardening decision](https://github.com/anthropic-experimental/sandbox-runtime/pull/182)), while bare macOS `mktemp` resolves `_CS_DARWIN_USER_TEMP_DIR` before `$TMPDIR` ([`mktemp(1)`](https://keith.github.io/xcode-man-pages/mktemp.1.html)); removing the entry therefore fails bare `mktemp` with `Operation not permitted`. Re-verify only with the entry absent from every loaded settings scope, e.g. a child `claude` with an isolated `CLAUDE_CONFIG_DIR` and explicit `--settings`; user-scope settings merge into a child session's sandbox even under `--setting-sources project,local`, so an in-place check false-passes. Keep only the rendered per-machine `T/` path; never widen it to a `/var/folders` ancestor.
- Allowed domains cover the source hosts, package registries, and Claude endpoints used by local development. Add domains from observed traffic, not anticipated convenience, and only for consumers that actually run sandboxed: entries here widen egress for every sandboxed command, and tools running via excludedCommands never consult this list.
- `allowUnixSockets` permits the two GPG agent sockets and `~/Code`, where `core.fsmonitor` is enabled. `~/Code` covers per-repository `.git/fsmonitor--daemon.ipc` sockets for wrapped Git without opening Docker or SSH agent sockets. `allowLocalBinding=true` supports local test servers; `com.apple.trustd.agent` supports macOS certificate verification. Add entries only after an observed failure.

## Worktrees and runtime-owned state

- `worktree.baseRef="head"` makes isolated sessions include local commits and feature-branch state instead of starting from the upstream default branch.
- Keep `model` and `effortLevel` as CLI-owned seed values. Do not move them into the managed fragment.
- Keep `CLAUDE_CODE_EFFORT_LEVEL` unset so `/effort` remains the session-level control; the environment variable overrides both `/effort` and the persisted setting.
