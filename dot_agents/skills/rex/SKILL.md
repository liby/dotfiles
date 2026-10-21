---
name: rex
description: Control Rex, the terminal multiplexer app, through the `rex` CLI - sessions, tabs, and panes; commands, services, and coding-agent CLIs run in visible panes with their results collected; terminal output; and the Rex app's own interface. Use when the user mentions Rex or its sessions, tabs, or panes, or when a task needs a coding agent from another CLI or model vendor, such as a cross-vendor review, consultation, panel, or delegated work, or the user wants to watch or take over a command or agent. Not for the agent's own in-process subagents or commands that need no visible terminal.
metadata:
    rex-guide-sha256: e2a96ec2a1597b2961a2bce1239fa401990abac30fc5c8de64d110355f140f96
    rex-version: 0.0.1792519967-gd05acf
---

# Rex

Rex runs terminals on a server; the Rex app and the `rex` CLI are clients of that server. Use it when work needs a terminal the user can see or take over: another agent CLI, a command the user wants to watch, an interactive program, or a service that should keep running. The calling agent owns the assignment and its validation, Rex owns terminals and layout, and each launched tool owns its authentication and conversation.

Programs in Rex terminals run with the user's full permissions, outside the calling agent's sandbox and approval checks. Never use Rex to run a command that the host's sandbox or approval would refuse, or to avoid asking, unless the user asked for that command in Rex; otherwise take the host's own escalation path.

Load each reference before its first action:

