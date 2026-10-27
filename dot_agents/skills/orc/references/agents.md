# Coding agents in Rex

## Choose how the agent runs

Choose the mode by what the task needs after launch. Either way, start the agent in its own pane with its task passed at launch and `--keep-open`; [its runtime's section](runtimes.md) gives the flags for both modes.

- Interactive session when the user wants to watch it work, interject, or take over, or when the task already plans more turns with the same participant, such as re-checking your fixes or a discussion round, so that later prompts reach the conversation that holds the context. Use its runtime's screen mode and have its own terminal title name the participant, because a program's title replaces the pane label in the Rex header.
- Native non-interactive run for a one-shot job that ends with its output, such as a bounded question or review whose answer you act on yourself, or a scripted batch: process exit bounds the wait, the answer is the tool's output file, which the task registers as its result, and no dialog can stop it. When the runtime's non-interactive run only prints its answer, ask in its task for the answer in that file. Some runtimes print nothing until they finish, so run those interactively when the user wants to watch.

The agent must work under the existing permissions; an approval it cannot obtain is a blocker.

When collecting directly from a fullscreen agent, or when capture or stdout cannot return a long answer whole, give each requested turn a distinct absolute Markdown answer-file path in this task's temporary directory and ask for the complete answer there. Read it on the host that wrote it after the turn finishes; a missing or partial file leaves the result uncollected. For an existing session without an answer file, read the matching turn from its verified native session record.

Reuse a live agent only when the user asked to continue or message it, or this task started it, and its role and context still match; a new participant or a new question needs a new pane and a fresh conversation. A conversation whose context is mostly used, or whose prompt cache has expired, costs more to continue than a fresh agent given a self-contained brief, so continue it only when the work needs what only that conversation holds. Read-only helpers may share a checkout; serialize writers unless the user asks for isolated worktrees. Commands that read a credential store or open a browser sign-in can each raise an approval or sign-in prompt, and parallel runs stack them on the user, so run them one process at a time across yourself and every helper; launching agents whose sign-in already works is not such a command. State both constraints in the helpers' tasks; they are not sandbox settings.

## Resolve the runtime, model, effort, and cache

A model name is not an executable. Use the runtime the user names; otherwise prefer the model vendor's installed agent when it offers the model, then another installed runtime whose usable-model listing includes it. For Pi, inspect `pi --list-models <search>`. If no route works, report those checked and ask; one missing model-named CLI does not exhaust the routes.

Pass a model ID the user gives exactly as given, even when the runtime has no usable-model listing to find it in. For a name that is not an ID, use the single ID that configuration or the usable listing pairs with it, or a native alias, and if it remains unresolved or ambiguous after those checks, ask one question rather than guessing.

Use the reasoning effort the user names; otherwise decide it per participant, moving from that model's default only for a reason its task gives: lower when the task is bounded and fully specified and you will check the result, higher when it must trace complex logic, weigh trade-offs, or find what others missed. Reserve the top levels for the hardest long work, because each step up lengthens turns and the waits that collect them. Pass the level at launch with the runtime's effort flag, since a launch without one takes a configured default instead of this decision.

A later prompt reuses the conversation's prompt cache only within the provider's retention, often five minutes. When the planned follow-ups will come later than that but within a longer retention the runtime's section lists, as when they wait for fixes you make, launch with that retention; keep the default for one-shot runs, quick exchanges, and follow-ups that would outlast both, because a longer retention can cost more to write.

## Answer a dialog inside an agent you started

Capture an interactive agent's screen before its first prompt: a dialog may already be showing. A dialog in someone else's agent belongs to the user. A question the agent's own model raises is such a dialog, and a [Codex question card](runtimes.md#answer-a-question-card) shows no options until opened. Identify the intended and selected options and navigate without submitting until the whole option list is visible; never confirm unseen options.

Answer only within the task's authorization, with no uncleared stop under the host's authority rules and no answer only the user holds. Without shared rules, require an undoable action visible only to the user, or specific user direction clearing the otherwise-stopped effect. Judge the action enabled, not the keypress; do not spend a helper's permission boundary. Resolve a model choice from the requested or configured ID; ask only for an undelegated material choice.

Accepting a folder trust prompt for the agent's checkout, as [Launch](../SKILL.md#launch) directs, enables that checkout's project configuration, such as settings, hooks, permission rules, and extensions. Where the runtime raises a separate hook review, its trust option lets every listed hook, including hooks from user configuration, run outside the sandbox: continue without trusting them and report them. Do not start the agent from another directory or strip its configuration to avoid either prompt: the agent can keep its access to the checkout yet lose the checkout's instructions and configuration. Decline optional onboarding or configuration offers, such as `Teach auto mode about your environment?`, with their visible defer option, not a settings-writing option or an assumed Escape binding. Move to the chosen option with `rex send-key`, confirm it, and capture again after each key, because another dialog may follow.

When user input is required, report the agent, pane, and exact dialog and options while unblocked participants continue.

## Deliver a prompt

Choose delivery-only or required results before submitting. Enter the prompt itself as a paste, as [Send input to a running program](../SKILL.md#send-input-to-a-running-program) shows. Never paste another task into a busy editor. When the target is working, deliver without waiting for it to go idle: Claude Code queues a message entered while it works, and Codex and Pi have their own [queue and steer paths](runtimes.md); for any other runtime, wait for the active turn to settle before prompting. For parallel work, confirm each receipt on the screen or in the queue command's output, then dispatch the rest of the batch before collecting.

## Complete the requested outcome

- Delivery-only finishes when the intended agent shows the exact message accepted, reported as delivered or queued, not processed.
- Required results finish only after every required participant's actual response or blocker to the new message is collected and judged. Read each prompt's complete answer, including questions, blockers, and stated failures; reported program status is neither a turn receipt nor a verdict. If the latest reply still answers an earlier turn, or the screen shows the new message queued or running, wait again without resubmitting. After a timeout, read and keep waiting finitely in this turn while the live task continues; unchanged output alone does not prove a stall.

Ending the turn schedules collection only through something that resumes you: a rexume notice for a registered task, a background command the host re-invokes you after, as Claude Code does for background Bash waits, or a new user message. Yield with outstanding work only at the user's direction or limit, a user-only dialog, a verified unrecoverable stall, an unavoidable host limit preventing further waits, or a pending notice or background wait that resumes you. Report what resumes you, each unfinished agent's pane and state, owned resources, and the exact wait and capture commands.

## Run a panel

Use a pane when a participant needs a different agent binary or model vendor, the user needs to watch or take over its session, or asks for one; equivalent in-process subagents save screen space for other participants when available. One round asks one question. Give every participant the same self-contained brief, start fresh agents in new panes, verify they did not resume old conversations, and use distinct labels across simultaneous rounds.

Freeze the checkout, or a named base plus the complete uncommitted diff, before dispatch and leave it unchanged through the round; changed inputs make verdicts incomparable. Keep other participants' answers out of briefs and the working directory until comparison. The brief must prohibit reading their panes, sessions, or verdicts: exposure invalidates independent confirmation, so disclose affected results. Put outputs in this round's own directory.

Ask for the complete written verdict in the pane or the run's native output, and name what to compare. Dispatch the whole batch, confirm each delivery, then collect every assessment under [the completion rules](#complete-the-requested-outcome); a dialog in one participant must not prevent dispatch to the others. Attribute each finding to the runtime and model you launched, not to the model's account of itself, which can be wrong, and distinguish agreement from disagreement. For a discussion follow-up, quote the other positions verbatim, because participants share no conversation context.
