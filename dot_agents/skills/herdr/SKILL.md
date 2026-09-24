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

Where the host sandbox exempts `herdr` by command name, as Claude Code does, give a control command the shell invocation to itself: keep every command in it an exempt one, split at shell separators such as `|`, `&&`, `;`, and a newline, and put nothing else in the call but those commands' own arguments and a file-descriptor duplication such as `2>&1`; a command substitution or heredoc sandboxes it even inside an argument. An inline assignment before the command name sandboxes the call, unless the name is one the CLI treats as inert, such as `TERM` or `LANG`. A sandboxed socket call then fails with `Operation not permitted` rather than a recognizable permission error, and a `2>/dev/null` hides that message while the call still fails.

## Establish the boundary

Before any control command, verify that this process belongs to Herdr and knows which pane it occupies. Run the check on its own, and issue no Herdr command at all if it fails:

```bash
test "${HERDR_ENV:-}" = 1 && test -n "${HERDR_PANE_ID:-}"
```

If either is missing, say that this process has no caller identity inside Herdr and stop. A missing pane ID is a boundary failure rather than something to work around: `--current` with no caller pane ID resolves through the active context, so it can succeed while answering for whichever window another client has focused. Once both hold, confirm the connection against that pane in a second invocation and keep the workspace, tab, and pane IDs it returns:

```bash
herdr pane current --pane "$HERDR_PANE_ID"
```

If that fails with the environment check satisfied, report its connection or protocol error instead; it does not prove the process is outside Herdr. Do not inspect or control whichever Herdr window another client has focused.

Anything you did not create belongs to the user: read it when the task needs its state, and do not close, replace, relabel, resize, or rearrange it unless the user asks. Prompting an existing agent is ordinary use of it, not a change of ownership. What you created stays yours to name, drive, and close for as long as the task runs, across later turns as well. Never stop the Herdr server or kill its main process without a specific request. If a Codex or Claude subprocess cannot see `HERDR_*`, stop and report the environment boundary; do not edit shell environment policy, install Herdr integrations, or kill a reused daemon as an automatic workaround.

Treat the installed binary as the syntax authority. Inspect only the relevant group before relying on unfamiliar options:

```bash
herdr agent
herdr pane
herdr tab
herdr workspace
```

Never run bare `herdr` for discovery; it launches or attaches the TUI. Do not probe a mutating nested command by omitting required arguments. After a Herdr upgrade or an option rejection, inspect `herdr --version`, the relevant group, and `herdr --skill` for current syntax and capabilities, and keep this skill's authorization, ownership, and workflow rules where the bundled text differs. If the installed version cannot satisfy those rules, report the incompatibility rather than retrying syntax this file happens to show.

An upgraded client can keep using an older server. Before relying on a new server feature, check `herdr status`; a missing method is not permission to restart or replace the server and its running panes.

Parse IDs and state from control-command JSON. `pane read` and `agent read` return terminal text, not JSON. Target a pane by the ID a response returned and an agent by its unique live name; `--current` works only on the commands whose help lists it, and the read, run, and wait commands take the pane ID as a positional argument. Never predict an ID or rely on UI focus or sidebar order.

## Place the work

A pane is one participant or terminal process. A tab groups panes the user should view together, usually one round or phase of the work. A workspace is the context and lifetime boundary the user navigates by, holding one piece of work and all of its rounds.

Default to the nearest place: a sibling pane in the caller's tab, in the caller's working directory, without taking focus. Inspect the layout first and read the new pane ID from `.result.pane.pane_id`:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Split right while the pane is wide and down when it is narrow or tall. Choose the agent name first, since it must match `[a-z][a-z0-9_-]{0,31}`, then label the pane yourself for the same participant, because nothing sets that label for you. Passing the agent name keeps the sidebar, the pane title, and your prompts aligned, and since a pane label accepts any text, a more readable label in the user's own language is equally fine:

```bash
herdr pane rename <returned-pane-id> <label>
```

Create a container when the work's purpose or lifetime no longer matches where you were called, not because the current tab has filled. One helper stays a sibling pane. A round with several participants gets its own tab: it lays the round out across the full window width, keeps the caller's pane clean, and lets the round be switched to and closed as one. Stay in the caller's tab only when it already holds that round's panes, as when a later batch of the same round joins the earlier one. Pass the caller's workspace, an explicit `--cwd`, `--no-focus`, and a label saying what the round is; split from the root pane its response returns, not from `--current`, which still points at the caller's original tab.

