# Herdr agent workflow

## Start and drive an agent

Inspect the live agents before creating or prompting one:

```bash
herdr agent list
```

`agent list` is how you find a free name, not how you find an agent to reuse: names are unique only among live agents and are released when one exits, so a name that was yours can now belong to another instance. Reuse a settled live agent only when the user asked to continue that instance, or this task started it, and in either case its role and context still match; a call for a new participant needs a fresh agent. Do not use `agent prompt --wait` on a `working` agent: its current turn can finish and incorrectly satisfy the new wait. For a requested next-turn message to Codex, use its native queue as described in [Codex runtime behavior](runtimes.md#codex). Otherwise wait for the current turn before prompting. Treat `unknown` as unresolved, not complete.

Name an agent for its role plus whatever separates it from its siblings, which is the model when several models share a role and the target when several instances share a model. Start each participant you were asked to create in a newly created pane.

Helpers that only read may share the current checkout; concurrent writers may not. Limit extra agents to reading, or run writers one at a time, unless the user asks for isolated worktrees, and state that limit in the task text: it is a constraint on what the helper does, not a sandbox setting.

### Resolve the runtime and model

Users usually name a participant by model, not by program. `--kind` names the agent program that runs in the pane, and the kinds `herdr agent` lists are programs, some of which share a vendor's or model's name, so a model name is never itself a kind. Resolve each participant in this order before starting it:

1. When the user names the runtime, use it.
2. Otherwise use the model vendor's own agent when it is installed and offers the model, such as Claude Code for Claude models and Codex for OpenAI models.
3. Otherwise use an installed runtime whose own list of usable models contains it. For Pi, `pi --list-models <search>` lists only models whose configured provider can serve them.
4. When no installed runtime offers it, report the runtimes you checked and ask. A missing CLI named after the model, or a kind Herdr lists but this machine has not installed, settles only that one route.

Pass the exact model ID the user gave, or the one the runtime's listing or configuration pairs with the user's name for it; an alias the runtime resolves natively can pass through as it stands. Never invent an ID: a name you cannot resolve that way is worth one question rather than a guess. For Pi, pass both `--provider` and `--model`, taking the provider from the same listing row, even when a default provider is configured: `--model` alone can resolve to a built-in provider that has the same model ID but no credentials. Start the runtime directly and let the selected provider resolve its own credentials; do not synthesize or remap credential environment variables.

### Start, prompt, and read

`agent start` requires an existing pane at an interactive shell prompt. Pass the resolved kind, and pass native arguments such as the provider and model only after `--`:

```bash
herdr agent start <agent-name> --kind <kind> --pane <returned-pane-id> -- <agent-args...>
```

A successful `agent start` returns only after Herdr detects the expected agent and considers it ready for input. If startup is blocked, it returns `agent_not_ready` but keeps the name available. Either way, read `visible` before prompting: a startup prompt can still be on screen while Herdr already reports `idle` and `interactive_ready`.

Submit a self-contained task as one literal argument. Choose the requested outcome before submission: delivery alone, or delegated work whose result you must collect. When the caller must keep working in parallel, prompt without `--wait`, confirm delivery from the pane, continue the caller's work, and collect with `agent wait <agent-name> --timeout <milliseconds>` before finishing. Use `--wait --timeout` for a synchronous task. Task text and quoted findings routinely contain backticks and `$(...)`, which your own shell expands inside double quotes before Herdr ever sees the argument, so keep the task in single quotes:

```bash
herdr agent prompt <agent-name> '<task>' --wait --timeout <milliseconds>
```

When the text itself contains quotes, write it to a file under this task's own directory and prompt the agent to read that path, which keeps the shell out of it entirely.

For an idle agent, deliver tasks and follow-ups through `agent prompt`: it gives Herdr the agent identity and ordered paste/submission boundary. Do not paste another task into a busy editor. Codex next-turn messages use the native queue; typed delivery is reserved for the runtime-specific recovery in [runtime behavior](runtimes.md).

`--wait` settles on `idle`, `done`, or `blocked`; do not narrow it to `--until done`, and keep it whenever you pass `--timeout`, which requires it. A wait tracks lifecycle state, not an individual turn or a successful result. A timeout ends only the wait and does not prove the agent is still working. After every wait, read the response to your prompt and check for a question or a stated inability to proceed. Never blindly resend the prompt or press Enter when submission is ambiguous.

```bash
herdr agent get <agent-name>
herdr agent read <agent-name> --source recent-unwrapped --lines 120
```

Raise `--lines` as needed to reach the complete response, including any questions or blockers. The read has a row cap, so a long turn can push earlier output out of reach; when a larger read returns no older output and the response is still incomplete, use the file fallback under [Run and read a pane command](../SKILL.md#run-and-read-a-pane-command). On `agent_blocked`, `blocked`, timeout, `agent_prompt_stalled`, or unexpected output, inspect `agent get` and read `visible` before deciding whether a follow-up is safe.

## Answer a dialog inside an agent you started

A dialog blocks the agent it appears in and everything waiting on that agent, so leaving one on screen costs the whole round. A dialog inside an agent you did not start belongs to the user. Inside one you started, `agent prompt` refuses with `agent_blocked` instead of sending input, which is usually how you find out. Read `visible` before pressing anything, and identify both the option you intend and the one currently selected. `visible` returns the viewport, so raising `--lines` cannot bring an option that is off screen into view; use the dialog's own non-submitting navigation and read again. If you still cannot see the full option list, do not press a confirmation key.

Answer it yourself when the option you mean to choose has no stop requirement left to clear under Authority (without the shared rules in context, answer only when the action is still undoable and no one else can see its result, or when the user's own direction or supplied text clears the effect it would otherwise stop for), the answer does not need the user personally, and answering stays inside what the user authorized for this task. Judge the option by the action it lets through rather than by the keypress: approving a command inside a helper inherits that command's consequences, and that helper's permission boundary is the user's configuration, not budget for you to spend. Wait when a stop effect remains uncleared, when only the user holds the answer, or when answering would claim authority the task never granted. A question is not the user's merely because the dialog phrases it as one: answer a model prompt from the ID the user named or the one configuration pairs with it, and wait only when a materially different choice is still open and the task did not delegate it.

Two cases recur. A prompt asking whether to trust the working directory or the hooks already present there writes the configuration that decides what may run without asking, so it is subject to that stop effect: let the repository's hooks run with the user's permissions only when the user's direction or a standing authorization already covers that checkout, and otherwise name what those hooks do and ask. Reading files in a checkout is not by itself authorization to execute hooks a branch introduced. When you do accept, move to the option that grants trust, because the preselected one can be a review or decline step, then confirm. An agent's own onboarding or configuration offer, such as `Teach auto mode about your environment?`, is yours to decline with whichever option defers it, never with the variant that writes a setting on the user's behalf; read which key that is rather than assuming Escape. After any keypress, read again: a startup sequence can raise a second dialog, and one keystroke is not proof the agent reached a usable prompt.

```bash
herdr agent send-keys <agent-name> down enter
herdr agent send-keys <agent-name> esc
```

When you do wait, name the blocked agent and pane and quote the dialog with its options, and let the participants that are not blocked keep working.

## Complete the requested outcome

Herdr never resumes you: it has no message that reaches another agent, and its notifications reach the human, never this conversation. Once your turn ends, only a new user message starts it again, unless your host re-invokes you when a background command exits, as Claude Code does for a Bash command run in the background; only there is a backgrounded `herdr agent wait <agent-name> --timeout <milliseconds>` a way to be resumed. Otherwise "I'll summarize when they finish" or "I'll watch it" leaves the round stalled until the user notices.

For a delivery-only request, finish when the intended session has accepted the exact message, and report that evidence as delivered or queued without claiming it was processed. Any readiness wait needed before sending belongs to this delivery task; complete the wait and submission rather than leaving an unscheduled message for later. Delivery completion does not release an earlier promise to collect that agent's work.

When the user requires delegated work or results, the work is done only when every required participant is accounted for: for each, wait on a finite timeout, then read its answer to this prompt and judge it, counting a question, blocker, or stated failure as part of your answer. A settled state is not a result, and for a prompt sent without `--wait` confirm delivery first, because `idle` proves nothing about a task that never arrived. When a wait times out, the wait ended and the work did not: read the pane, and if a live turn is on screen, wait again in this turn, keeping the re-waits bounded. Where a reported state disagrees with the pane, the pane decides; on Pi the hook can stay `working` after the answer is on screen (see [Pi runtime behavior](runtimes.md#pi)).

Yield with work outstanding only when the user asked to leave it running, only the user can answer a dialog, the host will not accept another wait, or a background wait your host re-invokes you on is pending. Then say what resumes the round, a new user message or a background wait your host re-invokes you on, and for each unfinished participant give its agent name, pane ID, and last observed state, the containers you own, and the exact `herdr agent wait <agent-name> --timeout <milliseconds>` and `herdr agent read <agent-name>` commands. `herdr notification show` can alert the human before such a yield; it cannot wake you.
