---
paths:
  - ".chezmoitemplates/claude/claude.json"
  - ".chezmoitemplates/claude/settings.json"
  - "modify_dot_claude.json"
  - "dot_claude/modify_private_settings.json"
  - "dot_claude/CLAUDE.md.tmpl"
  - "dot_claude/output-styles/**/*"
  - "dot_claude/hooks/**/*"
  - "dot_claude/scripts/executable_statusline.sh"
---

# Claude Code settings

This is not a settings reference. Keep only repository-specific decisions that cannot be recovered from the managed configuration, its owning code, or the [environment variable](https://code.claude.com/docs/en/env-vars), [settings](https://code.claude.com/docs/en/settings), and [sandbox](https://code.claude.com/docs/en/sandboxing) references.

Revalidate runtime-dependent evidence after upgrades.

## Ownership

Keep `~/.claude/settings.json` and `~/.claude.json` partially managed so Claude Code's runtime-owned state survives chezmoi applies. Do not replace their modifiers with complete templates or move `model` and `effortLevel` into the managed fragment; `chezmoi re-add` cannot reconcile these targets.

Apply the [configuration ownership boundary](../../.github/CONCEPTS.md#configuration-ownership) per server in `~/.claude.json`: source-declared MCP registrations are fully managed, while undeclared registrations and other runtime state remain intact.

Keep main-conversation presentation and terminology defaults in `dot_claude/output-styles/natural-technical-writing.md`, with `keep-coding-instructions: true` so the built-in engineering instructions remain active. Keep operating and artifact contracts, including verification of model and delegated reports, in `dot_claude/CLAUDE.md.tmpl`. Non-fork subagents use separate system prompts and do not inherit the output style.

## Session retention and unattended runs

- `cleanupPeriodDays=99999` intentionally retains transcripts for a practically indefinite period.
- `CLAUDE_CODE_RETRY_WATCHDOG=1` keeps unattended sessions waiting through retryable capacity errors. Keep `fallbackModel` unset while the watchdog is on: the watchdog exists to wait for the requested model, while a fallback would silently downgrade the runs it protects.

## Privacy and feature delivery

`DISABLE_TELEMETRY=1` also disables server-side feature-flag fetching. Keep `CLAUDE_CODE_FORK_SUBAGENT=1` and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` as explicit opt-ins because both workflows are intentionally enabled here.

Do not consolidate the separate privacy controls into `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`; it would also disable automatic updates.

## Auto mode and file protection

- Keep bare `Bash` out of `permissions.allow`. Sandboxed Bash remains auto-approved, while commands that run outside the sandbox still use the regular auto-mode decision.
- Keep `Bash(herdr:*)` and `Bash(oracle:*)` globally allowed because their panes or sessions can continue after the invoking Skill's turn, when frontmatter preapproval no longer applies. Keep `Bash(snow:*)` globally allowed for the standing direct-command and native-SSO execution path owned by [Shared agent execution](../../.github/CONCEPTS.md#shared-agent-execution). Do not mirror same-turn Git or other host-CLI commands globally unless a current-version reproducer shows that Claude denies the matching Skill grant. Their sandbox exclusions remain separately necessary for Herdr control, Oracle browser control, and native Snowflake SSO.
- Do not mirror `excludedCommands` into `permissions.allow`: sandbox placement and permission approval are independent decisions. `chezmoi`, `docker`, and direct `codex` stay on the regular auto-mode path; Git commands receive narrower Skill approvals.
- `Read`, `Edit`, and `Write` stay broadly allowed for routine file work, so their path deny rules are the file-tool boundary. The Bash secret hook supplies the command-layer checks; keep both surfaces aligned when adding sensitive paths. `~/.ssh` is the exception: `pre-tool-guard.py` also runs for `Read|Edit|Write|Grep` because its policy allows public keys, client config, `allowed_signers`, and `known_hosts` inside an otherwise private directory, which a deny glob cannot express, so do not add `~/.ssh` deny rules back. Grep permits explicit public files; directory searches covering private SSH material must be narrowed. Do not use glob rewriting to grant access: composing public reinclusions with the caller's filter changes search scope.

The Bash guard uses native Zsh tokenization for direct commands and ordinary pipelines and lists. Keep it out of shell execution semantics: it does not expand variables, enter compound bodies, interpret child-shell or eval strings, or follow heredoc input and file descriptors. Common bare execution prefixes and env options are supported; other wrappers remain outside precise command-policy checks. Its separate sensitive-signature scan intentionally also inspects literal examples, comments and heredoc text. For static pipelines consisting only of `rg` and `grep`, `.env` search patterns are distinguished from file operands; pattern files and positive file selectors remain reads. Other forms and unknown search options retain the conservative signature check. After a heredoc delimiter, precise checks stop at the first newline or semicolon; normal permissions and sandboxing still govern unchecked forms.

## Search tools

For `gh auth status`, an explicit token-display flag is rejected even if another option cancels it. Omit the display flag for ordinary status inspection; do not add CLI boolean-precedence emulation to the guard.

- `Grep` stays out of `permissions.deny` while `Glob` stays in: the structured Grep tool has no CLI flag or shell-quoting surface, which is where the corrupted `rg --replace` output and silent zero-result searches came from, while `fd` remains the file-discovery route. `pre-tool-guard.py` blocks the `rg` flag misuse that survives on the Bash path.
- `USE_BUILTIN_RIPGREP=0` points the Grep tool at the system ripgrep so it and Bash `rg` share one engine version.

## Models, context, and statusline

- Keep the Opus and Sonnet aliases pinned while the gateway serves those exact model IDs; otherwise its aliases lag the first-party route. Because the pins also stop CLI upgrades from advancing first-party sessions, re-check them whenever a new model generation ships rather than treating either pin as permanent.
- `ANTHROPIC_DEFAULT_FABLE_MODEL` and `ANTHROPIC_DEFAULT_OPUS_MODEL` carry the `[1m]` suffix; the Sonnet and Haiku pins do not. The managed env block serves both modes of the `claude` launcher, and in gateway mode Claude Code runs as the Vertex provider, where it budgets a model at 1M without the suffix only when its built-in catalog marks that model natively 1M on Vertex. Sonnet 5 has that mark; Opus 5 and Fable 5.1 do not, so without the suffix Vertex sessions and `model: opus` subagents fall to 200K and `autoCompactWindow` is capped to that window. On the subscription route the suffix is inert: the `fable` alias drops it and Opus 5 accepts the 1M beta natively. Never add it to the Haiku pin, whose 200K model would receive an unsupported beta header. Keep the suffix in the variables rather than at delegation call sites, because Vertex alias resolution has no automatic 1M step.
- `autoCompactWindow` is a compaction threshold, not evidence of the active model's context size. Verify the effective budget from runtime status or the model picker before changing the model or threshold.
- `precomputeCompactionEnabled=true` builds the compaction summary in the background before the threshold is reached, removing the foreground stall. It defaults to false, so the explicit value is what enables it, and it only applies while auto-compact is on; it must move together with any change that disables auto-compact.
- `dot_claude/scripts/executable_statusline.sh` owns its compact-window parser and denominator calculation. Update and test both when changing `autoCompactWindow` or adding support for another compact override.

## Integrations

- `CLAUDE_CODE_ENABLE_CFC=0` explicitly disables automatic Claude in Chrome wiring; it does not govern the separately permitted `chrome-devtools` MCP tools. Keep the explicit false value because unset restores automatic eligibility.
- Keep `CLAUDE_CODE_DISABLE_CRON=1` with the bare `ScheduleWakeup` deny while local scheduling is retired. The environment variable removes `/loop` and the Cron tools, but Claude Code 2.1.252 still registers `ScheduleWakeup` eagerly. Cloud Routines are account-owned and unaffected. Remove the deny only after a cleanly restarted session and a resumed session, both with the environment flag enabled, cannot create, retain, or execute a scheduled wakeup through any exposed scheduling surface.
- `disableClaudeAiConnectors=true` is the source of truth for blocking auto-fetched claude.ai connectors; explicitly configured MCP servers remain available.
- `disableBundledSkills=true` keeps the repository-managed skill registry authoritative. Keep the separate `disableWorkflows` setting unset because `ultracode` depends on dynamic workflows.
- `ENABLE_TOOL_SEARCH=1` forces MCP tool deferral through the custom gateway. Re-test after gateway changes because the gateway must preserve `tool_reference` blocks.
- The `SessionStart` entry registers a hook owned by `herdr integration install claude`; see [Herdr integrations](../../.github/CONCEPTS.md#herdr-integrations). Keep the installer's exact `bash '<absolute path>' session` form, because with the repository's usual `~/.claude/hooks/...` form a reinstall appends a duplicate entry instead of recognizing this one.

## Sandbox

- Treat `excludedCommands` entries as deliberate command shapes, not universal wrapper-aware policies. Matching runs per segment and exempts the whole line: when any `&&`-, `;`-, or `|`-separated segment starts with an excluded command, every segment runs outside the sandbox, so an entry exempts far more than the named tool. Leading `cd`, variable assignments, and `command` are looked through; a wrapper such as `env` in front of the command keeps the line sandboxed. Do not broaden a matcher without an observed failure.
- Extra write paths are limited to development tool caches and stores, plus `~/.codex`, which sandboxed tools that manage Codex state (e.g. `gh skill update --agent codex --scope user`) write into; codex itself runs excluded and no longer needs it. `~/.oracle` exists for sandboxed parents of oracle such as the skill-validator smoke, whose oracle dry-run chmods `~/.oracle/sessions`; direct `oracle` commands run excluded and never needed it. Sandboxed writes to `~/.codex/config.toml` are a side effect of this entry; the file stays chezmoi-managed, so treat unexplained drift there as suspect. Add a path only after an observed sandbox denial, and do not widen access to a whole home or source tree.
- `denyRead` covers `~/.ssh` as a directory and `allowRead` reopens the same files the hook allows. `allowRead` accepts `*.pub` and `config.*` patterns, so keep the exceptions as patterns rather than key names; re-test pattern support with an isolated `--settings` file, because merged user settings mask a removal. `Read` deny rules also feed the sandbox, so a `Read(~/.ssh/...)` deny would block public keys inside the sandbox as well.
- Keep the rendered `getconf DARWIN_USER_TEMP_DIR` entry in `sandbox.filesystem.allowWrite`: bare macOS `mktemp` resolves that per-user directory, which Claude's built-in allowlist omits. Removing it makes `mktemp` fail with `Operation not permitted`. Re-test only with an isolated `CLAUDE_CONFIG_DIR`, because merged user settings make an in-place removal test false-pass; keep the rendered `T/` path rather than a `/var/folders` ancestor.
- Add allowed domains only after observed sandbox traffic: every entry widens egress for all sandboxed commands, while excluded commands never consult the list. Keep `network.strictAllowlist` unset so a novel host prompts instead of failing deterministically; promote repeatedly approved hosts from runtime-owned state into `allowedDomains`. The setting is OR-merged, so another managed scope can still force strict mode.
- `allowUnixSockets` permits the gpg-agent and keyboxd sockets (private key and public-key lookup) plus the gpg-agent SSH socket. Any line with a `git` segment runs excluded from the sandbox, so these serve sandboxed `gpg`, `ssh`, and git invoked by a sandboxed parent such as `gh`, `glab`, or a hook script. Without the keyboxd entry a sandboxed `gpg` reports `no keyboxd running in this session` while the daemon is running. `allowLocalBinding=true` emits three seatbelt rules, not one: bind and inbound on any local port, plus outbound to `localhost:*`. Sandboxed clients of a local server therefore depend on this same entry, so do not narrow it to the server side. `com.apple.trustd.agent` supports macOS certificate verification for Go-based CLIs; it is absent from the fixed built-in mach-lookup list, so this explicit entry is the only thing granting it short of `enableWeakerNetworkIsolation`, which the sandbox schema itself labels a security reduction. Add entries only after an observed failure.

## Worktrees and runtime-owned state

- `worktree.baseRef="head"` makes isolated sessions include local commits and feature-branch state instead of starting from the upstream default branch.
- Keep `CLAUDE_CODE_EFFORT_LEVEL` unset so `/effort` remains the session-level control; the environment variable overrides both `/effort` and the persisted setting.