When the work should be navigated and managed on its own, or its context is not the caller's workspace, create a workspace with an explicit `--label`: the default label follows the current directory, so different workspaces can otherwise share one name.

A named session is a separate server with its own workspaces, sockets, and persisted runtime state, not a security or filesystem boundary; reach for one only when the work needs that server-level isolation, the user has asked for or authorized it, and you have verified a control path that can address that server. Persistence is not the trigger: tabs and workspaces already survive in this server, and a long or recurring investigation stays a workspace.

```bash
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "<round>" --no-focus
herdr workspace create --cwd "$PWD" --label "<work>" --no-focus
```

Only the pane's terminal title follows the agent on its own, through the agent's OSC title; a tab and a workspace keep the label they were created or last renamed with, and a workspace label defaults to its working directory. Whenever the task behind a container or participant changes, rename that level yourself, even when the current name is a default, the agent's own terminal title, or a name you or another participant set earlier, so the sidebar and window title keep naming the current work, and keep the agent name aligned with the pane label:

```bash
herdr workspace rename <workspace-id> "<work>"
herdr tab rename <tab-id> "<round>"
herdr pane rename <pane-id> "<participant>"
```

`pane layout` reports the rectangle every pane in the tab keeps, so you can tell before splitting what both halves would get; budget against every pane in the tab, the user's included, and against the window you actually have rather than a remembered number. Width is what has actually been observed to break: an agent TUI squeezed to around 60 columns is unreadable to the user even though your own reads still succeed, and 80 columns is the usual comfortable floor; both are calibration points, and the user's own answer decides. A tab cannot widen a window that is itself too narrow. Inspect the layout again after creating the pane, since the split you got may not be the one you predicted. When a round does not fit in one tab, run it in batches or give it another tab, and say which you chose; when even an unsplit pane stays unreadable, report the capacity limit and what you could not start.

Do not move work into a different working directory or worktree unless the user asks for that topology.

## Name what you own

There is no dispatcher role in Herdr, so refusing to rename because you are "not the main dispatcher" is the wrong test. Ownership is creation: you own a workspace, tab, or pane only when a `create` or `split` you ran returned its ID. The pane you occupy and the tab and workspace you were called from are not yours, whoever started you. Rename only what you own, and only while the user has not taken it over.

- A workspace label names the piece of work it holds. Its creator renames it when that work changes, including on a later turn; a round inside a workspace is not a workspace rename.
- A tab label names the round. Its creator renames it when the round's purpose changes; a new round gets a new tab rather than a seized label.
- A pane label names the participant. Its creator sets it at creation and may correct it when the pane is repurposed. An occupant never renames the pane it sits in: the pane's terminal title already tracks what its agent is doing, so leave activity to that field, do not copy the task into the pane label, and never rename a live agent to follow a task, because the agent name is the handle your prompts, waits, and resume commands use.

Another participant changing a label you own does not transfer ownership, so you may correct it; a name the user set, or a container the user has taken over, stays. Read the label with `herdr workspace get`, `herdr tab get`, or `herdr pane get` before renaming and leave it if it changed against you, since Herdr has no atomic compare-and-set. Report a stale label on a container you do not own instead of renaming it.

```bash
herdr workspace rename <workspace-id> "<work>"
herdr tab rename <tab-id> "<round>"
herdr pane rename <pane-id> "<participant>"
```

## Run a command in a pane

For a shell command that does not need agent lifecycle, run it, wait with a finite timeout, and read:

```bash
herdr pane run <pane-id> "<command>"
herdr pane wait-output <pane-id> --match "<fresh expected text>" --timeout <milliseconds>
herdr pane read <pane-id> --source recent-unwrapped --lines 120
```

`wait-output` searches existing output immediately, and the command you sent is itself on screen, so match something the submitted text cannot contain: a marker the command assembles while running, or a result it prints afterwards together with its exit status. A literal you typed into the command is already on screen and matches its own echo however unique it is, which ends the wait before anything has run.

