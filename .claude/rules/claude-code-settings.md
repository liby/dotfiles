---
paths:
  - ".chezmoitemplates/claude-settings.json"
  - "modify_dot_claude.json"
  - "dot_claude/modify_private_settings.json"
  - "dot_claude/CLAUDE.md"
  - "dot_claude/hooks/**/*"
  - "dot_claude/scripts/executable_statusline.sh"
---

# Claude Code settings

This rule records only repository-specific intent and non-obvious interactions for the managed Claude Code settings. The [environment variable reference](https://code.claude.com/docs/en/env-vars), [settings reference](https://code.claude.com/docs/en/settings), and [sandbox reference](https://code.claude.com/docs/en/sandboxing) own current syntax, defaults, and compatibility history.

Add an entry only when a value would otherwise look removable, its literal form matters, or multiple settings must change together. Revalidate runtime-dependent conclusions after upgrades. Do not record minified symbols, internal gate names, call-site counts, or version history unless a live compatibility boundary depends on them.

## Ownership

`.chezmoitemplates/claude-settings.json` owns its declared top-level subtrees. `dot_claude/modify_private_settings.json` preserves undeclared state, seeds missing `model` and `effortLevel` values, and keeps the target at `0600`. `modify_dot_claude.json` preserves all other `~/.claude.json` state and owns only `leftArrowOpensAgents=false` and `autoConnectIde=true`. Keep both targets partially managed; `chezmoi re-add` is a no-op for them.

## Session retention and unattended runs

- `cleanupPeriodDays=99999` intentionally retains transcripts for a practically indefinite period.
- `CLAUDE_CODE_RETRY_WATCHDOG=1` keeps unattended sessions waiting through retryable capacity errors instead of stopping at the normal retry limit. It exempts exactly 529 overloaded and 429 rate-limit responses from retry exhaustion, and it also suppresses `fallbackModel` for the server-error class. Keep `fallbackModel` unset while the watchdog is on: the watchdog exists to wait for the requested model, and a fallback list would silently downgrade the very runs it protects.

## Privacy and feature delivery

`DISABLE_TELEMETRY=1` also disables server-side feature-flag fetching. Keep `CLAUDE_CODE_FORK_SUBAGENT=1` and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` as explicit opt-ins because both workflows are intentionally enabled here.

Do not consolidate the separate privacy controls into `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`; it would also disable automatic updates.

## Auto mode and file protection

- `permissions.defaultMode="auto"` delegates actions not already decided by explicit rules or sandbox auto-allow to the classifier.
- Keep bare `Bash` out of `permissions.allow`. Sandboxed Bash remains auto-approved, while commands that run outside the sandbox still use the regular auto-mode decision.
- `Bash(oracle:*)` in `permissions.allow` exists because `oracle:*` in `sandbox.excludedCommands` alone is not enough: oracle needs to run unsandboxed for browser control, and its second-opinion runs attach repository files to an external ChatGPT session, a decision the user has standing-approved via this rule instead of per-run. The pair moves together.
- `Read`, `Edit`, and `Write` stay broadly allowed for routine file work, so their path deny rules are the file-tool boundary. The Bash secret hook supplies the command-layer checks; keep both surfaces aligned when adding sensitive paths.
- Empty `attribution.commit` and `attribution.pr` values suppress generated Git attribution. `attribution.sessionUrl` stays the boolean `false` to suppress session links.

## Search tools

- `Grep` stays out of `permissions.deny` while `Glob` stays in: the structured Grep tool has no CLI flag or shell-quoting surface, which is where the corrupted `rg --replace` output and silent zero-result searches came from, while `fd` remains the file-discovery route. `pre-bash-policy.sh` blocks the `rg` flag misuse that survives on the Bash path.
- `USE_BUILTIN_RIPGREP=0` points the Grep tool at the system ripgrep so it and Bash `rg` share one engine version.

## Models, context, and statusline

- `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` pin the aliases used by the main session and `model: "sonnet"` subagents, preventing CLI upgrades from moving either workload implicitly. The pin has a standing cost: with the variable unset the CLI resolves the alias from a provider-aware table whose first-party entries track the newest generation, so a stale pin keeps every `opus` or `sonnet` caller on a previous generation with no warning, exactly what happened between the Opus 5 release and the audit that corrected it. Re-check both values whenever a new model generation ships. The pin also overrides the gateway launch path, whose built-in aliases resolve a generation behind the first-party ones; keep it only while the gateway serves the pinned IDs.
- `autoCompactWindow` is a compaction threshold, not evidence of the active model's context size. Verify the effective budget from runtime status or the model picker before changing the model or threshold.
- `precomputeCompactionEnabled=true` builds the compaction summary in the background before the threshold is reached, removing the foreground stall. It defaults to false, so the explicit value is what enables it, and it only applies while auto-compact is on; it must move together with any change that disables auto-compact.
- `dot_claude/scripts/executable_statusline.sh` owns its compact-window parser and denominator calculation. Update and test both when changing `autoCompactWindow` or adding support for another compact override.

## Integrations

- `leftArrowOpensAgents=false` removes the left-arrow shortcut into Agent View without disabling Agent View or background agents.
- `autoConnectIde=true` lets sessions launched from an external terminal discover a running IDE; extension installation remains a separate setting.
- `CLAUDE_CODE_ENABLE_CFC=0` explicitly disables automatic Claude in Chrome wiring; it does not govern the separately permitted `chrome-devtools` MCP tools. Keep the explicit false value because unset restores automatic eligibility.
- `disableClaudeAiConnectors=true` is the source of truth for blocking auto-fetched claude.ai connectors; explicitly configured MCP servers remain available.
- `disableBundledSkills=true` keeps the repository-managed skill registry authoritative. Keep the separate `disableWorkflows` setting unset because `ultracode` depends on dynamic workflows.
- `ENABLE_PROMPT_CACHING_1H=1` requests the one-hour cache used by this provider setup.
- `ENABLE_TOOL_SEARCH=1` forces MCP tool deferral through the custom gateway. Re-test after gateway changes because the gateway must preserve `tool_reference` blocks.

## Sandbox

- Keep `sandbox.enabled` and `sandbox.failIfUnavailable` enabled so a missing sandbox fails at startup instead of silently running every Bash command on the host.
- `excludedCommands` bypasses the sandbox for trusted CLIs that would otherwise need broad, unstable exceptions. `git:*` keeps direct Git commands on the regular auto-mode path.
- `excludedCommands` uses prefix matching for `cmd:*`, a whitespace-normalized whole-command glob for a bare `*`, and exact matching otherwise. Re-verified in 2.1.219: direct `git ...` and leading `NAME=value git ...` match `git:*`, because the matcher strips leading assignments before comparing. It stops stripping at any `PATH=`, `LD_*`, or `DYLD_*` assignment, so `PATH=/x git status` stays sandboxed by design. Wrapper stripping covers a fixed list of `timeout`, `time`, `nice`, `stdbuf`, `nohup`, `command`, `builtin`, and `noglob` only, so `env ... git ...` never reduces to a `git:*` match and stays sandboxed; loops and Claude-internal calls behave the same way. The companion filename glob intentionally accepts spoofable names to match literal and expanded plugin paths.
- Extra write paths are limited to development tool caches and stores, plus `~/.codex`, which sandboxed tools that manage Codex state (e.g. `gh skill update --agent codex --scope user`) write into; codex itself runs excluded and no longer needs it. Sandboxed writes to `~/.codex/config.toml` are a side effect of this entry; the file stays chezmoi-managed, so treat unexplained drift there as suspect. Add a path only after an observed sandbox denial, and do not widen access to a whole home or source tree.
- Keep the rendered `getconf DARWIN_USER_TEMP_DIR` entry in `sandbox.filesystem.allowWrite`. The sandbox write allowlist covers only built-in static paths, Claude's own session temp directory, and configured entries, and nothing in it resolves the Darwin per-user temp directory ([sandbox-runtime defaults](https://github.com/anthropic-experimental/sandbox-runtime/blob/cf24a43eba92c9ab4140c380d11ca55771be9db2/src/sandbox/sandbox-utils.ts#L360-L375), [hardening decision](https://github.com/anthropic-experimental/sandbox-runtime/pull/182)), while bare macOS `mktemp` resolves `_CS_DARWIN_USER_TEMP_DIR` before `$TMPDIR` ([`mktemp(1)`](https://keith.github.io/xcode-man-pages/mktemp.1.html)); removing the entry therefore fails bare `mktemp` with `Operation not permitted`. Re-verify only with the entry absent from every loaded settings scope, e.g. a child `claude` with an isolated `CLAUDE_CONFIG_DIR` and explicit `--settings`; user-scope settings merge into a child session's sandbox even under `--setting-sources project,local`, so an in-place check false-passes. Keep only the rendered per-machine `T/` path; never widen it to a `/var/folders` ancestor.
- Allowed domains cover the source hosts, package registries, and Claude endpoints used by local development. Add domains from observed traffic, not anticipated convenience, and only for consumers that actually run sandboxed: entries here widen egress for every sandboxed command, and tools running via excludedCommands never consult this list.
- Leave `network.strictAllowlist` unset. Setting it replaces the interactive "Allow network connection to `<host>`?" prompt with a deterministic deny; the prompt is wanted, so a novel host can be approved in place instead of requiring an edit here. The cost is that an approval writes the host into unmanaged session or local settings, so promote hosts you keep approving into `allowedDomains`. Note it is OR-merged across user, managed, and `--settings` scopes, so a managed policy elsewhere can still turn it on.
- `allowUnixSockets` permits the two GPG agent sockets and `~/Code`, where `core.fsmonitor` is enabled. `~/Code` covers per-repository `.git/fsmonitor--daemon.ipc` sockets for wrapped Git without opening Docker or SSH agent sockets. `allowLocalBinding=true` emits three seatbelt rules, not one: bind and inbound on any local port, plus outbound to `localhost:*`. Sandboxed clients of a local server therefore depend on this same entry, so do not narrow it to the server side. `com.apple.trustd.agent` supports macOS certificate verification for Go-based CLIs; it is absent from the fixed built-in mach-lookup list, so this explicit entry is the only thing granting it short of `enableWeakerNetworkIsolation`, which the sandbox schema itself labels a security reduction. Add entries only after an observed failure.

## Worktrees and runtime-owned state

- `worktree.baseRef="head"` makes isolated sessions include local commits and feature-branch state instead of starting from the upstream default branch.
- Keep `model` and `effortLevel` as CLI-owned seed values. Do not move them into the managed fragment.
- Keep `CLAUDE_CODE_EFFORT_LEVEL` unset so `/effort` remains the session-level control; the environment variable overrides both `/effort` and the persisted setting.
