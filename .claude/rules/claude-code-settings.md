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

Keep `~/.claude/settings.json` and `~/.claude.json` partially managed per the [configuration ownership boundary](../../.github/CONCEPTS.md#configuration-ownership), so keys source does not declare, which Claude Code writes at runtime, survive chezmoi applies. Do not replace their modifiers with complete templates; `chezmoi re-add` cannot reconcile these targets.

Each top-level key in `~/.claude/settings.json` has one of three roles:

- Managed: declared in `.chezmoitemplates/claude/settings.json`. Every apply overwrites the live value, so a change made inside Claude Code lasts only until the next apply. This is the default for any key source sets.
- Seed: declared in `$seeds` in `dot_claude/modify_private_settings.json`. Apply writes it only when the key is missing from the live file, and never touches it afterwards.
- Undeclared: in neither. Apply leaves the live value as Claude Code wrote it. Removing a key from the fragment moves it here without deleting its live value.

Seed a key only when routine use changes it so often that restoring it on every apply would undo that use. Only `model` and `effortLevel`, switched through `/model` and `/effort`, meet that bar; the seed still gives a new machine the intended starting value, which leaving them undeclared would not. Seed `model` as the `opus` alias rather than a model ID: a seed is written once, so an ID would freeze each machine on the generation current at its first apply, while the alias follows the Opus pin and its `[1m]` suffix. Being changeable inside Claude Code is not the criterion: many managed keys, such as `advisorModel`, change in a session and stay managed, so make the change durable in the fragment. Keep `CLAUDE_CODE_EFFORT_LEVEL` unset because it overrides both `/effort` and the persisted `effortLevel`, which defeats the seed.

`~/.claude.json` has no seeds. `modify_dot_claude.json` overlays its declared keys and replaces each source-declared MCP server whole, so removed transport fields disappear; undeclared servers and all other state stay intact.

Keep main-conversation presentation and terminology defaults in `dot_claude/output-styles/natural-technical-writing.md`, with `keep-coding-instructions: true` so the built-in engineering instructions remain active. Keep operating and artifact contracts, including verification of model and delegated reports, in `dot_claude/CLAUDE.md.tmpl`. Non-fork subagents use separate system prompts and do not inherit the output style.

## Session retention and unattended runs

- `cleanupPeriodDays=99999` intentionally retains transcripts for a practically indefinite period.
- `CLAUDE_CODE_RETRY_WATCHDOG=1` keeps unattended sessions waiting through retryable capacity errors. Keep `fallbackModel` unset while the watchdog is on: the watchdog exists to wait for the requested model, while a fallback would silently downgrade the runs it protects.

## Privacy and feature delivery

`DISABLE_TELEMETRY=1` also disables the client that evaluates server-side feature flags, so every gated feature falls back to its default. `CLAUDE_CODE_GB_DISK_CACHE_WHEN_TELEMETRY_OFF=1` restores evaluation from the flag cache already in `~/.claude.json` without re-enabling telemetry. It is undocumented, and it only applies on the first-party route: gateway, Vertex, Bedrock and Foundry sessions keep the defaults regardless. The cache only refreshes in sessions where the client runs, so on a machine that always has telemetry off it stays empty and the variable has nothing to read.

Because that variable restores every cached flag rather than one feature, `syncClaudeAiSkills=false` and `syncClaudeAiPlugins=false` are what keep account-synced skills and plugins out of sessions; without them the flag pulls claude.ai skills into context and the repository-managed registry stops being the only source. One of the gated features is the built-in `agents-md` mod that reads `AGENTS.md` directly, which is why `.claude/CLAUDE.md` keeps its `@../AGENTS.md` import: gateway sessions cannot reach the mod at all.

Keep `CLAUDE_CODE_FORK_SUBAGENT=1` and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` as explicit opt-ins because both workflows are intentionally enabled here. Keep `CLAUDE_CODE_ENABLE_EXPERIMENTAL_ADVISOR_TOOL=1` as the advisor's first-party opt-in: it bypasses the `tengu_sage_compass2` feature flag that `DISABLE_TELEMETRY=1` stops fetching, and relaxes the client-side advisor model-pairing check to the API. Gateway sessions run as the Vertex provider and cannot use the advisor at all.

Do not consolidate the separate privacy controls into `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`; it would also disable automatic updates.

## Auto mode and file protection

- `autoMode.environment` carries the machine-wide trust and sensitivity facts the auto-mode classifier needs, not repo-specific ones: the envchain credential store and its legitimate use, so a credential mention is not read as exploration, and the non-public scope, so delivering task material inside it is not read as egress. The classifier does not read the shared authority rules, so the scope entry restates that scope's predicate instead of naming accounts or services; a destination the predicate excludes stays outside the scope, and the authority rules own the disclosure judgment. Entries use the `**Slot**: value` form, and the list starts with `$defaults` so the built-in entries stay; a custom slot entry sits beside the built-in one of the same name rather than replacing it.
- `autoMode.allow` carries no custom entry: the terminal-state-loss rules did not trigger for local temp-path operations, and an entry could not be shown to change a decision. The built-in soft-deny rules stay in force; add an entry only with a reproducer where the classifier denies without it, keep `$defaults` first so every other built-in rule remains in force, and keep incident nouns, paths, and product names out of any entry.
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

- Keep the Sonnet alias pinned: on the Vertex provider that gateway mode runs as, the built-in `sonnet` alias still resolves to an older generation than first-party. The built-in `opus` alias now matches, so the Opus pin stays only to carry the `[1m]` suffix described below. Pins stop CLI upgrades from advancing either alias, so re-check them whenever a new model generation ships, and keep a pin only while the gateway serves that exact ID.
- `ANTHROPIC_DEFAULT_FABLE_MODEL` and `ANTHROPIC_DEFAULT_OPUS_MODEL` carry the `[1m]` suffix; the Sonnet and Haiku pins do not. The managed env block serves both modes of the `claude` launcher, and in gateway mode Claude Code runs as the Vertex provider, where it budgets a model at 1M without the suffix only when its built-in catalog marks that model natively 1M on Vertex. Sonnet 5 has that mark; Opus 5.5 and Fable 5.1 do not, so without the suffix Vertex sessions, and `model: opus` subagents started from a non-Opus session, fall to 200K and `autoCompactWindow` is capped to that window. On the subscription route the suffix is harmless: the `fable` alias drops it, and Opus 5.5 is natively 1M there and accepts the 1M beta header it adds. Never add it to the Haiku pin, whose 200K model would receive an unsupported beta header. Keep the suffix in the variables rather than at delegation call sites, whose model slots accept only the bare `opus`, `sonnet`, `haiku`, and `fable` aliases.
- `autoCompactWindow` is a compaction threshold, not evidence of the active model's context size. Verify the effective budget from the `context_window.context_window_size` that Claude Code passes to the statusline before changing the model or threshold; the model picker labels 1M only on `[1m]` spellings, so it misses a natively 1M model named without the suffix.
- `precomputeCompactionEnabled=true` builds the compaction summary in the background before the threshold is reached, removing the foreground stall. It defaults to false, so the explicit value is what enables it, and it only applies while auto-compact is on; it must move together with any change that disables auto-compact.
- `dot_claude/scripts/executable_statusline.sh` owns its compact-window parser and denominator calculation. Update and test both when changing `autoCompactWindow` or adding support for another compact override.

## Integrations

- `CLAUDE_CODE_ENABLE_CFC=0` explicitly disables automatic Claude in Chrome wiring; it does not govern the separately permitted `chrome-devtools` MCP tools. Keep the explicit false value because unset restores automatic eligibility.
- Keep `CLAUDE_CODE_DISABLE_CRON=1` with the bare `ScheduleWakeup` deny while local scheduling is retired. The environment variable removes `/loop` and the Cron tools, but the client still registers `ScheduleWakeup` eagerly. Cloud Routines are account-owned and unaffected. Remove the deny only after a cleanly restarted session and a resumed session, both with the environment flag enabled, cannot create, retain, or execute a scheduled wakeup through any exposed scheduling surface.
- `disableClaudeAiConnectors=true` is the source of truth for blocking auto-fetched claude.ai connectors; explicitly configured MCP servers remain available.
- `disableBundledSkills=true` keeps the repository-managed skill registry authoritative. Keep the separate `disableWorkflows` setting unset because `ultracode` depends on dynamic workflows.
- `ENABLE_TOOL_SEARCH=1` forces MCP tool deferral through the custom gateway. Re-test after gateway changes because the gateway must preserve `tool_reference` blocks.
- The `SessionStart` entry registers a hook owned by `herdr integration install claude`; see [Herdr integrations](../../.github/CONCEPTS.md#herdr-integrations). Keep the installer's exact `bash '<absolute path>' session` form, because with the repository's usual `~/.claude/hooks/...` form a reinstall appends a duplicate entry instead of recognizing this one.

## Sandbox

- Treat `excludedCommands` entries as deliberate command shapes, not universal wrapper-aware policies. Matching runs per segment, splitting on `&&`, `||`, `|`, `;`, `&`, and a newline, and the invocation is exempt only when every segment reduces to an excluded command with nothing but its own arguments, apart from a file-descriptor duplication such as `2>&1` and the stripped prefixes named below; a command substitution or heredoc sandboxes the invocation even in an argument position. An inline assignment before the command name, and any other non-exempt command in the call, keeps the whole invocation sandboxed, unless the CLI strips the assignment name as inert (such as `TERM`, `LANG`, or `NODE_ENV`). A bare `env` or `time` prefix is stripped before matching and keeps the exemption, but an `env` prefix whose value is not inert, such as `env PROBE=1`, does not. Git options that select another repository or configuration, such as `-C`, `-c`, `--git-dir`, and `--work-tree`, are rejected by a built-in check before any pattern is compared, so no entry form such as `git *` can exempt them; `git --no-pager` stays exempt. A socket-based tool such as `herdr` then fails with `Operation not permitted` rather than a recognizable permission error, and a `2>/dev/null` hides that message while the call still fails. Do not broaden a matcher without an observed failure.
- Extra write paths are limited to development tool caches and stores, plus `~/.codex`, which sandboxed tools that manage Codex state (e.g. `gh skill update --agent codex --scope user`) write into; codex itself runs excluded and no longer needs it. `~/.oracle` exists for sandboxed parents of oracle such as the skill-validator smoke, whose oracle dry-run chmods `~/.oracle/sessions`; direct `oracle` commands run excluded and never needed it. Sandboxed writes to `~/.codex/config.toml` are a side effect of this entry; the file stays chezmoi-managed, so treat unexplained drift there as suspect. Add a path only after an observed sandbox denial, and do not widen access to a whole home or source tree.
- `denyRead` covers `~/.ssh` as a directory and `allowRead` reopens the same files the hook allows. `allowRead` accepts `*.pub` and `config.*` patterns, so keep the exceptions as patterns rather than key names; re-test pattern support with an isolated `--settings` file, because merged user settings mask a removal. `Read` deny rules also feed the sandbox, so a `Read(~/.ssh/...)` deny would block public keys inside the sandbox as well.
- Keep the rendered `getconf DARWIN_USER_TEMP_DIR` entry in `sandbox.filesystem.allowWrite`: bare macOS `mktemp` resolves that per-user directory, which Claude's built-in allowlist omits. Removing it makes `mktemp` fail with `Operation not permitted`. Re-test only with an isolated `CLAUDE_CONFIG_DIR`, because merged user settings make an in-place removal test false-pass; keep the rendered `T/` path rather than a `/var/folders` ancestor.
- Add allowed domains only after observed sandbox traffic: every entry widens egress for all sandboxed commands, while excluded commands never consult the list. Keep `network.strictAllowlist` unset so a novel host prompts instead of failing deterministically; promote repeatedly approved hosts from runtime-owned state into `allowedDomains`. The setting is OR-merged, so another managed scope can still force strict mode.
- `allowUnixSockets` permits the gpg-agent and keyboxd sockets (private key and public-key lookup) plus the gpg-agent SSH socket. A `git` invocation runs sandboxed whenever the matcher above rejects its segment, so these serve sandboxed `gpg`, `ssh`, and git, including every `git -C` call, git sharing a call with a non-exempt command, and git under a sandboxed parent such as `gh`, `glab`, or a hook script. Without the keyboxd entry a sandboxed `gpg` reports `no keyboxd running in this session` while the daemon is running. `allowLocalBinding=true` emits three seatbelt rules, not one: bind and inbound on any local port, plus outbound to `localhost:*`. Sandboxed clients of a local server therefore depend on this same entry, so do not narrow it to the server side. `com.apple.trustd.agent` supports macOS certificate verification for Go-based CLIs; it is absent from the fixed built-in mach-lookup list, so this explicit entry is the only thing granting it short of `enableWeakerNetworkIsolation`, which the sandbox schema itself labels a security reduction. Add entries only after an observed failure.
- Keep `NODE_USE_ENV_PROXY=1`: the sandbox proxies egress, and Node's `fetch` ignores `HTTPS_PROXY` without it, so a sandboxed Node CLI fails with `fetch failed` even when its host is in `allowedDomains`; the flag is inert when `HTTPS_PROXY` is unset, so excluded commands are unaffected. The context7 skill's `ctx7` calls are the observed case. Remove the flag only after a cleanly restarted session runs a sandboxed Node CLI that uses `fetch` without it and succeeds.

## Worktrees

- `worktree.baseRef` stays unset (default `fresh`), so new worktrees branch from `origin/<default-branch>` instead of carrying local HEAD state.