Choose the read source for the task: `recent-unwrapped` for logs and transcripts, `visible` for interactive prompts, `recent` for recent rendered output. An agent TUI indents its own output, and that margin reaches every text source, so a pattern anchored at the start of a line can miss what it is looking for; `recent-unwrapped` additionally joins soft-wrapped rows, which removes the row boundaries a greedy extraction pattern relies on to stop. A larger read can also collect an idle agent's application-owned history, so treat the alternate screen as hard to reach only when that read still returns no older output. When a larger read still cannot recover the complete response, ask the agent to write it as Markdown under this task's own directory in runtime-provided temporary space and reply with the path; do not make file output the default protocol, and on hosts that cannot share that directory read the file on the same machine.

## Start and drive an agent

Inspect the live agents before creating or prompting one:

```bash
herdr agent list
```

`agent list` is how you find a free name, not how you find an agent to reuse: names are unique only among live agents and are released when one exits, so a name that was yours can now belong to another instance. Reuse a settled live agent only when the user asked to continue that instance, or this task started it, and in either case its role and context still match; a call for a new participant needs a fresh agent. Never prompt an agent already classified as `working`: its current turn can finish and incorrectly satisfy the new wait. Treat `unknown` as unresolved, not complete.

Name an agent for its role plus whatever separates it from its siblings, which is the model when several models share a role and the target when several instances share a model. Start each participant you were asked to create in a newly created pane.

Helpers that only read may share the current checkout; concurrent writers may not. Limit extra agents to reading, or run writers one at a time, unless the user asks for isolated worktrees, and state that limit in the task text: it is a constraint on what the helper does, not a sandbox setting.

`agent start` requires an existing pane at an interactive shell prompt. Start the kind the user asked for, and pass native arguments such as the model only after `--`:

```bash
herdr agent start <agent-name> --kind <kind> --pane <returned-pane-id> -- <agent-args...>
```

Start Codex on the profile its `default_permissions` setting selects, and pass no `-s` / `--sandbox` value unless the user names a sandbox mode for this launch. The flag does not narrow that profile: it selects Codex's older sandbox settings in its place, and a managed `allowed_permission_profiles` requirement alone keeps the profile, so if the user asks for a read-only launch, say that under that requirement the flag cannot remove the profile's write access. Where the flag takes effect, `-s read-only` turns off the network the configured profile keeps enabled; the launch that prompted this rule failed with `Could not resolve host`.

A successful `agent start` returns only after Herdr detects the expected agent and considers it ready for input. If startup is blocked, it returns `agent_not_ready` but keeps the name available. Either way, read `visible` before prompting: a startup prompt can still be on screen while Herdr already reports `idle` and `interactive_ready`.

Submit a self-contained task with a finite timeout, passing it as one literal argument. Task text and quoted findings routinely contain backticks and `$(...)`, which your own shell expands inside double quotes before Herdr ever sees the argument, so keep the task in single quotes:

```bash
herdr agent prompt <agent-name> '<task>' --wait --timeout <milliseconds>
```

When the text itself contains quotes, write it to a file under this task's own directory and prompt the agent to read that path, which keeps the shell out of it entirely.

`--wait` settles on `idle`, `done`, or `blocked`; do not narrow it to `--until done`, and keep it whenever you pass `--timeout`, which requires it. A wait tracks lifecycle state, not an individual turn or a successful result. A timeout ends only the wait and does not prove the agent is still working. After every wait, read the response to your prompt and check for a question or a stated inability to proceed. Never blindly resend the prompt or press Enter when submission is ambiguous.

```bash
herdr agent get <agent-name>
herdr agent read <agent-name> --source recent-unwrapped --lines 120
```

Raise `--lines` as needed to reach the complete response, including any questions or blockers. The read has a row cap, so a long turn can push earlier output out of reach; when a larger read returns no older output and the response is still incomplete, use the file fallback under Run a command in a pane. On `agent_blocked`, `blocked`, timeout, `agent_prompt_stalled`, or unexpected output, inspect `agent get` and read `visible` before deciding whether a follow-up is safe.

## Answer a dialog inside an agent you started

A dialog blocks the agent it appears in and everything waiting on that agent, so leaving one on screen costs the whole round. A dialog inside an agent you did not start belongs to the user. Inside one you started, `agent prompt` refuses with `agent_blocked` instead of sending input, which is usually how you find out. Read `visible` before pressing anything, and identify both the option you intend and the one currently selected. `visible` returns the viewport, so raising `--lines` cannot bring an option that is off screen into view; use the dialog's own non-submitting navigation and read again. If you still cannot see the full option list, do not press a confirmation key.

