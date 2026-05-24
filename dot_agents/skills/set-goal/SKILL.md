---
name: set-goal
description: Turn a brief task description into an outcome-based, verifiable goal file, then start `/goal` when available. Use when the user says or mentions "/set-goal", "set goal", or asks for a long-running task goal. Not for continuing an active goal, ordinary planning, or direct `/goal Read ...` handoffs.
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

Create a goal file from `$ARGUMENTS` or the current user request, then start `/goal` when the runtime exposes a goal tool. If no goal tool is callable, return a compact `/goal` handoff. When invoked from natural language such as `set goal`, still generate the goal file and handoff instead of executing the requested work.

For long-running or subagent-heavy work, translate the request into this schema: objective, criteria, evidence, scope, and any required cross-validation. Include subagent orchestration only when the request or proof requires independent checks.

## Goal Structure

The goal file is the condition that `/goal` evaluates. Produce these sections in this order. Omit empty sections.

1. Objective: one or two sentences naming the end state in user-visible or system-observable terms. Outcome, not steps.
   - Wrong: `refactor the reconnect loop`
   - Right: `the tunnel reconnects within 5s after a network blip, with exactly one active session in the server log`
2. Proof of completion: concrete checks a reviewer can execute and observe. Use test commands, log greps, curl invocations, UI states, file diffs, metrics, or explicit artifacts. Prefer deterministic gates over model judgment. Include the evidence the agent must surface because `/goal` evaluators judge the conversation, not hidden filesystem state.
3. Scope / constraints: include only files, modules, APIs, performance bounds, dependency limits, safety limits, compatibility requirements, subagent requirements, or cross-validation requirements that materially change what done means.
4. Out of scope: specific related work that must stay outside the goal. Omit this section when no boundary changes completion.

## Process

1. Read `$ARGUMENTS`; if no slash-command arguments are available, use the current user request as the input. If both are empty, ask for one sentence describing the desired end state.
2. Decide whether Objective and Proof can be drafted from the input. Do not treat length alone or missing repo matches as ambiguity.
3. If named symbols, files, modules, or behaviors would make the proof sharper, do one read-only grounding pass before asking:
   - one broad `rg` or `fd` for named symbols, files, modules, or behaviors
   - one targeted read of the most relevant file, doc, or call site
4. Ask one specific question only if the user request lacks an observable outcome or success evidence after optional grounding.
5. Draft the goal in the structure above. Bias toward specificity over length.
6. Write exactly the drafted goal text with one trailing newline to a markdown file under `${SET_GOAL_OUTPUT_DIR:-/tmp}`. Create the directory first. Use `YYYYMMDD-HHMMSS-<short-slug>.md`; make the slug lowercase ASCII, hyphenated, and outcome-based.
7. Read the file back and verify its content equals the drafted goal text after both strings are normalized to exactly one trailing newline. Verification is internal; do not output the verification result.
8. If verification fails, use the failure output shape below.
9. If verification succeeds, use the output contract below as the entire final assistant message.
10. Stop.

## Output Contract

After successful read-back verification, the final assistant message is an action or handoff, not a report. Do not print validation status, summaries, file paths, or instructions.

If a callable goal tool is available, invoke it with this argument:

```text
Read <absolute-file-path> and use its contents as the goal.
```

If no callable goal tool is available, including normal Claude Code skill execution, the entire assistant message must be exactly one fenced `text` block:

```text
/goal Read <absolute-file-path> and use its contents as the goal.
```

## Failure Output

If file writing or read-back verification fails, reply in this shape only:

```text
file write failed: <reason>
```

Then one fenced `markdown` block containing the goal body exactly once. Do not include a `/goal` command on failure.

## Anti-Patterns

- Steps disguised as goals: `1. read file X 2. modify Y 3. run tests`.
- Vague success: `make the code cleaner`, `improve performance`, `fix the bug`.
- Self-report validation: `the agent confirms the change works`.
- Subagent self-report as proof without master-side evidence.
- Generic obligations in Scope: `use the existing code style`, `don't break tests`.
- Padding for length.
- Putting `/goal`, copy instructions, markdown fences, or surrounding prose inside the goal file.
