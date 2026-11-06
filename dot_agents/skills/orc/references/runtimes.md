# Runtime-specific behavior in Rex

## Claude Code host

When the sandbox refuses the server socket, `rex` fails with `operation not permitted` before submitting anything, so that failure is not an uncertain result: report it as a sandbox configuration gap. `Bootstrap failed: 5` means the server was not running and the sandbox kept `rex` from starting it: open the Rex app, or run that one `rex` call outside the sandbox. Do not hide socket errors with `2>/dev/null`.

For a foreground `rex wait --for`, set Bash's timeout above that duration and within the tool limit. A Bash call moved to the background keeps running: retain its task ID and output-file path and follow its completion notification. While that wait remains active for the same target, do independent work or yield instead of starting another wait or polling loop. Before replacing a wait whose result is unknown, reconcile the host task and establish that it ended; neither a lost connection, a missing receipt, nor the target's reported status establishes that.

## Claude Code participant

`claude` on PATH is a launcher that runs Claude Code on the subscription or the gateway: `--subscription` or `--gateway` as its first argument picks the route for that launch, and without either it takes the saved mode, which can differ from the route the task calls for.

`claude -n '<participant>' '<task>'` starts an interactive session with the participant in its terminal title; `claude -p '<task>'` runs non-interactively and prints nothing until it finishes. Set effort with `--effort <level>`.

`env CLAUDE_CODE_PROMPT_CACHE_TTL=1h` before `claude` in the launch command requests an hour of cache retention for the conversation on any route that supports it.

## Codex

`codex --no-alt-screen -c 'tui.terminal_title=["activity","model-name","thread-name"]' '<task>'` starts an interactive session on the primary screen with the model and the name Codex generates for the thread from its task in its terminal title. `codex exec '<task>'` runs non-interactively, shows its progress in the pane, and with `-o <file>` also writes its final message to a file. Set effort with `-c 'model_reasoning_effort="<level>"'`.

Use the profile selected by `default_permissions`; pass no `-s`/`--sandbox` unless the user names a sandbox mode. That flag substitutes legacy sandbox settings rather than narrowing the profile. A managed `allowed_permission_profiles` requirement keeps the profile, so `-s read-only` cannot remove its write access; report that limitation when a read-only launch is requested. Where the flag takes effect, read-only disables the profile's network access.

### Answer a question card

A Codex model's question appears as a collapsed card while its turn keeps running, and shows no options until opened. Open it with the key the card names, sent through `rex send-key`, then answer under the [dialog rules](agents.md#answer-a-dialog-inside-an-agent-you-started): choose an option, or paste free text into its free-text option, and submit; the reply is bound to that question. Enter pressed in the main composer instead removes the card and arrives as an unbound message, and Rex does not refuse that input. The card disappears when the asking turn ends; deliver an answer that arrives later, such as the user's, as next-turn input.

### Queue or steer a busy agent

While Codex is running a turn, choose between queueing for the next turn and steering the active one. To queue on this machine, including while a question card is pending, use `codex queue`, which writes to the queue database under `CODEX_HOME` without touching the composer. Use the thread's verified native UUID from Codex itself; pane labels, block IDs, and titles are not thread IDs.

```bash
codex queue --thread <verified-session-uuid> --message '<follow-up>'
```

To steer an unblocked running turn immediately, with no question card pending, paste the message into the composer and press `enter`.

Retain thread and message receipt IDs. Queue acceptance proves enqueueing, not consumption: a required result needs the new message's response. For a recipient under another `CODEX_HOME` or on another machine, or after an explicit rejection before enqueueing, steer only when mid-turn delivery is acceptable and no card is pending; otherwise follow the turn until it settles and prompt then. An uncertain queue or submission result requires reconciliation before this fallback or any retry.

## Pi

Take both `--provider` and `--model` from the same `pi --list-models` row and pass both: a default provider does not prevent model-only resolution to an unauthenticated built-in provider.

`pi --tui-mode fullscreen --name '<participant>' '<task>'` starts an interactive session on the alternate screen with the participant in its terminal title; `pi -p '<task>'` runs non-interactively and prints nothing until it finishes. Set effort with `--thinking <level>`.

`env PI_CACHE_RETENTION=long` before `pi` in the launch command lengthens the cache where the provider supports it, to an hour on Anthropic models; what it gives on other providers varies with their API.

While Pi is working, a message entered and submitted with `enter` steers the active run after the current tool batch. To queue a follow-up for after the run instead, confirm on the screen that the editor is empty, paste the text, and submit it with `alt+enter`. Abort a running turn with `esc`; Ctrl+C clears the editor. Editor-only slash commands start no turn, so verify them on the screen.

An idle prompt can mean completed or never delivered: reconcile the submitted task with its actual answer or receipt, collect completed output, and resend only after proven non-delivery or when a repeat is harmless; otherwise report the ambiguity.