Answer it yourself when the option you mean to choose is recoverable, the answer does not need the user personally, and answering stays inside what the user authorized for this task. Judge recoverability by the action the option lets through rather than by the keypress: approving a command inside a helper inherits that command's consequences, and that helper's permission boundary is the user's configuration, not budget for you to spend. Wait when the option you would choose is irreversible, when only the user holds the answer, or when answering would claim authority the task never granted. A question is not the user's merely because the dialog phrases it as one: answer a model prompt from the ID the user named or the one configuration pairs with it, and wait only when a materially different choice is still open and the task did not delegate it.

Two cases recur. A prompt asking whether to trust the working directory or the hooks already present there is subject to the same test rather than exempt from it: accepting it lets the repository's hooks run with the user's permissions, so accept when the trust decision for that checkout is already settled within the task's authority, and otherwise read what those hooks do before choosing. Reading files in a checkout is not by itself authorization to execute hooks a branch introduced. When you do accept, move to the option that grants trust, because the preselected one can be a review or decline step, then confirm. An agent's own onboarding or configuration offer, such as `Teach auto mode about your environment?`, is yours to decline with whichever option defers it, never with the variant that writes a setting on the user's behalf; read which key that is rather than assuming Escape. After any keypress, read again: a startup sequence can raise a second dialog, and one keystroke is not proof the agent reached a usable prompt.

```bash
herdr agent send-keys <agent-name> down enter
herdr agent send-keys <agent-name> esc
```

When you do wait, name the blocked agent and pane and quote the dialog with its options, and let the participants that are not blocked keep working.

## Run a panel of models

Use a pane for a participant that needs a different agent binary, a different model vendor, a session the user can watch and take over, or simply because the user asked for one. Where your own runtime offers in-process subagents they cost no pane and no screen space, which makes them the cheaper choice for the rest; panes are the supported mechanism when no such equivalent exists.

The user names participants by model nickname. Pass the exact model ID the user gave, or the one the runtime's own configuration pairs with that nickname, and never invent one: an alias that the runtime resolves natively can be passed through as it stands, and a nickname you cannot resolve from configuration is worth one question rather than a guess.

One round asks one question. Write the brief once and give every participant the same one, including the context they cannot see, because a fresh agent has neither your conversation nor the other participants' answers.

Start a fresh agent for each participant rather than reusing one that has been reading around the repository, confirm that the fresh start did not resume an earlier conversation, and give simultaneous rounds distinct agent names, since a name collision with another lead's round is not permission to reuse that agent. Keep the other participants' answers out of the brief and out of the working directory until the comparison step, and write the round's own outputs under a directory belonging to this round; remove only the files you put there, never a shared temporary root another round may still be using. Because a participant can go looking on its own, the brief itself has to say not to read the other participants' panes, sessions, or verdicts before comparison. Exposure to another verdict does not guarantee copying, but agreement after it is not independent confirmation, so when you find that a participant saw one, say which result is affected rather than counting it. Fix the inputs before dispatching and leave them alone until the round ends: the files as they stand, or a named base plus the complete uncommitted diff. Editing the checkout mid-round, which is tempting while early answers arrive, means the later participants reviewed something else and their verdicts cannot be pooled with the earlier ones. Ask for a written verdict in the pane and name what you want compared; reserve the file fallback for a response you could not read back.

Dispatch the whole batch before collecting any of it. `agent prompt --wait` blocks until that one agent settles, so issuing the prompts one after another turns a panel into a queue, and a dialog in the first participant stalls participants that were never prompted. Where your host runs tool calls concurrently, issue the waiting prompts together. Otherwise prompt without `--wait`, confirm from each pane that the task arrived, and collect afterwards with `herdr agent wait <agent-name> --timeout <milliseconds>`, which bounds the wait the same way without resubmitting anything; an `idle` state proves nothing about a task that was never delivered.

Attribute each finding to the model that produced it, and report agreement and disagreement separately. A second model repeating a claim is not evidence that the claim is true: check it against the source before carrying it into your own answer. When the round is a discussion rather than a poll, quote the other positions verbatim in the follow-up prompt, since the participants share no context.

## Finish the round before you yield

