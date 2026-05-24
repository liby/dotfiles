---
name: set-goal
description: Turn a brief task description into an outcome-based, verifiable goal, then hand it off to `/goal`. Use when the user says "set goal", "/set-goal", "goal-driven", or asks to set up a goal for a long-running task. Replaces direct `/goal "fix the bug"` style invocations.
argument-hint: "[brief task description]"
allowed-tools:
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(date:*)
  - Bash(mkdir:*)
  - Read
  - Write
---

Turn `$ARGUMENTS` into a structured goal file, then return a compact handoff. The skill ends at the handoff; do not start executing toward the goal in the same turn unless the original message asked you to.

## Goal structure

Produce these sections in this order. Omit empty sections; do not pad.

1. Objective: one or two sentences naming the end state in user-visible or system-observable terms. Outcome, not steps.
  - Wrong: `refactor the reconnect loop`
  - Right: `the tunnel reconnects within 5s after a network blip, with exactly one active session in the server log`
2. Proof of completion: concrete checks a reviewer can execute and observe. Test commands, log greps, curl invocations, UI states, file diffs, metrics. If you cannot name a check, the objective is too vague; revise it.
3. Scope / constraints: include only when they materially change what `done` means. Files or modules in scope, APIs that must stay backward compatible, perf or memory bounds, dependencies you may not introduce. Skip when defaults apply.
4. Out of scope: include only when there is a tempting adjacent task you must not do. Keeps the agent from scope-creeping into a "while I'm here" rewrite.

## Steps

1. Read `$ARGUMENTS`. If empty or under five words, ask the user for one sentence describing what they want done.
2. Read-only grounding: one broad `rg`/`fd` pass for the symbols, files, or behaviors named in the description, plus one targeted read of the most relevant file or call site. Stop once Objective and Proof can name concrete evidence. Skip entirely when the description is self-contained (e.g., `add a --json flag to "tool foo" that prints the result as JSON`).
3. Draft the goal in the structure above. Bias toward specificity over completeness: a 4-line goal that names the right end state beats a 20-line goal that hedges every term.
4. Write the drafted condition text to a markdown file under `${SET_GOAL_OUTPUT_DIR:-/tmp}`. Create the directory first. Use `YYYYMMDD-HHMMSS-<short-slug>.md`; make the slug lowercase ASCII, hyphenated, and based on the outcome.
5. The file content is exactly the goal condition text. Do not put `/goal`, copy instructions, markdown fences, or surrounding prose inside the file.
6. Reply with only a short description, the absolute file path, and this copyable command line: `/goal Read <absolute-file-path> and use its contents as the goal.` Do not echo the goal body in chat.
7. If file writing fails, output the goal body once and say the file write failed. Do not duplicate it in a second `Run:` line.
8. Stop. The skill's job ends after the compact handoff.

## Anti-patterns

- Steps disguised as goals: `1. read file X 2. modify Y 3. run tests`. Steps belong in a plan.
- Vague success: `make the code cleaner`, `improve performance`, `fix the bug`. A reviewer cannot tell when these are met.
- Self-report validation: `the agent confirms the change works`. Validation must be observable independent of the agent's claim.
- Generic obligations in Scope: `use the existing code style`, `don't break tests`. The agent already does these; put concrete validation commands under Proof instead.
- Padding for length: a goal is not a design doc. If a section adds no constraint, delete it.
- Handoff duplication: do not print the full goal body or add a second command line.
- Handoff leakage: do not include `/goal` or platform instructions inside the goal file itself.