- Before starting, prompting, or collecting from another coding agent, read the [agent workflow](references/agents.md); for several participants on one question, also its [panel section](references/agents.md#run-a-panel).
- When Claude Code is the host, read its [runtime section](references/runtimes.md#claude-code-host) before the first `rex` call. Before launching or sending input to Claude Code, Codex, or Pi, read its section of that file.

## Find the target

The CLI calls a tab a window and a pane a block; a session holds the work of one project or task. Use `rex help <command>` for syntax, and `rex api list` with `rex api describe <method> --json` for what the CLI lacks, such as floating layers, detached blocks, resizing, and event streams. Options from tmux don't apply, and a command that help lists may answer that it is not implemented; use its API method then. `rex skill show` prints Rex's general guide for features this skill does not cover.

Inside a Rex terminal, `REX_SESSION` and `REX_BLOCK` identify where this agent runs, not what the user is viewing. "Here", "beside you", or no location means those IDs; "the focused pane" or "the current tab" means the `focused_block_id` of the window that `active_window_id` names in `rex session inspect <session> --json`; a named session, tab, or pane wins over both. Inherited IDs are unchecked: `rex whoami --json` reports the connection, and its `session_id` and `block_id` only while those IDs still resolve; it cannot find the pane itself, so when they are missing, treat this agent as outside a Rex terminal.

Outside a Rex terminal, such as in another terminal app or a desktop agent app, there is no caller pane. Use the session the request names (`rex ls --json`), ask when several match, and otherwise create one labelled for the task. The user sees that work only in the Rex app, because `rex attach` elsewhere only views output and does not forward keys: report the session's label, or show it with `session.select` from [Drive the Rex app](#drive-the-rex-app) when the user asks.

Retain the full IDs that `--json` returns (`.session_id`, `.block_ids[0]`, `.window_id`) and target them, not labels or ID suffixes, which can match several resources or a replacement. Pass `-s <session>` with every window or block ID: without it Rex looks only in the session `REX_SESSION` names and reports an ID from another session as not found. Inspect with `--autostart=false` so that probing for an absent server does not start one. Never stop or restart the server or Rex processes unless the user asks: several Rex versions can run at once, and stopping the server ends every session.

## Label and place work

Label by purpose: session = the work, tab = the round, pane = the participant. Open a round's tab together with its first program, `rex window new -s <session> <round> --keep-open -- <command>`, and split the other participants beside the block it returns. Label a pane with `--label '<participant>'` on `rex run` or `rex split`, or with `rex block rename -s <session> <block> '<participant>'`. An agent participant's label names its runtime and model, and its role when siblings share them, such as `Pi DeepSeek reviewer`, so the user can tell panes apart without remembering their launch order. When the first request identifies the work, replace a generated or generic session label with two to four lowercase hyphenated words, and keep a label that already describes it. Rename a label of a resource you work in or created once it no longer matches its work, unless the user has taken that resource over.

Put one helper in a pane beside the caller, in the same tab and working directory; give a multi-participant round its own tab. Budget every pane, the user's included, against the window's actual width: around 60 columns has proved unreadable to the user and 80 is the usual floor, so use batches or another tab when a round cannot fit, and say so.

## Launch

Put Rex options before `--` and the program and its arguments after it as separate words. The command is not parsed by a shell, so wrap pipes or `&&` in `sh -c '...'`. Set `--cwd`. New tabs and panes take focus, and with it whatever the user is typing, so pass `--focus=false` unless the user asks to switch; `rex new` creates a session without showing it. `rex run -s <session>` opens a tab unless given `--split`, and `rex split -s <session> -b <block>` places a pane beside that block.

A pane created for a program closes when the program exits and takes its output with it; Rex keeps one open only after a quick failure. Pass `--keep-open` whenever output or exit status must be read afterwards. Start the program with its task in the launch command instead of opening a shell and typing into it, and dispatch independent jobs before waiting on any of them.

## Collect the result

`rex wait -s <session> <block> --for <duration>` exits with the program's status, or 1 on timeout, so a timeout says nothing about the outcome; `rex block call -s <session> -b <block> process` reports `last_exit` once the program has ended. After a timeout, keep following the same block while its program runs; never start a replacement because one wait ended.

`rex capture -s <session> -b <block> --trim --unwrap` includes scrollback, not only the visible screen, but a full-screen program shows only its own current screen: `rex block call ... modes` reports `"screen": "alternate"` while one runs. `rex block call ... program_status` returns the states a program reports (`idle`, `working`, `blocked`, `done`, `error`); Claude Code, Codex, and Pi report them; check another program's records before relying on them. A state tells when to look, not what was answered. An interactive program does not exit when its turn ends, so `rex wait` cannot collect a turn: note the record's `updated_at` before sending, then poll `program_status` finitely until `updated_at` has changed and the state no longer reads `working`.

A Rex notification alerts the user; it cannot wake this agent to collect a result later.

## Send input to a running program

`rex send` types text into whatever program currently owns the block and does not press Return; follow it with `rex send-key ... enter`. Letter key names are case-insensitive, so use `shift+g` or `send` for capitals. A successful send only queues bytes: Rex accepts input even while the program reports that it is blocked on a question. Read the target's screen first, send, then verify the screen or receipt before sending more, and never type into this agent's own pane. When delivery is uncertain, reconcile the screen, program, and result before any resend.

## Drive the Rex app

Client actions operate the Rex app's interface: which session and tab it shows, layout, focus, keys, font size, theme, sidebar, and palette, but also windows, updates, device pairing, remote hosts, and opening a session on the web. They need the app running with **Settings > Server > Remote Control** on, which opens that whole surface to the server's clients, so leave the switch as the user set it. `rex client ls` lists clients, `rex -C <client> actions` lists what that app offers (`-C` goes before the subcommand), and `rex -C <client> do session.select session_id=<id>` shows a session. A title ending in `…` opens a dialog that needs a response in the app. Arrange panes with the server commands above, which take explicit IDs, not client actions such as `pane.split`, which act on whatever the app has focused.

Run client actions that close windows, install updates, pair devices, change hosts, or open a session on the web, and API methods of the same reach (`server.stop`, `server.tailscale.*`, `hosts.put`, `hosts.remove`, `server.apple.grant_file_access`), only at the user's request.

## Release what you opened

Close a disposable helper's block with `rex block close -s <session> <block>` once its result is collected, its occupant is still that helper, and nothing remains pending; cancel an owned helper's obsolete turn instead of waiting for it. Close a tab or session only when everything in it is finished and task-created. Keep terminals handed to the user, requested services, and anything the user took over, and remove task temporary files.