Nothing resumes you. Your host runs you only while you keep emitting tool calls, and once your turn ends only a new user message starts it again; Herdr has no message that reaches another agent, and its notifications reach the human, never this conversation. So "I'll summarize when they finish" or "I'll watch it" leaves the round stalled until the user notices.

A round is done only when every participant you prompted is accounted for: for each, wait on a finite timeout, then read its answer to this prompt and judge it, counting a question, blocker, or stated failure as part of your answer. A settled state is not a result, and for a prompt sent without `--wait` confirm delivery first, because `idle` proves nothing about a task that never arrived. When a wait times out, the wait ended and the work did not: read the pane, and if a live turn is on screen, wait again in this turn, keeping the re-waits bounded. Where a reported state disagrees with the pane, the pane decides; on Pi the hook can stay `working` after the answer is on screen (see Pi).

Yield with work outstanding only when the user asked to leave it running, only the user can answer a dialog, or the host will not accept another wait. Then say that only a new user message resumes the round, and for each unfinished participant give its agent name, pane ID, and last observed state, the containers you own, and the exact `herdr agent wait <agent-name> --timeout <milliseconds>` and `herdr agent read <agent-name>` commands. `herdr notification show` can alert the human before such a yield; it cannot wake you.

## Close what you opened

This covers the helpers you started for your own work, not a process the user asked you to leave running. Close a pane when this task created it, its current occupant is still the helper you put there, you have collected what you needed, and nothing pending remains for it. Decide this yourself; do not ask the user whether to keep a helper alive.

```bash
herdr pane close <pane-id>
herdr tab close <tab-id>
herdr workspace close <workspace-id>
```

Starting a helper inside a pane the user already had does not make that pane yours, and once the user takes a session over it stops being yours to close. Keep a helper whose work you still need, whose output you have not read, or that holds an open question for the user, and name in your answer which ones you kept and why; a `blocked` state is a dialog to resolve or report, not a reason to keep anything, and a turn that has become pointless is not work worth protecting. Closing a tab shuts down the panes inside it, so close a tab you created only after every pane still in it is one you could close on its own; if the user has put something there, leave the tab. A container is not finished when its helpers are: collecting their output does not mean the tab or workspace you created has served its purpose. Close it only when that purpose is complete; leave it and say what you left when the user has taken it over or it is part of the work you are handing back. A workspace linked to a worktree refuses to close with `workspace_group_close_required`; leave it rather than adding `--group` to close more than you created. When you cannot establish that a pane is yours, leave it and say so.

## Pi

Herdr takes a Pi pane's status from the lifecycle hook, not the screen (`screen_detection_skip_reason: full_lifecycle_hook_authority`), so the reported turn state can be stale.

Use each layer for what it owns:

- When starting Pi with an explicit model, pass `--provider <provider> --model <exact-model-id>`, using the provider paired with that model in Pi's configured model list. Do not rely on `defaultProvider`: explicit `--model` resolution can select an unauthenticated built-in provider with the same model ID. Start Pi directly and let the selected provider resolve its own credentials; do not synthesize or remap credential environment variables.
- Send slash commands with `pane run` and read `visible` to confirm the effect, since a command that only changes the editor or the session leaves lifecycle state untouched and an `agent prompt` wait would never settle on it.
- Stop a running turn with `herdr agent send-keys <agent-name> esc`, which is Pi's documented abort in its default bindings; Ctrl+C clears the editor instead.

When the hook's report and the pane disagree, decide from the pane:

- A stall does not prove non-delivery, and `agent get` can report `working` after the pane has returned to its prompt. Read `visible` and reconcile what you sent against what the pane shows: an idle pane can mean the task finished as easily as it can mean the task never arrived. Collect the result if the turn completed, resend only once non-delivery is established or repeating the task is harmless, and otherwise report the ambiguity rather than replaying work.
- Use `pane send-text` followed by `send-keys enter` only when the visible state confirms that Pi did not receive the task; confirm receipt afterward.
- If interactive delivery stays unreliable for a long task, fall back to print mode, but only from a pane at a real shell prompt: `pane run` types into whatever holds the foreground, which in the agent's own pane is the Pi editor, so split a pane for it rather than reusing that one. Establish first that the interactive turn is no longer running, keep the provider, exact model, and full task from the original invocation, and check the exit status as well as the output.
- A persistent disagreement between the hook's report and the pane is worth reporting with the versions and what you observed; do not repair the integration yourself, and do not name a cause you have not isolated.
