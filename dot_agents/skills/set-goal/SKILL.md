---
name: set-goal
description: Create and start an outcome-based, verifiable completion contract from an explicitly requested task. Use for `/set-goal`, requests to set or start a goal, or long-running goal mode. Not for goal-setting discussion, ordinary planning, continuing an active goal, or direct `/goal Read ...` handoffs.
argument-hint: "[brief task description]"
allowed-tools:
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(date:*)
  - Bash(mkdir:*)
  - Bash(mktemp:*)
  - Agent
  - Read
  - Skill
  - Write
  - WebFetch
  - WebSearch
---

Create and start an external completion contract from the slash-command arguments or accompanying request. The contract preserves acceptance across turns and context changes; it is not a plan, todo list, progress log, or substitute for the task's source of truth.

A direct `/set-goal` invocation always runs this workflow, including when the task is to audit or edit this skill. Merely quoting or discussing goals does not invoke it. Do not infer goal mode for an ordinary task: its overhead is justified when the user explicitly requests it, especially for work that spans turns, compaction, sessions, executors, independent evaluation, or recoverable verification.

By default, create and start the goal before executing the requested work. If the user explicitly requires research or requirements gathering to finish before the Goal is drafted, created, or started, use the deferred read-only grounding path in Process. This delays Goal creation, not skill invocation.

## Goal Structure

Map every material user condition to the following sections in this order; omit empty sections. A condition is material when omitting it could change acceptance, authority, safety, compatibility, cost, scope, or required cross-validation.

1. Objective: one or two sentences naming the user-visible or system-observable end state. State an outcome, not implementation steps.
2. Proof of completion: for each material completion claim, name the check and expected observation. Prefer repeatable deterministic evidence such as tests, exit codes, state queries, logs, diffs, counts, or UI state. Use model judgment only for a criterion that deterministic evidence cannot decide, and name the rubric or human owner. Require the executor to surface fresh evidence after the final relevant mutation because the goal evaluator judges surfaced conversation evidence, not hidden filesystem or external state; rerun any check a later change could invalidate. For UI, connector, external-service, or production-runtime goals, require both the final user-visible state and the source-owned state that can overwrite it. If the environment cannot expose a required state, name the exact manual observation and keep the claim unverified until it is supplied.
3. Scope / constraints: include only files, modules, APIs, performance bounds, dependency limits, safety limits, compatibility requirements, subagent requirements, or cross-validation requirements that change what done means. Reference an existing issue, spec, tracker, or runtime source of truth instead of copying its dynamic state into the goal.
4. Out of scope: name specific adjacent outcomes that must remain excluded. Omit this section when no boundary changes completion.

Wrong Objective: `refactor the reconnect loop`.

Right Objective: `the tunnel reconnects within 5s after a network blip, with exactly one active session in the server log`.

## Iterative Evaluator Goals

When the request asks to repeat an evaluator, reviewer, auditor, cleanup pass, verifier, or critique until clean, empty, or issue-free, treat its output as evidence for a live issue frontier rather than the objective. Completion requires an empty accepted frontier and current evaluator evidence that adds no new trigger path; another pass requires a later mutation or new external evidence. Load the [iterative-evaluator goal contract](references/iterative-evaluator.md) before drafting frontier fields and the stop-and-report condition.

## Process

1. Use invocation arguments when supplied; otherwise use the accompanying request. If both are empty, ask for one sentence describing the desired end state.
2. Use deferred pre-Goal grounding only when the user explicitly orders research or requirements gathering to finish before Goal creation. A Goal whose work is research, investigation, discovery, or requirements gathering stays on the immediate path.
3. In the deferred path, use read-only tools and applicable research skills only to resolve acceptance questions derived from the request. Stop when every material acceptance question has current source-of-truth evidence or is recorded as an exact manual check or unverified gap. Do not mutate state or execute the Goal. Map findings into Objective, Proof, Scope, or Out of scope; do not add a research dossier.
4. On the immediate path, decide whether Objective and Proof are observable from the input. Do not treat request length or missing repository matches as ambiguity. If named files, symbols, or behaviors would materially sharpen Proof, perform one bounded read-only grounding pass: one `rg` or `fd` search, then read the most relevant owner. Do not use preprocessors, exec actions, command substitution, or shell operators, and do not mutate state during grounding.
5. Ask at most one focused question, and only when one unresolved choice would materially change acceptance.
6. Apply the linked evaluator contract when relevant, then draft the smallest goal that preserves every material condition.
7. Choose storage for the required lifetime. When the goal must survive a different session, host, or executor, require `SET_GOAL_OUTPUT_DIR` to name an absolute persistent path reachable by every executor; if it is absent, ask one focused question for that path and do not claim cross-session durability. Otherwise, if `SET_GOAL_OUTPUT_DIR` is set, resolve it to an absolute path and create it; for same-host work in the current session or its runtime-supported resume, run `mktemp -d` once and use that absolute runtime temporary directory. Write the goal with exactly one trailing newline as `YYYYMMDD-HHMMSS-<short-slug>.md`; use a lowercase ASCII, hyphenated, outcome-based slug.
8. Read the file back and verify exact equality after normalizing both strings to one trailing newline. If verification fails, use Failure Output. Otherwise use Output Contract.
9. Continue executing the goal from the verified file in the same thread. The callable-tool branch first creates or updates the runtime goal; every other runtime executes the file directly. Do not emit a `/goal` command.

## Output Contract

After read-back verification, follow the first matching branch.

If the runtime exposes `create_goal` or an equivalent callable tool:

- Call `get_goal` or the equivalent status tool first when available.
- If status identifies an unfinished goal, regardless of its status label, never replace it. Complete it with `update_goal` or the equivalent only when fresh evidence in the current conversation satisfies its own Proof; if completion is unavailable, unjustified, or fails, report the conflict or non-sensitive failure once and stop.
- Invoke creation once with exactly `Read <absolute-file-path>; the goal is met only when its entire contents are satisfied.` Pass the pointer, not the goal body.
- If creation reports an unfinished goal, refresh status once. Continue without retrying creation only when that status identifies the same prior goal as completed; otherwise report the conflict once and stop.
- Report any other non-sensitive creation or status failure once without blind retries. After success, execute the goal in the same thread.

Otherwise, the skill cannot program the runtime, so treat the verified file as the completion contract and continue executing it in the current thread. `/goal` is a user-owned entry point: never emit a `/goal` command or a paste handoff, whether or not a goal is already active.

## Failure Output

If writing or read-back verification fails, output exactly `file write failed: <reason>`, one blank line, then the goal body. Do not include a `/goal` command.

## Reject These Goal Shapes

- Steps disguised as an outcome.
- A passive plan or copied backlog that can become stale.
- Vague success such as `make it cleaner`, `improve performance`, or `fix the bug`.
- Self-report or subagent report without source, runtime, or outcome evidence.
- A hidden check the evaluator cannot observe in the conversation.
- A proof that cannot be phrased as an observable prediction; sharpen it or name the exact manual verification.
- Generic constraints that do not change acceptance.
- Padding, a research dossier, `/goal`, or handoff prose inside the goal file.
