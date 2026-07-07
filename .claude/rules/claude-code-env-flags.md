# Claude Code settings.json guardrail

Records only the `dot_claude/settings.json` values a cold reader would misjudge or "fix" and break: parser traps, non-defaults chosen for a reason, and our own decisions. Anything recoverable from the flag name, the [settings docs](https://code.claude.com/docs/en/settings), or a binary grep is deliberately NOT here.

## When to touch this file

- Add an entry only when you set something that reads as a mistake (a value-format trap, a non-default with a reason, a provider/gate dependency) or when you reverse-engineer a new trap. Self-explanatory flags and anything the settings docs cover stay out.
- Re-check or delete an entry after a CC upgrade changes what it records (gate removed, parser flipped, default changed). Verify against the current binary: `rg -a -o '<name>' ~/.local/share/claude/versions/<ver>`; drop it if it no longer holds.
- Record the conclusion and the trap, not the changelog; git history and the docs carry provenance.

## The source is `modify_settings.json`, not a plain file

`dot_claude/modify_settings.json` is a chezmoi modify-template: apply enforces its inline managed JSON (env, permissions, hooks, `skip*` dialog acks, ...) and passes every other key through from the live file. `model`, `effortLevel`, and `ultracode` are runtime-owned (the CLI writes them via /model and /effort; the template only seeds model/effortLevel on a fresh machine), so those keys never show drift and apply never reverts them; a plain source file did exactly that, silently rolling back a /model default. Traps: `chezmoi re-add ~/.claude/settings.json` is a silent no-op on this target; editing the live file only sticks for runtime-owned keys, and a managed-key edit reverts on the next apply: change those via `chezmoi edit ~/.claude/settings.json`, which opens the template. Do not "simplify" it back to a plain source file.

## `DISABLE_TELEMETRY=1` freezes feature gates

It kills the GrowthBook fetch, so gates resolve from the binary's build-time snapshot and server rollouts never reach this install. The per-gate env override still works, making the `env` block our only feature-delivery lever. Three flags are force-on this way (env -> gate): `CLAUDE_CODE_NEW_INIT` (`tengu_slate_harbor_experiment`), `CLAUDE_CODE_FORK_SUBAGENT` (`tengu_copper_fox`), `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (`tengu_amber_flint`). Not the same as the similarly-named `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (see Deliberately absent, below).

## Value formats: a "cleaner" form silently no-ops

- `ENABLE_CLAUDEAI_MCP_SERVERS=0`: falsy parser, `0` is the correct disable value.
- `CLAUDE_CODE_ENABLE_CFC=0`: tri-state (`true`/`false`/unset all distinct); do not normalize.
- `DISABLE_ERROR_REPORTING=1`: any non-empty value disables, so `=0` also disables; never flip to `0` to re-enable.
- `ENABLE_PROMPT_CACHING_1H=1`: the Vertex flag; do not add the bedrock-only `_BEDROCK` sibling.

## Auto mode red lines (`defaultMode: "auto"`)

`CLAUDE_CODE_ENABLE_AUTO_MODE=1` is the eligibility gate (required on Vertex/Bedrock, model-gated). If the classifier throws `<model> is temporarily unavailable ... cannot determine the safety`, the cause is `CLAUDE_CODE_ATTRIBUTION_HEADER=0`, not provider capacity ([#64585](https://github.com/anthropics/claude-code/issues/64585)).

- Bare `Bash` is kept OUT of `permissions.allow` on purpose, so shell routes to the classifier instead of allow-everything; bare `Read`/`Write`/`Edit` stay (cheap file ops).
- Secret protection is split: the `pre-bash-guard-secrets.sh` hook covers Bash only. For Read/Edit/Write the `deny` rules are the ONLY guard, so paths outside them (`.env.production`, `~/.config/gcloud/*`) are readable with no prompt under auto.
- `sessionUrl` must be boolean `false` (CLI checks `=== false`); `""` silently no-ops.

## Model alias pins

`ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` pin what the `opus` / `sonnet` aliases resolve to, so a CLI update can't drift the main or subagent model (the sonnet pin is where CLAUDE.md's `model: "sonnet"` subagents land). On Vertex they also supply the regional ids the refusal-fallback reroute needs.

## `ENABLE_TOOL_SEARCH=1`

Forces MCP tool-schema deferral on a non-first-party gateway (no-op on first-party, which already defers). It only lands if the gateway forwards `tool_reference` blocks; re-confirm tools still defer after a gateway change.

## `worktree.baseRef: "head"`

A new worktree (agent isolation) branches from `origin/<default>` by default; this repo usually has unpushed local commits a `fresh` worktree would miss. `head` branches from local HEAD.

## Internal per-spawn env: never put in `settings.json`

The CLI sets these per child process; your value would override that logic. `CLAUDE_CODE_RESUME_INTERRUPTED_TURN` (globalizing risks false auto-resume on first spawn), `CLAUDE_CODE_SESSION_NAME`, `CLAUDE_BG_*`.

## Deliberately absent: do not (re-)add

- `CLAUDE_CODE_ATTRIBUTION_HEADER=0`: breaks the auto classifier (above); the empty `attribution.commit`/`pr` already hide the footer, so it buys nothing.
- `CLAUDE_CODE_EFFORT_LEVEL`: any value blocks `/effort` for the whole session. Effort is the `effortLevel` key (`low|medium|high|xhigh`) plus `/effort`; `max` and `ultracode` live only in `/effort` (`ultracode` is the boolean `ultracode: true`, not an `effortLevel` value).
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: kills auto-update.
