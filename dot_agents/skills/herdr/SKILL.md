---
description: Control Herdr, a terminal multiplexer for coding agents. Use only when the user explicitly mentions Herdr or asks to use Herdr to inspect or control panes, tabs, workspaces, commands, or another agent. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work. Requires HERDR_ENV=1.
allowed-tools:
  - Bash(herdr:*)
  - Bash(test:*)
  - Read
license: Apache-2.0
metadata:
    github-path: skills/herdr
    github-pinned: v0.9.1
    github-ref: refs/tags/v0.9.1
    github-repo: https://github.com/herdrdev/herdr
    github-tree-sha: 6985a5e8418d43171c45c2a9e04b02de7308e1d8
name: herdr
---

Control the current Herdr session through the installed `herdr` CLI. Pane commands control raw terminals; agent commands control the lifecycle state of a recognized coding agent.

## Establish the boundary

Before any control command, verify that this process belongs to Herdr:

```bash
test "${HERDR_ENV:-}" = 1 && herdr pane current --current
```

If `HERDR_ENV` is not `1`, say that this process is outside Herdr and stop. If `pane current` fails with the environment check satisfied, report its connection or protocol error instead; it does not prove the process is outside Herdr. Do not inspect or control whichever Herdr window another client has focused.

Do not close or replace workspaces, tabs, panes, agents, or sessions you did not create unless the user explicitly requests it. Never stop the Herdr server or kill its main process without a specific request. If a Codex or Claude subprocess cannot see `HERDR_*`, stop and report the environment boundary; do not edit shell environment policy, install Herdr integrations, or kill a reused daemon as an automatic workaround.

Treat the installed binary as the syntax authority. Inspect only the relevant group before relying on unfamiliar options:

```bash
herdr agent
herdr pane
```

Never run bare `herdr` for discovery; it launches or attaches the TUI. Do not probe a mutating nested command by omitting required arguments. After a Herdr upgrade or an option rejection, inspect `herdr --version`, the relevant group, and `herdr --skill` for current syntax; follow this skill where they differ.

An upgraded client can keep using an older server. Before relying on a new server feature, check `herdr status`; a missing method is not permission to restart or replace the server and its running panes.

Parse IDs and state from control-command JSON. `pane read` and `agent read` return terminal text, not JSON. Use `--current`, an explicit pane ID, or a unique live agent name; never predict an ID or rely on UI focus or sidebar order.

## Control a pane

Default to a sibling pane in the current tab and the caller's working directory. Do not create a workspace, tab, worktree, or different cwd unless the user asks for that topology. Inspect the current layout, split without stealing focus, and read the new pane ID from `.result.pane.pane_id`:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Use `down` instead when the layout is narrow.

For a shell command that does not need agent lifecycle, run, wait with a finite timeout, and read:

```bash
herdr pane run <returned-pane-id> "<command>"
herdr pane wait-output <returned-pane-id> --match "<fresh expected text>" --timeout <milliseconds>
herdr pane read <returned-pane-id> --source recent-unwrapped --lines 120
```

`wait-output` searches existing output immediately. Match fresh task-specific text or an observable result, not a generic `DONE` that an earlier turn or the prompt echo could satisfy.

Choose the read source for the task: `recent-unwrapped` for logs and transcripts, `visible` for interactive prompts, `recent` for recent rendered output. A larger read can also collect an idle agent's application-owned history, so treat the alternate screen as hard to reach only when that read still returns no older output. When a larger read still cannot recover the complete response, ask the agent to write it as Markdown in a runtime-provided temporary directory and reply with the path; do not make file output the default protocol, and on hosts that cannot share that directory read the file on the same machine.

## Run an agent

Inspect the live agents before creating or prompting one:

```bash
herdr agent list
```

Reuse a settled live agent only when its role and context match the new task and continuity is useful. Never prompt an agent already classified as `working`: its current turn can finish and incorrectly satisfy the new wait. Treat `unknown` as unresolved, not complete.

