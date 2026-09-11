---
description: Control Herdr, a terminal multiplexer for coding agents. Use only when the user explicitly mentions Herdr or asks to use Herdr to inspect or control panes, tabs, workspaces, commands, or another agent. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work. Requires HERDR_ENV=1.
allowed-tools:
  - Bash(herdr:*)
  - Bash(test:*)
  - Read
license: Apache-2.0
metadata:
    github-path: skills/herdr
    github-pinned: v0.9.0
    github-ref: refs/tags/v0.9.0
    github-repo: https://github.com/herdrdev/herdr
    github-tree-sha: b9dcfddcfa7ce43e2e4cf60e724c519be553f149
name: herdr
---
# Herdr

Control the current Herdr session through the installed `herdr` CLI. Use pane commands for raw terminals and agent commands for recognized coding-agent lifecycle state.

## Establish the boundary

Before any control command, verify that this process belongs to Herdr:

```bash
test "${HERDR_ENV:-}" = 1 && herdr pane current --current
```

If `HERDR_ENV` is not `1`, say that this process is outside Herdr and stop. If `pane current` fails with the environment check satisfied, report its connection or protocol error instead; it does not prove the process is outside Herdr. Do not inspect or control whichever Herdr window another client has focused.

Treat the installed binary as the syntax authority. Inspect only the relevant group before relying on unfamiliar options:

```bash
herdr agent
herdr pane
```

Never run bare `herdr` for discovery; it launches or attaches the TUI. Do not probe a mutating nested command by omitting required arguments. After a Herdr upgrade or an option rejection, inspect `herdr --version`, the relevant group, and `herdr --skill`; treat the latter as a release-matched upstream reference, not permission to overwrite this local policy.

An upgraded client can keep using an older server. Before relying on a new server feature, check `herdr status`; a missing method is not permission to restart or replace the server and its running panes.

Parse IDs and state from control-command JSON. `pane read` and `agent read` return terminal text, not JSON. Use `--current`, an explicit pane ID, or a unique live agent name; never predict an ID or rely on UI focus or sidebar order.

## Coordinate an agent

Inspect the live agents before creating or prompting one:

```bash
herdr agent list
```

Reuse a settled live agent only when its role and context match the new task and continuity is useful. Never prompt an agent already classified as `working`: its current turn can finish and incorrectly satisfy the new wait. Treat `unknown` as unresolved, not complete.

Give agents stable role names matching `[a-z][a-z0-9_-]{0,31}`. Add a short mnemonic suffix when several agents share a role, and rename the pane to the same human-readable label. Address agents by name after creation instead of passing pane IDs between prompts.

Default to a sibling pane in the current tab and the caller's working directory. Do not create a workspace, tab, worktree, or different cwd unless the user asks for that topology. Inspect the current layout, split without stealing focus, and read the new pane ID from `.result.pane.pane_id`:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Use `down` instead when the layout is narrow. `agent start` requires an existing pane at an interactive shell prompt. Start the kind requested by the user and pass native arguments only after `--`:

```bash
herdr pane rename <returned-pane-id> <agent-name>
herdr agent start <agent-name> --kind <kind> --pane <returned-pane-id> -- <agent-args...>
```

When starting Pi with an explicit model, pass `--provider <provider> --model <exact-model-id>` using the provider paired with that model in Pi's configured model list. Do not rely on `defaultProvider`: explicit `--model` resolution can select an unauthenticated built-in provider with the same model ID. Start Pi directly and let the selected provider resolve its own credentials; do not synthesize or remap credential environment variables.

A successful `agent start` returns only after Herdr detects the expected agent and considers it ready for input. If startup is blocked, it returns `agent_not_ready` but keeps the name available. Either way, read `visible` before prompting: a startup prompt can still be on screen while Herdr already reports `idle` and `interactive_ready`.

A prompt inside another agent belongs to the user, with one exception: in an agent you started, a prompt that only asks whether to trust its working directory or the hooks already present there. Answer that one with `pane send-keys`: move to the option that grants trust, because the preselected one can be a review or decline step, then confirm. Everything else waits for the user, including login, model selection, and any approval or question raised during a turn.

Submit a self-contained task with a finite timeout:

```bash
herdr agent prompt <agent-name> "<task>" --wait --timeout <milliseconds>
```

Normal `--wait` already settles on `idle`, `done`, or `blocked`; do not narrow it to `--until done`. Waits observe screen-derived lifecycle, not a turn receipt. After every wait, inspect the returned state and read the result. Never blindly resend the prompt or press Enter when submission is ambiguous.

```bash
herdr agent get <agent-name>
herdr agent read <agent-name> --source recent-unwrapped --lines 120
```

On `blocked`, timeout, `agent_prompt_stalled`, or unexpected output, inspect `agent get` and read `visible` before deciding whether a follow-up is safe.

Read-only helpers may share the current checkout. Do not let concurrent writers edit the same checkout. Keep extra agents read-only or sequential unless the user asks for isolated worktrees.

## Pi agent delivery

- Send slash commands with `pane run` and read `visible` to confirm the effect; `agent prompt` waits observe lifecycle state, which a slash command never changes.
- Submit Pi tasks through `agent prompt` like other agents. A stall does not prove non-delivery. Use `pane send-text` followed by `send-keys enter` only when the visible state confirms that Pi did not receive the task; confirm receipt afterward. If interactive delivery remains unreliable for a long task, run `pi -p @<file>` through `pane run` and wait for a unique completion marker.

## Run an ordinary command in another pane

Use pane commands for a shell command that does not need agent lifecycle. Split as above, then run, wait with a finite timeout, and read:

```bash
herdr pane run <returned-pane-id> "<command>"
herdr pane wait-output <returned-pane-id> --match "<fresh expected text>" --timeout <milliseconds>
herdr pane read <returned-pane-id> --source recent-unwrapped --lines 120
```

`wait-output` searches existing output immediately. Match fresh task-specific text or an observable result, not a generic `DONE` that an earlier turn or the prompt echo could satisfy.

## Recover and clean up

Prefer `recent-unwrapped` for logs and transcripts and `visible` for interactive prompts. If increasing `--lines` still cannot recover a completed response, the agent is probably using the terminal alternate screen. Only then ask it to write the complete response as Markdown in a runtime-provided temporary directory and reply with the path; do not make file output the default protocol.

If a Codex or Claude subprocess cannot see `HERDR_*`, stop and report the environment boundary. Do not edit shell environment policy, install Herdr integrations, or kill a reused daemon as an automatic workaround.

Do not close or replace workspaces, tabs, panes, agents, or sessions you did not create unless the user explicitly requests it. Never stop the Herdr server or kill its main process without a specific request.
