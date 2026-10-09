# Herdr agent workflow

## Start and drive an agent

Inspect live agents before creating or prompting one:

```bash
herdr agent list
```

Names are unique only while live and may belong to a replacement after exit. Reuse a settled instance only when the user asked to continue it or this task started it, and its role/context still match; a new participant needs a new pane and agent. Name it for role plus model or target when those distinguish siblings. Treat `unknown` as unresolved. For a busy Codex next-turn message, use its [native queue](runtimes.md#codex); otherwise wait for the current turn before prompting. `agent prompt --wait` on a working agent can settle on the old turn.

Read-only helpers may share a checkout; serialize writers unless the user asks for isolated worktrees. Run commands that authenticate as the user through a credential-store read or a browser sign-in in one process at a time, across yourself and every helper: each such process can raise its own approval or sign-in prompt, and parallel runs stack them on the user. State both constraints in the helpers' tasks; they are not sandbox settings.

### Resolve the runtime and model

`--kind` selects a program, not a model. Use the runtime the user names; otherwise prefer the model vendor's installed agent when it offers the model, then another installed runtime whose usable-model listing includes it. For Pi, inspect `pi --list-models <search>`. If no route works, report those checked and ask; one missing model-named CLI does not exhaust the routes.

Use the exact user-given ID, the single ID that configuration or the usable listing pairs with the user's name, or a native alias. If the requested name remains unresolved or ambiguous after those checks, ask one question rather than guessing. Let the runtime obtain its normal credentials without synthesizing or remapping environment variables.

### Launch

Use a returned pane at an interactive shell prompt. Put native arguments after `--`. For Pi, take both provider and model from the same usable-list row and pass both explicitly: a default provider does not prevent model-only resolution to an unauthenticated built-in provider.

```bash
herdr agent start <agent-name> --kind <kind> --pane <returned-pane-id> -- <agent-args...>
herdr agent start <agent-name> --kind pi --pane <returned-pane-id> -- --provider <listed-provider> --model <listed-model-id>
```

Startup success means Herdr detected readiness; `agent_not_ready` leaves the name available. Either way, read `visible` before prompting: a dialog may still be present at `idle`/`interactive_ready`. Handle it under the dialog contract below.

## Answer a dialog inside an agent you started

A dialog in someone else's agent belongs to the user. In your helper, `agent prompt` refuses with `agent_blocked`. A question the agent's own model raises is such a dialog; a [Codex question card](runtimes.md#answer-a-question-card) shows no options until opened. Read `visible`, identify the intended and selected options, and navigate without submitting until the whole option list is visible; increasing `--lines` cannot expand a viewport. Never confirm unseen options.

Answer only within the task's authorization, with no uncleared stop under Authority and no answer only the user holds. Without shared rules, require an undoable action visible only to the user, or specific user direction clearing the otherwise-stopped effect. Judge the action enabled, not the keypress; do not spend a helper's permission boundary. Resolve a model choice from the requested/configured ID; ask only for an undelegated material choice.

Trusting a checkout or its hooks changes what may execute without asking: require authorization covering that checkout's hooks; reading files does not authorize new branch hooks. Move to the actual trust option before confirming. Decline optional onboarding/configuration such as `Teach auto mode about your environment?` with its visible defer option, not a settings-writing option or an assumed Escape binding. Re-read after each key because another dialog may follow.

```bash
herdr agent send-keys <agent-name> down enter
herdr agent send-keys <agent-name> esc
```

When user input is required, report the agent, pane, and exact dialog/options while unblocked participants continue.

## Complete the requested outcome

Choose delivery-only or required results before submitting. Deliver to an idle agent through `agent prompt`, using one literal argument; single quotes keep backticks and `$(...)` out of the controller shell. If quoting or the [host runtime](runtimes.md) prevents inline text, place the full task in a task-owned file and send a path. Never paste another task into a busy editor; typed delivery is reserved for runtime-specific recovery.

```bash
herdr agent prompt <agent-name> '<task>' --wait --timeout <milliseconds>
```

For parallel work, omit `--wait`, confirm delivery from the pane, and dispatch the batch before collecting. A synchronous prompt uses `--wait --timeout`; `--timeout` requires `--wait`, which settles on `idle`, `done`, or `blocked`, so do not narrow it to `--until done`.

```bash
herdr agent wait <agent-name> --timeout <milliseconds>
herdr agent get <agent-name>
herdr agent read <agent-name> --source recent-unwrapped --lines 120
```

After each wait, read this prompt's complete answer, including questions, blockers, and stated failures. Lifecycle state is neither a turn receipt nor a verdict. On timeout, `blocked`, `agent_prompt_stalled`, or unexpected output, inspect `get` and `visible` before another input. Reconcile ambiguous submission; never blindly resend or press Enter. Recover unreadable output through the root's [read/file fallback](../SKILL.md#run-and-read-a-pane-command).

- Delivery-only finishes at the intended session's acceptance of the exact message, reported as delivered/queued, not processed. Finish any readiness wait and submission now; this does not cancel an earlier obligation to collect results.
- Required results finish only after every required participant's actual response or blocker is collected and judged. After timeout, read and keep waiting finitely in this turn while the live task continues; neither timeout nor a host-cut wait establishes a stall. Reconcile state against the pane; Pi's [hook can remain working after completion](runtimes.md#pi).

Herdr notifications reach the human, not this conversation. Ending the turn does not schedule collection: only a new user message resumes it, except when the host re-invokes after a background command, as Claude Code does for background Bash waits.

Yield with outstanding work only at the user's direction/limit, a user-only dialog, a verified unrecoverable stall, an unavoidable host limit preventing further waits, or a pending background wait that re-invokes you. Unchanged output alone does not prove a stall. Report what resumes you, each unfinished agent's name/pane/state, owned containers, and exact wait/read commands. A notification can alert the human; it cannot wake you.