Give agents stable role names matching `[a-z][a-z0-9_-]{0,31}`. Add a short mnemonic suffix when several agents share a role, and rename the pane to the same human-readable label. Address agents by name after creation instead of passing pane IDs between prompts.

Read-only helpers may share the current checkout. Do not let concurrent writers edit the same checkout. Keep extra agents read-only or sequential unless the user asks for isolated worktrees.

`agent start` requires an existing pane at an interactive shell prompt. Start the kind requested by the user and pass native arguments only after `--`:

```bash
herdr pane rename <returned-pane-id> <agent-name>
herdr agent start <agent-name> --kind <kind> --pane <returned-pane-id> -- <agent-args...>
```

A successful `agent start` returns only after Herdr detects the expected agent and considers it ready for input. If startup is blocked, it returns `agent_not_ready` but keeps the name available. Either way, read `visible` before prompting: a startup prompt can still be on screen while Herdr already reports `idle` and `interactive_ready`.

A prompt inside another agent belongs to the user, with one exception: in an agent you started, a prompt that only asks whether to trust its working directory or the hooks already present there. Answer that one with `pane send-keys`: move to the option that grants trust, because the preselected one can be a review or decline step, then confirm. Everything else waits for the user, including login, model selection, and any approval or question the agent raises about the task.

Submit a self-contained task with a finite timeout:

```bash
herdr agent prompt <agent-name> "<task>" --wait --timeout <milliseconds>
```

`--wait` settles on `idle`, `done`, or `blocked`; do not narrow it to `--until done`. A wait tracks lifecycle state, not an individual turn or a successful result. A timeout ends only the wait and does not prove the agent is still working; before waiting again, read the pane to judge whether a turn is still live. After every wait, read the response to your prompt: confirm the outcome you asked for, and check for a question or a stated inability to proceed. Never blindly resend the prompt or press Enter when submission is ambiguous.

```bash
herdr agent get <agent-name>
herdr agent read <agent-name> --source recent-unwrapped --lines 120
```

Raise `--lines` as needed to reach the complete response, including any questions or blockers. The read has a row cap, so a long turn can push earlier output out of reach; when a larger read returns no older output and the response is still incomplete, use the file fallback under Control a pane. On `blocked`, timeout, `agent_prompt_stalled`, or unexpected output, inspect `agent get` and read `visible` before deciding whether a follow-up is safe.

## Pi

Herdr takes a Pi pane's status from the lifecycle hook, not the screen (`screen_detection_skip_reason: full_lifecycle_hook_authority`), so the reported turn state can be stale.

Use each layer for what it owns:

- When starting Pi with an explicit model, pass `--provider <provider> --model <exact-model-id>`, using the provider paired with that model in Pi's configured model list. Do not rely on `defaultProvider`: explicit `--model` resolution can select an unauthenticated built-in provider with the same model ID. Start Pi directly and let the selected provider resolve its own credentials; do not synthesize or remap credential environment variables.
- Submit a task through `agent prompt` like any other agent.
- Send slash commands with `pane run` and read `visible` to confirm the effect; `agent prompt` waits observe lifecycle state, which a slash command never changes.
- Stop a running turn with `herdr agent send-keys <agent-name> esc`. Pi documents Escape as the abort, not Ctrl+C, which clears the editor.

When the hook's report and the pane disagree, decide from the pane:

- A stall does not prove non-delivery, and `agent get` can report `working` after the pane has returned to its prompt. Read `visible`; if no turn is live, re-prompt a bounded task rather than waiting again.
- Use `pane send-text` followed by `send-keys enter` only when the visible state confirms that Pi did not receive the task; confirm receipt afterward.
- If interactive delivery remains unreliable for a long task, run `pi -p @<file>` through `pane run` and wait for a unique completion marker.
- A persistent mismatch is a Herdr Pi-integration defect: report it instead of repairing the integration.
