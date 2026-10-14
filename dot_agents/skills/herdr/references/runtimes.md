# Runtime-specific Herdr behavior

## Claude Code host

Give Herdr control commands their own Bash call, containing only exempt commands and their literal arguments (descriptor duplication such as `2>&1` is allowed). Other shell segments, such as a `sleep N;` before a read, heredocs, backticks or `$(` (including `$((`) even inside arguments, and non-inert inline assignments sandbox the whole call; inert assignments such as `TERM`/`LANG` are exceptions, and `"$HERDR_PANE_ID"` or a quoted `$?` stays exempt. Track agent turns and pane output with the corresponding finite Herdr wait command; a required time delay uses a separate `sleep` call. Use a task-owned file pointer for rich task text, or have the target pane source a file for rich shell commands. Do not suppress socket errors with `2>/dev/null`.

A socket connection denied with `Operation not permitted` submitted nothing: remove the non-exempt shape before retrying. This is distinct from an uncertain result after submission. For foreground waits, set Bash's timeout above Herdr's finite timeout and within the tool limit; a background Bash wait re-invokes Claude when it exits.

## Codex

Use the profile selected by `default_permissions`; pass no `-s`/`--sandbox` unless the user names a sandbox mode. That flag substitutes legacy sandbox settings rather than narrowing the profile. A managed `allowed_permission_profiles` requirement keeps the profile, so `-s read-only` cannot remove its write access; report that limitation when a read-only launch is requested. Where the flag takes effect, read-only disables the profile's network access.

### Answer a question card

A Codex model's question appears as a collapsed card under `Queued follow-up inputs` (`? N question · shift+← to answer`) while its turn keeps running: Herdr reports `blocked`, `agent prompt` refuses with `agent_blocked`, and the card shows no options until opened. Open it with `agent send-keys <agent-name> shift+left`, then answer under the [dialog contract](agents.md#answer-a-dialog-inside-an-agent-you-started): choose with `up`/`down`, or type free text into `Other` with `pane send-text`, and submit with `enter`; the reply is bound to that question. Typed Enter in the main composer instead removes the card and arrives as an unbound message. The card disappears when the asking turn ends; deliver an answer that arrives later, such as the user's, as next-turn input.

### Queue or steer a busy agent

While a Codex recipient is running a turn, choose between queueing for the next turn and steering the active turn. To queue for the next turn on this machine (including while a question card is pending, since `codex queue` writes to the queue database under `CODEX_HOME` without touching the composer), take its exact native UUID from `agent get` (`agent_session.kind: id`, `value`; agent names, pane IDs, and titles are not thread IDs) and enqueue now without waiting for the active turn; to steer an unblocked running turn immediately (when no question card is pending), use `herdr agent prompt` without `--wait`:

```bash
codex queue --thread <verified-session-uuid> --message '<follow-up>'
herdr agent prompt <agent-name> '<steer-message>'
```

Retain thread/message receipt IDs. Queue acceptance proves enqueueing, not consumption: apply the [outcome contract](agents.md#complete-the-requested-outcome). Required results need the new message's response; if a wait settles on the earlier turn before the queued or steered message is answered, wait again without resubmitting.

Herdr's `--machine` does not forward `codex queue`. For a recipient on another machine or under another `CODEX_HOME`, or after an explicit rejection before enqueueing, either steer the active turn with `agent prompt` when mid-turn delivery is acceptable and no question card is pending, or follow the original agent until settled and then use `agent prompt`; qualify remote wait/read/prompt calls with the same `--machine`. An uncertain queue/submission result requires reconciliation before this fallback or any retry. Finish the delivery now rather than promising it later.

A long/multiline terminal paste can remain unsent after Enter despite reported success. If that exact text is visibly still in the composer, queue it with Tab, not Enter, which would steer the running turn, and verify the queued indication/eventual response; do not repaste or also enqueue it. A cleared composer or idle state alone is not a receipt.

## Pi

Pi lifecycle hooks own Herdr's status (`full_lifecycle_hook_authority`), so it may disagree with the screen. While Pi is `working`, `herdr agent prompt <agent-name> '<text>'` (without `--wait`) steers the active run after the current tool batch; to queue a follow-up for after the run finishes instead, confirm on `visible` that the editor is empty, send the text with `herdr pane send-text <pane-id> '<text>'`, and submit it with `herdr agent send-keys <agent-name> alt+enter`. Send slash commands with `pane run` and verify `visible`; editor-only commands do not settle lifecycle waits. Abort a running turn with `agent send-keys <agent-name> esc`; default Ctrl+C clears the editor.

On a stall or hook/pane disagreement, read `visible` and reconcile the submitted task with its actual answer/receipt. An idle prompt can mean completed or never delivered. Collect completed output; resend only with proven non-delivery or a harmless repeat, otherwise report ambiguity. Use `pane send-text` followed by `send-keys enter` (a steer submission) only for visibly proven non-delivery, submitting a one-line file pointer and confirming receipt.

If interactive delivery stays unreliable, use print mode only after establishing the original turn is no longer running. Split a shell pane: `pane run` in the agent pane types into its editor. Preserve provider, exact model and full task; check output and exit status. Report persistent hook/pane disagreement with versions and observations; do not repair integrations or invent a cause.
