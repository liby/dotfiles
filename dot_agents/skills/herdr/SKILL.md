---
description: Control Herdr, a terminal multiplexer for coding agents. Use only when the user explicitly mentions Herdr or asks to use Herdr to inspect or control panes, tabs, workspaces, commands, or another agent. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work. Requires HERDR_ENV=1.
allowed-tools:
  - Bash(herdr:*)
  - Bash(pi --list-models:*)
  - Bash(test:*)
  - Read
license: Apache-2.0
metadata:
    github-path: skills/herdr
    github-pinned: v0.9.3
    github-ref: refs/tags/v0.9.3
    github-repo: https://github.com/herdrdev/herdr
    github-tree-sha: 67042ed7910d4177a9000e0679e78b0346060927
name: herdr
---

Control the current Herdr session with the installed CLI. Pane commands drive terminals; agent commands bind input and waits to a recognized agent.

Load each branch before its first action, and again before acting on it whenever its text is no longer in your context, as after compaction:

- Before inspecting, starting, or prompting an agent, read the [agent workflow](references/agents.md); for several participants, also read the [panel workflow](references/panels.md) before placing or dispatching the round.
- When Claude Code is the host, read its [runtime section](references/runtimes.md#claude-code-host) before the first control call. Before launching or sending input to Codex or Pi, read its section of that file.
- Before saved-machine discovery or remote control, read the [remote-machine contract](references/remote.md).

Deliver input to a Codex agent you drive by its state, even when notes or summaries from earlier in the session prescribe typing into its pane: answer a pending question card (`? N question · shift+← to answer`) inside the card when the task authorizes that answer, send input for a `working` agent on this machine through `codex queue`, and prompt an idle one with `agent prompt`. Typing into its main composer and pressing Enter instead deletes a pending card and steers the running turn.

## Establish the boundary

Run this check alone before any Herdr command; if it fails, report the missing process boundary and stop:

```bash
test "${HERDR_ENV:-}" = 1 && test -n "${HERDR_PANE_ID:-}"
```

A missing caller ID must not fall through to another client's active context. If the gate passes, resolve the inherited ID in a separate invocation and retain the returned workspace, tab, and pane IDs:

```bash
herdr pane current --pane "$HERDR_PANE_ID"
```

If that lookup fails, report its error and stop the actions that depend on the caller; focus, `--current`, labels, and other agents' identities cannot stand in for it. Work that needs no caller pane still proceeds, such as creating a requested workspace with an explicit cwd. Report connection or protocol errors as such; the CLI enforces protocol compatibility. Never change endpoints, overwrite `HERDR_*`, or restart the server to recover. Missing subprocess environment is a boundary to report, not authorization to change environment policy or install integrations.

Use the installed binary for syntax; inspect the relevant group before unfamiliar options:

```bash
herdr agent
herdr pane
herdr tab
herdr workspace
```

Never run bare `herdr` for discovery: it launches or attaches the TUI. Bare `herdr server` is not a usage probe either: it runs a headless server. Do not probe a mutating nested command by omitting arguments. After an upgrade or option rejection, inspect `herdr --version`, the relevant group, and `herdr --skill`; retain this skill's authorization, ownership, and workflow rules. Report an incompatibility when the installed version cannot satisfy them. Before relying on a new server feature, check `herdr status`; never stop or replace the server or kill its main process without a specific request.

Control responses contain JSON IDs and state; `pane read` and `agent read` contain terminal text. Use returned pane IDs and verified unique live agent names, not inherited IDs, predicted IDs, focus, or sidebar order. Never use `--current` while the caller is unresolved.

## Ownership and labels

A returned `create` or `split` ID establishes task ownership across turns until user takeover. The caller's containers are not yours: do not close, replace, resize, rearrange, or relabel them without authorization. Inspecting or prompting an existing agent does not transfer ownership.

Label on creation: workspace = work, tab = round, pane = participant. Update owned labels when their purpose changes; preserve user-set labels and taken-over containers. Keep the live agent name stable for prompting, waiting, and recovery; its occupant's activity already updates the terminal title. Read a label before changing it. A label change does not transfer ownership.

```bash
herdr workspace rename <workspace-id> "<work>"
herdr tab rename <tab-id> "<round>"
herdr pane rename <pane-id> "<participant>"
```

## Place the work

With a resolved caller, put one helper in a sibling pane in the same tab and cwd. Inspect the layout, split without focus, and retain `.result.pane.pane_id`:

```bash
herdr pane layout --pane <caller-pane-id>
herdr pane split <caller-pane-id> --direction right --cwd "$PWD" --no-focus
```

Choose the agent name first (`[a-z][a-z0-9_-]{0,31}`), then explicitly label its pane for that participant; readable labels may use the user's language. Split right when wide, down when narrow or tall. Budget every pane, including the user's, against the actual layout, and inspect again after splitting. Around 60 columns has proved unreadable to the user; 80 is a usual comfortable floor, subject to the user's judgment. Use batches or another tab when the round cannot fit, and state that choice. A tab cannot widen the window: if even an unsplit pane is unreadable, report the capacity limit and what could not start.

Place work by purpose and lifetime. Give a multi-participant round its own tab; reuse the caller's tab only if it already holds that round. Pass the verified workspace, explicit cwd, label, and `--no-focus`, then split from the returned root pane. Create a labeled workspace when the work needs its own navigation/lifetime or a different context; the default directory label cannot distinguish separate tasks in the same cwd.

```bash
herdr tab create --workspace <caller-workspace-id> --cwd "$PWD" --label "<round>" --no-focus
herdr workspace create --cwd "$PWD" --label "<work>" --no-focus
```

A named session is a separate server with its own sockets and persisted state, not a security or filesystem boundary. Use one only for needed, authorized server isolation with a verified control path; long-lived work already persists in a workspace. Do not change cwd or introduce a worktree unless the user asks for that topology.

## Run and read a pane command

Pass a shell command as one literal argument so substitutions and `$?` evaluate in the target pane:

```bash
herdr pane run <pane-id> '<command>'
herdr pane wait-output <pane-id> --match "<fresh expected text>" --timeout <milliseconds>
herdr pane read <pane-id> --source recent-unwrapped --lines 120
```

`wait-output` searches existing output immediately, including the submitted command's echo. Match a marker assembled at runtime or actual result text with exit status that the submitted text cannot contain; a unique literal in that text can match before execution.

Use `visible` for dialogs, `recent-unwrapped` for transcripts/logs, and `recent` for rendered output. TUI margins can defeat start-of-line patterns; unwrapping joins rows and can defeat extraction boundaries. Increase `--lines` to recover complete output; supported idle agents can also expose application-owned alternate-screen history through a larger `recent` or `recent-unwrapped` read. On `agent_not_idle`, wait for the turn to settle and retry that read. Only if the larger idle read still cannot reach it, ask the agent to write Markdown under this task's own directory in runtime-provided temporary space and return the path. This is a recovery protocol, not the default; read the file on its host when the directory is not shared.

## Close what you opened

Close a helper yourself when this task created its container, its occupant is still that helper, you have collected what is still needed, and nothing pending remains. Cancel an owned helper's obsolete turn when its result is no longer needed; do not wait for that result merely to close it. Do not ask whether to retain a disposable helper. Preserve user-requested running processes, taken-over containers, unread required results, and open user questions; resolve or report `blocked` rather than treating that state alone as a reason to retain it.

```bash
herdr pane close <pane-id>
herdr tab close <tab-id>
herdr workspace close <workspace-id>
```

Close a tab/workspace only when its own purpose is complete and every contained pane is independently eligible for closure. Collected helper results do not finish a workspace being handed back. Leave containers with user additions or uncertain ownership, and report what remains and why. On `workspace_group_close_required`, leave it; do not add `--group` and close more than you created.
