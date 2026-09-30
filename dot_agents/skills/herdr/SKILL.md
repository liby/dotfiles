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

Control the current Herdr session through the installed `herdr` CLI. Pane commands drive terminals; agent commands bind input and waits to a recognized coding agent.

Load the branch before its first action:

- Before inspecting, starting, or prompting an agent, read the [agent workflow](references/agents.md). For several participants, also read the [panel workflow](references/panels.md) before placing or dispatching the round.
- When Claude Code is the host, read its [runtime section](references/runtimes.md#claude-code-host) before the first Herdr control call. Before launching or sending input to Codex or Pi, read the corresponding section of the same file.
- Before saved-machine discovery or remote control, read the [remote-machine contract](references/remote.md).

## Establish the boundary

Before any control command, verify that this process belongs to Herdr and knows which pane it occupies. Run the check on its own, and issue no Herdr command at all if it fails:

```bash
test "${HERDR_ENV:-}" = 1 && test -n "${HERDR_PANE_ID:-}"
```

If either is missing, say that this process has no caller identity inside Herdr and stop. A missing pane ID is a boundary failure rather than something to work around: `--current` with no caller pane ID resolves through the active context, so it can succeed while answering for whichever window another client has focused. Once both hold, confirm the connection against that pane in a second invocation and keep the workspace, tab, and pane IDs it returns:

```bash
herdr pane current --pane "$HERDR_PANE_ID"
```

If that fails with the environment check satisfied, report its connection or protocol error instead; it does not prove the process is outside Herdr. Do not inspect or control whichever Herdr window another client has focused. If a Codex or Claude subprocess cannot see `HERDR_*`, stop and report the environment boundary; do not edit shell environment policy, install Herdr integrations, or kill a reused daemon as an automatic workaround.

Treat the installed binary as the syntax authority. Inspect only the relevant group before relying on unfamiliar options:

```bash
herdr agent
herdr pane
herdr tab
herdr workspace
```

Never run bare `herdr` for discovery; it launches or attaches the TUI. Do not probe a mutating nested command by omitting required arguments. After a Herdr upgrade or an option rejection, inspect `herdr --version`, the relevant group, and `herdr --skill` for current syntax and capabilities, and keep this skill's authorization, ownership, and workflow rules where the bundled text differs. If the installed version cannot satisfy those rules, report the incompatibility rather than retrying syntax this file happens to show.

Before relying on a new server feature, check `herdr status`; a missing method is not permission to restart or replace the server and its running panes. Never stop the Herdr server or kill its main process without a specific request.

Parse IDs and state from control-command JSON. `pane read` and `agent read` return terminal text, not JSON. Target a pane by the ID a response returned and an agent by its unique live name; `--current` works only on the commands whose help lists it; use each command's documented positional target. Never predict an ID or rely on UI focus or sidebar order.

## Ownership and labels

A returned `create` or `split` ID establishes ownership of that container until the user takes it over, including across later turns. The caller's pane, tab, and workspace are not yours. Read their state when needed; do not close, replace, resize, rearrange, or relabel them without authorization. Prompting an existing agent does not transfer ownership.

Set labels when creating containers. A workspace names the piece of work, a tab the round, and a pane the participant. Keep owned labels aligned with those roles when their purpose changes. A pane's terminal title already follows the agent's activity; its occupant does not rename its pane or live agent to follow a task. The agent name is the stable prompt, wait, and recovery handle.

Read an existing label before changing it and preserve a user-set label or a taken-over container. Herdr has no atomic compare-and-set: when authorization depends on a caller workspace still having its default directory label, a preceding read cannot bind the rename to that label. Obtain authorization for that workspace's new label without that precondition before renaming it. Creation ownership permits renaming your own container; another participant's label change alone does not transfer ownership.

```bash
herdr workspace rename <workspace-id> "<work>"
herdr tab rename <tab-id> "<round>"
herdr pane rename <pane-id> "<participant>"
```

## Place the work

A pane is the participant, a tab is the round, and a workspace is the work's context and lifetime. Default to a sibling pane in the caller's tab and working directory, without taking focus. Inspect the layout first and use the new pane ID from `.result.pane.pane_id`:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Split right while the pane is wide and down when it is narrow or tall. Choose the agent name first, since it must match `[a-z][a-z0-9_-]{0,31}`, then label the new pane for the same participant, because nothing sets that label for you. Passing the agent name keeps the sidebar, the pane title, and your prompts aligned, and since a pane label accepts any text, a more readable label in the user's own language is equally fine.

`pane layout` reports the rectangle every pane in the tab keeps, so you can tell before splitting what both halves would get; budget against every pane in the tab, the user's included, and against the window you actually have rather than a remembered number. Width is what has actually been observed to break: an agent TUI squeezed to around 60 columns is unreadable to the user even though your own reads still succeed, and 80 columns is the usual comfortable floor; both are calibration points, and the user's own answer decides. A tab cannot widen a window that is itself too narrow. Inspect the layout again after creating the pane, since the split you got may not be the one you predicted. When a round does not fit in one tab, run it in batches or give it another tab, and say which you chose; when even an unsplit pane stays unreadable, report the capacity limit and what you could not start.

Create a container when the work's purpose or lifetime no longer matches where you were called, not because the current tab has filled. One helper stays a sibling pane. A round with several participants gets its own tab: it lays the round out across the full window width, keeps the caller's pane clean, and lets the round be switched to and closed as one. Stay in the caller's tab only when it already holds that round's panes, as when a later batch of the same round joins the earlier one. Pass the caller's workspace, an explicit `--cwd`, `--no-focus`, and a label saying what the round is; split from the root pane its response returns, not from `--current`, which still points at the caller's original tab.

When the work should be navigated and managed on its own, or its context is not the caller's workspace, create a workspace with an explicit `--label`: the default label follows the current directory, so different workspaces can otherwise share one name.

```bash
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "<round>" --no-focus
herdr workspace create --cwd "$PWD" --label "<work>" --no-focus
```

A named session is a separate server with its own workspaces, sockets, and persisted runtime state, not a security or filesystem boundary; reach for one only when the work needs that server-level isolation, the user has asked for or authorized it, and you have verified a control path that can address that server. Persistence is not the trigger: tabs and workspaces already survive in this server, and a long or recurring investigation stays a workspace.

Do not move work into a different working directory or worktree unless the user asks for that topology.

## Run and read a pane command

For a shell command that does not need agent lifecycle, pass its text as one literal argument: shell substitutions and `$?` must be evaluated in the target pane, not by the controller's shell. Run it, wait with a finite timeout, and read:

```bash
herdr pane run <pane-id> '<command>'
herdr pane wait-output <pane-id> --match "<fresh expected text>" --timeout <milliseconds>
herdr pane read <pane-id> --source recent-unwrapped --lines 120
```

`wait-output` searches existing output immediately, and the command you sent is itself on screen, so match something the submitted text cannot contain: a marker the command assembles while running, or a result it prints afterwards together with its exit status. A literal you typed into the command is already on screen and matches its own echo however unique it is, which ends the wait before anything has run.

Choose the read source for the task: `recent-unwrapped` for logs and transcripts, `visible` for interactive prompts, `recent` for recent rendered output. An agent TUI indents its own output, and that margin reaches every text source, so a pattern anchored at the start of a line can miss what it is looking for; `recent-unwrapped` additionally joins soft-wrapped rows, which removes the row boundaries a greedy extraction pattern relies on to stop. A larger read can also collect an idle agent's application-owned history, so treat the alternate screen as hard to reach only when that read still returns no older output. When a larger read still cannot recover the complete response, ask the agent to write it as Markdown under this task's own directory in runtime-provided temporary space and reply with the path; do not make file output the default protocol, and on hosts that cannot share that directory read the file on the same machine.

## Close what you opened

This covers the helpers you started for your own work, not a process the user asked you to leave running. Close a pane when this task created it, its current occupant is still the helper you put there, you have collected what you needed, and nothing pending remains for it. Decide this yourself; do not ask the user whether to keep a helper alive.

```bash
herdr pane close <pane-id>
herdr tab close <tab-id>
herdr workspace close <workspace-id>
```

Starting a helper inside a pane the user already had does not make that pane yours, and once the user takes a session over it stops being yours to close. Keep a helper whose work you still need, whose output you have not read, or that holds an open question for the user, and name in your answer which ones you kept and why; a `blocked` state is a dialog to resolve or report, not a reason to keep anything, and a turn that has become pointless is not work worth protecting. Closing a tab shuts down the panes inside it, so close a tab you created only after every pane still in it is one you could close on its own; if the user has put something there, leave the tab. A container is not finished when its helpers are: collecting their output does not mean the tab or workspace you created has served its purpose. Close it only when that purpose is complete; leave it and say what you left when the user has taken it over or it is part of the work you are handing back. A workspace linked to a worktree refuses to close with `workspace_group_close_required`; leave it rather than adding `--group` to close more than you created. When you cannot establish that a pane is yours, leave it and say so.
