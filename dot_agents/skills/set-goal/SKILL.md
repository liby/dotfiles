---
name: set-goal
description: Turn a brief task description into an outcome-based, verifiable goal file, then call the runtime's goal tool (Codex) or emit a `/goal` paste handoff (Claude Code). Use when the user says or mentions "/set-goal", "set goal", or asks for a long-running task goal. Not for continuing an active goal, ordinary planning, or direct `/goal Read ...` handoffs.
when_to_use: Use when the user wants a new goal file and `/goal` handoff, including when "set goal" appears inside a longer request. Do not use to execute an existing `/goal Read ...` command.
argument-hint: "[brief task description]"
allowed-tools:
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(date:*)
  - Bash(mkdir:*)
  - Read
  - Write
---

Create a goal file from `$ARGUMENTS` or the current user request, then follow the Output Contract. When invoked from natural language such as `set goal`, still create the goal file and go through the Output Contract first instead of jumping straight into the requested work.

For long-running or subagent-heavy work, translate the request into this schema: objective, criteria, evidence, scope, and any required cross-validation. Include subagent orchestration only when the request or proof requires independent checks.

## Goal Structure

The goal file is the condition that `/goal` evaluates. Produce these sections in this order. Omit empty sections.

1. Objective: one or two sentences naming the end state in user-visible or system-observable terms. Outcome, not steps.
   - Wrong: `refactor the reconnect loop`
   - Right: `the tunnel reconnects within 5s after a network blip, with exactly one active session in the server log`
2. Proof of completion: concrete checks a reviewer can execute and observe. Use test commands, log greps, curl invocations, UI states, file diffs, metrics, or explicit artifacts. Prefer deterministic gates over model judgment. For UI, connector, external-service, or production-runtime goals, require the final user-visible state and the source-owned state that can overwrite it; if the current environment cannot expose that state, require manual verification and name the exact observation needed. Include the evidence the agent must surface because `/goal` evaluators judge the conversation, not hidden filesystem state.
3. Scope / constraints: include only files, modules, APIs, performance bounds, dependency limits, safety limits, compatibility requirements, subagent requirements, or cross-validation requirements that materially change what done means.
4. Out of scope: specific related work that must stay outside the goal. Omit this section when no boundary changes completion.

## Iterative Evaluator Goals

When the request asks to repeat an evaluator, reviewer, auditor, cleanup pass, verifier, or critique until it is clean, empty, or issue-free, do not make the evaluator's empty output the objective by itself. Treat evaluator output as evidence for a live issue frontier.

In the goal file, require:

- the named evaluator or skill that owns issue classification
- a live issue frontier with each accepted item carrying a trigger path, evidence, impact, and owner
- each mutation round to report how the frontier changed: resolved, newly discovered with new trigger evidence, regression from the last fix, repeated prior issue, speculative claim without new evidence, or manual/runtime/product gap
- progress evidence after each mutation: validation output, source evidence, runtime evidence, or explicit manual gap
- a stop-and-report condition when the loop repeats the same root cause, the next fix would undo a prior fix, new work is mostly caused by the last fix, or the evaluator keeps producing claims without new evidence

Do not require a hard round budget unless the user asks for one or the executor skill owns a runtime safety cap. Do not freeze the issue set at the first pass. New findings can enter when they add a new trigger path, source-of-truth evidence, or a real regression. If a named evaluator skill has a loop or fix policy, reference that skill as the owner instead of restating its full rules.

## Process

1. Read `$ARGUMENTS`; if no slash-command arguments are available, use the current user request as the input. If both are empty, ask for one sentence describing the desired end state.
2. Decide whether Objective and Proof can be drafted from the input. Do not treat length alone or missing repo matches as ambiguity.
3. If named symbols, files, modules, or behaviors would make the proof sharper, do one read-only grounding pass before asking:
   - one broad `rg` or `fd` for named symbols, files, modules, or behaviors
   - one targeted read of the most relevant file, doc, or call site
4. Ask one specific question only if the user request lacks an observable outcome or success evidence after optional grounding.
5. For iterative evaluator requests, apply Iterative Evaluator Goals before drafting Proof of completion and Scope.
6. Draft the goal in the structure above. Bias toward specificity over length.
7. Write exactly the drafted goal text with one trailing newline to a markdown file under `${SET_GOAL_OUTPUT_DIR:-/tmp}`. Create the directory first. Use `YYYYMMDD-HHMMSS-<short-slug>.md`; make the slug lowercase ASCII, hyphenated, and outcome-based.
8. Read the file back and verify its content equals the drafted goal text after both strings are normalized to exactly one trailing newline. Verification is internal; do not output the verification result.
9. If verification fails, use the failure output shape below.
10. If verification succeeds, follow the output contract below.
11. Stop after the paste handoff; the callable-tool branch continues executing the goal instead.

## Output Contract

After read-back verification succeeds, emit either a callable goal tool invocation or a two-line paste handoff. No summaries, file path explanations, or additional commentary around it.

If your runtime exposes a callable goal tool such as `create_goal` or equivalent (Codex and similar), invoke it with the argument `Read <absolute-file-path> and use its contents as the goal.` Pass only this short pointer, never the drafted goal body: the objective field is capped (~4000 chars in Codex). If creation fails because the thread already has an unfinished goal, report the conflict with the goal status tool's output (`get_goal`) instead of retrying. After the call succeeds, continue executing the goal in the same thread.

Otherwise the entire assistant message is exactly two paragraphs separated by a blank line. The first paragraph is the literal string `Run next:` and the second is `/goal Read <absolute-file-path> and use its contents as the goal.` Nothing else before, between, or after these two paragraphs. This branch always applies in Claude Code, where `/goal` is a user-input-only CLI slash command and not agent-callable.

## Failure Output

If file writing or read-back verification fails, reply with `file write failed: <reason>` followed by the goal body. Do not include a `/goal` command on failure.

## Anti-Patterns

- Steps disguised as goals: `1. read file X 2. modify Y 3. run tests`.
- Vague success: `make the code cleaner`, `improve performance`, `fix the bug`.
- Self-report validation: `the agent confirms the change works`.
- Subagent self-report as proof without master-side evidence.
- Empty evaluator output as the only completion proof for an iterative evaluator loop.
- Generic obligations in Scope: `use the existing code style`, `don't break tests`.
- A proof that cannot be phrased as an observable prediction (command output, log line, UI state): that is a vibe, not a gate. Sharpen it or mark it manual verification.
- Padding for length.
- Putting `/goal` or surrounding prose inside the goal file.
