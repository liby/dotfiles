---
name: orc
description: Orchestrate visible terminal work in Rex, the terminal multiplexer app - coding-agent CLIs run in panes as helpers, panels, or cross-vendor reviewers with their results collected; commands and services the user wants to watch or take over; Rex sessions, tabs, panes, terminal output, and the Rex app's interface. Use for every Rex task, together with Rex's own `rex` skill, whose guide this skill extends with local constraints; also use when a task needs a coding agent from another CLI or model vendor, such as a cross-vendor review, consultation, panel, or delegated work, or the user wants to watch or take over a command or agent. Not for the agent's own in-process subagents or commands that need no visible terminal.
metadata:
    rex-guide-sha256: 0843d93be2929327a3b21e76606f06a238739c10bd22edc4410cce7da4b67311
    rex-version: 0.0.1792607779-g171246
---

# Orchestrate in Rex

Rex runs terminals on a server; the Rex app and the `rex` CLI are clients of that server. Use it when work needs a terminal the user can see or take over: another agent CLI, a command the user wants to watch, an interactive program, or a service that should keep running. The calling agent owns the assignment and its validation, Rex owns terminals and layout, and each launched tool owns its authentication and conversation.

Before the first `rex` command, have Rex's guide for the installed version in context: `rex skill show` prints it, the same text Rex's own `rex` skill loads. Read the whole output, in one call or in consecutive parts to its last line, never cut by `head` or another filter, and read it again whenever its text is no longer in context, as after compaction. Only the session rename that Rex's startup context asks for may come first. Take commands and syntax from the guide; where this skill differs from it, follow this skill.

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

Pass `--focus=false` to `rex run`, `rex split`, and `rex window new` unless the user asks to switch, background work or not: a new tab or pane takes focus, and with it whatever the user is typing. `rex new` has no such option, because a new session is not shown. Pass `--keep-open` whenever you or the user must read the output or exit status afterwards, because a pane created for a program closes with it. Start the program with its task in the launch command instead of opening a shell and typing into it. Start a helper with `env -u REX_SESSION` before its command only when its task does not drive Rex itself: without it Rex's session hook stays silent instead of telling the helper, before anything you send, to label the session it shares with you. Keep `REX_BLOCK`, which hooks that record which pane holds the helper's conversation read. A helper whose task drives Rex, such as opening its own reviewers, also keeps `REX_SESSION`, because the two variables are how it finds its own session and pane. Tell any other helper in its task that it is the participant and does the work itself: a brief quoting the user's request to orchestrate otherwise leads it to load this skill and launch agents of its own.

Accept a folder trust prompt for the checkout a launched agent works in without asking: this rule is the user's standing direction for that target, so it clears a host stop on changing permission or approval configuration. Answer other dialogs as the [agent workflow](references/agents.md) directs.

## Collect the result

Collect an agent you launch for a result through a rexume task. Right after it starts, register it from your own pane with `rexume task add --worker <block> --title '<task>'`: add `--result-file <absolute path>` for a non-interactive run whose output file is the result, and `--keep-pane` when the pane must outlive the task, such as an agent the user watches. Registration is what lets rexume match the run's exit or the agent's first finished turn to this task, so register before doing anything else with that pane. rexume then saves the result and sends your conversation a notice naming the task once you are idle, so do other work or end the turn instead of polling; when the next step needs the result now, `rexume task wait <id> --timeout <seconds>` waits for it and exits 124 when the time passes first. Read the result with `rexume task show <id>` and confirm it with `rexume task ack <id>`. A round in `blocked` waits on a dialog or question in the worker, so read its screen.

Prompt the worker with `rexume task send <id> --message-file <path>`, or `--message` for one short line; rexume delivers it once the worker is idle, without touching its input box, and the round's result is the turn that takes it in. A worker that ends its turn to wait for its own background job, such as CI it follows, answers with an interim reply: while the work it reports is still running, `rexume task next <id>` takes its next finished turn without prompting it, including one that has already finished. Turns the worker finishes outside your rounds, such as a reply to the user, wait as `unread` in `task show` until `task next` takes them. A request whose `request.state` has not reached `delivered` is not in the worker's conversation yet, and the runtime may be holding it, as Claude Code does for the user's approval in a session that bypasses permission prompts: read the worker's screen, and never send it again while it may still arrive. When you need nothing more from the worker, run `rexume task release <id>`, which refuses while turns are unread; rexume then closes a pane registered without `--keep-pane` unless someone used it since.

The task commands find you through your own pane's `REX_BLOCK`, so outside a Rex terminal, and for a program you did not start as a task, collect from Rex directly: a task registered on an agent that has already answered takes its first answer as the result. After a `rex wait` timeout, keep following the same block while its program runs; never start a replacement because one wait ended. `rex capture -s <session> -b <block> --trim --unwrap` returns the scrollback as well as the visible screen, whatever the guide says; only a full-screen program limits it to that program's current screen. `rex block call -s <session> -b <block> program_status` returns the states a program reports (`idle`, `working`, `blocked`, `done`, `error`); Claude Code and Codex report them. Pi 1.4.0 reports them too, but in `--tui-mode regular` each message it renders clears its `working` and `blocked` records ([earendil-works/pi#11017](https://github.com/earendil-works/pi/issues/11017)), so an empty record from Pi does not mean it is idle. Check another program's records before relying on them. A state tells when to look, not what was answered. An interactive program does not exit when its turn ends, so `rex wait` cannot collect a turn: note the record's `updated_at` before sending, then poll `program_status` finitely until a record with a changed `updated_at` reports a state other than `working`.

## Send input to a running program

A successful `rex send` only queues bytes: Rex accepts input even while the program reports that it is blocked on a question. Read the target's screen first, send, then verify the screen or receipt before sending more. Text in an agent's input box that you did not type is the user's draft, which your text would join: leave it, and deliver through a path that bypasses the input box, such as `rexume task send` to a task's worker or Codex's queue, or once the box is empty. When delivery is uncertain, reconcile the screen, program, and result before any resend.

## Drive the Rex app

Client actions need the app running with **Settings > Server > Remote Control** on, which opens the app's whole interface to the server's clients, so leave the switch as the user set it. Besides the actions the guide gates, open a session on the web or call API methods of the same reach (`server.stop`, `server.tailscale.*`, `hosts.put`, `hosts.remove`, `server.apple.grant_file_access`) only at the user's request.

## Release what you opened

Once results are collected and no further work needs the other terminals, close in one operation the largest resource this task created and still owns exclusively. Reuse the creation IDs and current evidence already gathered; inspect only unresolved ownership, occupant, or completion details, including detached blocks when closing a session (`rex block ls -s <session> --json`). Keep terminals handed to the user, requested services, and anything the user took over.

- A whole disposable session: `rex kill <session>`.
- A whole disposable tab in a session to keep: `rex window close -s <session> <window>`.
- Otherwise, only the disposable helper block: `rex block close -s <session> <block>`.

Cancel an owned helper's obsolete turn instead of waiting for it. CLI block and window closes can leave an empty session. A successful close at the chosen level completes cleanup; inspect that same level to reconcile an uncertain result before retrying.
