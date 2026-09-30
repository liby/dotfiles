# Runtime-specific Herdr behavior

## Claude Code host

Where the host sandbox exempts `herdr` by command name, as Claude Code does, give a control command the shell invocation to itself: keep every command in it an exempt one, split at shell separators such as `|`, `&&`, `;`, and a newline, and put nothing else in the call but those commands' own arguments and a file-descriptor duplication such as `2>&1`; a command substitution or heredoc sandboxes it even inside an argument. An inline assignment before the command name sandboxes the call, unless the name is one the CLI treats as inert, such as `TERM` or `LANG`. A sandboxed socket call then fails with `Operation not permitted` rather than a recognizable permission error, and a `2>/dev/null` hides that message while the call still fails.

## Codex

Start Codex on the profile its `default_permissions` setting selects, and pass no `-s` / `--sandbox` value unless the user names a sandbox mode for this launch. The flag does not narrow that profile: it selects Codex's older sandbox settings in its place, and a managed `allowed_permission_profiles` requirement alone keeps the profile, so if the user asks for a read-only launch, say that under that requirement the flag cannot remove the profile's write access. Where the flag takes effect, `-s read-only` turns off the network the configured profile keeps enabled.

### Queue a next-turn message

For a requested follow-up to a busy Codex session on this machine, use `codex queue` after verifying that it reaches that agent's app server. Resolve the session UUID from `herdr agent get <agent-name>` (`agent_session.kind: id`, `agent_session.value`), and verify that this live agent is the intended recipient; an agent name, pane ID, or terminal title is not a Codex thread ID. Enqueue now for execution after the active turn; do not wait for that turn to finish before enqueueing.

Herdr's `--machine` does not forward `codex queue`. If no Codex app-server route is verified, or the queue explicitly rejects the message before enqueueing, follow the original agent with finite waits and pane reads until its turn settles, then submit with `herdr agent prompt`. Qualify every remote wait, read, and prompt with `--machine <label-or-id>`. Use this path only after establishing that the queue did not accept the message; an uncertain result requires reconciliation instead. Finish that delivery in this task; a promise to send later has not queued anything.

```bash
codex queue --thread <verified-session-uuid> --message '<follow-up>'
```

Keep the returned thread and queued-message IDs. Acceptance by the queue proves enqueueing, not consumption. Apply the [requested-outcome contract](agents.md#complete-the-requested-outcome): a delivery-only request ends at the bound receipt; when results are required, follow the same agent with finite waits and reads until that message's actual response or blocker appears. The current turn can settle before the queued turn starts, so one Herdr wait is not enough to collect a result. If the queue call's result is uncertain, inspect that session before sending again; a retry creates another message.

Codex distinguishes busy-turn steering from next-turn queueing: Enter steers the current turn and Tab queues the next. Long or multiline terminal pastes can remain in the composer after Enter even while the command reports success. If an earlier delivery is visibly still unsent in the composer, queue that existing text with Tab and verify the queued indication and eventual response; do not paste it again or also enqueue a duplicate. A cleared composer or `idle` status alone does not establish receipt.

## Pi

Herdr takes a Pi pane's status from the lifecycle hook, not the screen (`screen_detection_skip_reason: full_lifecycle_hook_authority`), so the reported turn state can be stale.

Use each layer for what it owns:

- Send slash commands with `pane run` and read `visible` to confirm the effect, since a command that only changes the editor or the session leaves lifecycle state untouched and an `agent prompt` wait would never settle on it.
- Stop a running turn with `herdr agent send-keys <agent-name> esc`, which is Pi's documented abort in its default bindings; Ctrl+C clears the editor instead.

When the hook's report and the pane disagree, decide from the pane:

- A stall does not prove non-delivery, and `agent get` can report `working` after the pane has returned to its prompt. Read `visible` and reconcile what you sent against what the pane shows: an idle pane can mean the task finished as easily as it can mean the task never arrived. Collect the result if the turn completed, resend only once non-delivery is established or repeating the task is harmless, and otherwise report the ambiguity rather than replaying work.
- Use `pane send-text` followed by `send-keys enter` only when the visible state confirms that Pi did not receive the task, and type a one-line pointer to a file holding the task rather than the task itself; confirm receipt afterward.
- If interactive delivery stays unreliable for a long task, fall back to print mode, but only from a pane at a real shell prompt: `pane run` types into whatever holds the foreground, which in the agent's own pane is the Pi editor, so split a pane for it rather than reusing that one. Establish first that the interactive turn is no longer running, keep the provider, exact model, and full task from the original invocation, and check the exit status as well as the output.
- A persistent disagreement between the hook's report and the pane is worth reporting with the versions and what you observed; do not repair the integration yourself, and do not name a cause you have not isolated.
