---
name: orc
description: Orchestrate visible terminal work in Rex, the terminal multiplexer app - coding-agent CLIs run in panes as helpers, panels, or cross-vendor reviewers with their results collected; commands and services the user wants to watch or take over; Rex sessions, tabs, panes, terminal output, and the Rex app's interface. Use for every Rex task, together with Rex's own `rex` skill, whose guide this skill extends with local constraints; also use when a task needs a coding agent from another CLI or model vendor, such as a cross-vendor review, consultation, panel, or delegated work, or the user wants to watch or take over a command or agent. Not for the agent's own in-process subagents or commands that need no visible terminal.
metadata:
    rex-guide-sha256: 0843d93be2929327a3b21e76606f06a238739c10bd22edc4410cce7da4b67311
    rex-version: 0.0.1792607779-g171246
---

# Orchestrate in Rex

Rex runs terminals on a server; the Rex app and the `rex` CLI are clients of that server. Use it when work needs a terminal the user can see or take over: another agent CLI, a command the user wants to watch, an interactive program, or a service that should keep running. The calling agent owns the assignment and its validation, Rex owns terminals and layout, and each launched tool owns its authentication and conversation.

Before the first `rex` command, have Rex's guide for the installed version in context: `rex skill show` prints it, the same text Rex's own `rex` skill loads. Read the whole output, in one call or in consecutive parts to its last line, never cut by `head` or another filter, and read it again, with any reference below you loaded, whenever its text is no longer in context, as after compaction. Only the session rename that Rex's startup context asks for may come first. Take commands and syntax from the guide; where this skill differs from it, follow this skill.

Programs in Rex terminals run with the user's full permissions, outside the calling agent's sandbox and approval checks. Never use Rex to run a command that the host's sandbox or approval would refuse, or to avoid asking, unless the user asked for that command in Rex; otherwise take the host's own escalation path.

Load each reference before its first action:

- Before starting, prompting, or collecting from another coding agent, read the [agent workflow](references/agents.md); for several participants on one question, also its [panel section](references/agents.md#run-a-panel).
- When Claude Code is the host, read its [runtime section](references/runtimes.md#claude-code-host) before the first `rex` call. Before launching or sending input to Claude Code, Codex, or Pi, read its section of that file.

## Find the target

`rex whoami --json` reports `session_id` and `block_id` only while the inherited IDs still resolve and cannot find the pane itself, so when they are missing, treat this agent as outside a Rex terminal. There, with no named or matching session, create one labelled for the task; the user sees that work only in the Rex app, so report the session's label, and show it with `session.select` only when the user asks.

Pass `-s <session>` with every window or block ID: without it Rex looks only in the session `REX_SESSION` names and reports an ID from another session as not found. Inspect with `--autostart=false` so that probing for an absent server does not start one.

## Label and place work

What your commands create belongs to this task until the user takes it over. Nothing else does, including the caller's tab and panes, the original pane that `rex split` also returns, and agents you only inspected or prompted: leave them unclosed and unmoved, and change their size only by splitting beside them, unless the user asks.

Label by purpose: session = the work, tab = the round, pane = the participant. Open a round's tab together with its first program, `rex window new -s <session> <round> --focus=false --keep-open -- <command>`, and split the other participants beside the block it returns. Label a pane with `--label '<participant>'` on `rex run` or `rex split`, or with `rex block rename -s <session> <block> '<participant>'`; `rex window new` has no `--label`, and the name of the pane it opens labels the tab. An agent participant's label names its runtime and model, and its role when siblings share them, such as `Pi DeepSeek reviewer`, so the user can tell panes apart without remembering their launch order. Rename a tab or pane label you work in or created once it no longer matches its work, unless the user has taken that resource over.

Put one helper in a pane beside the caller, in the same tab and working directory; give a multi-participant round its own tab. Budget every pane, the user's included, against the window's actual width: around 60 columns has proved unreadable to the user and 80 is the usual floor, so use batches or another tab when a round cannot fit, and say so.

## Launch

Pass `--focus=false` to `rex run`, `rex split`, and `rex window new` unless the user asks to switch, background work or not: a new tab or pane takes focus, and with it whatever the user is typing. `rex new` has no such option, because a new session is not shown. Pass `--keep-open` whenever you or the user must read the output or exit status afterwards, because a pane created for a program closes with it. Start the program with its task in the launch command instead of opening a shell and typing into it.

## Collect the result

After a `rex wait` timeout, keep following the same block while its program runs; never start a replacement because one wait ended.

`rex capture -s <session> -b <block> --trim --unwrap` returns the scrollback as well as the visible screen, whatever the guide says; only a full-screen program limits it to that program's current screen. `rex block call -s <session> -b <block> program_status` returns the states a program reports (`idle`, `working`, `blocked`, `done`, `error`); Claude Code, Codex, and Pi report them; check another program's records before relying on them. A state tells when to look, not what was answered. An interactive program does not exit when its turn ends, so `rex wait` cannot collect a turn: note the record's `updated_at` before sending, then poll `program_status` finitely until `updated_at` has changed and the state no longer reads `working`.

A Rex notification alerts the user; it cannot wake this agent to collect a result later.

## Send input to a running program

A successful `rex send` only queues bytes: Rex accepts input even while the program reports that it is blocked on a question. Read the target's screen first, send, then verify the screen or receipt before sending more. When delivery is uncertain, reconcile the screen, program, and result before any resend.

## Drive the Rex app

Client actions need the app running with **Settings > Server > Remote Control** on, which opens the app's whole interface to the server's clients, so leave the switch as the user set it. Besides the actions the guide gates, open a session on the web or call API methods of the same reach (`server.stop`, `server.tailscale.*`, `hosts.put`, `hosts.remove`, `server.apple.grant_file_access`) only at the user's request.

## Release what you opened

Close a disposable helper's block with `rex block close -s <session> <block>` once its result is collected, its occupant is still that helper, and nothing remains pending; cancel an owned helper's obsolete turn instead of waiting for it. Close a tab or session only when everything in it is finished and task-created. Keep terminals handed to the user, requested services, and anything the user took over.
