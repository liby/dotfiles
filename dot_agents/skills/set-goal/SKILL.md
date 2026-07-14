---
name: set-goal
description: Turn an explicitly requested task into an outcome-based, verifiable goal file, then start it through a callable goal tool or emit an exact `/goal` paste handoff. Use when the user invokes `/set-goal`, asks to set, create, or start a goal, or explicitly requests long-running goal mode. Not for discussing goal-setting, continuing an active goal, ordinary planning, or direct `/goal Read ...` handoffs.
argument-hint: "[brief task description]"
allowed-tools:
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(date:*)
  - Bash(mkdir:*)
  - Read
  - Write
---

Create a goal file from the slash-command arguments or accompanying request. A direct `/set-goal` invocation always runs this workflow, even when the requested task is to audit or edit the skill itself. Merely quoting or mentioning `set goal` does not invoke it. By default, write the file and follow the Output Contract before starting the requested work. If the user explicitly requires research or requirements gathering to finish before the Goal is drafted, created, or started, first use the deferred read-only grounding path in Process. This delays Goal creation, not skill invocation.

Translate the request into the Goal Structure below. Include subagent orchestration only when the request or proof requires independent checks.

## Goal Structure

The goal file is the condition that `/goal` evaluates. Map every material user condition to Objective, Proof, Scope, or Out of scope; a condition is material when omitting it could change acceptance, authority, safety, compatibility, or required cross-validation. Produce these sections in this order. Omit empty sections.

1. Objective: one or two sentences naming the end state in user-visible or system-observable terms. Outcome, not steps.
   - Wrong: `refactor the reconnect loop`
   - Right: `the tunnel reconnects within 5s after a network blip, with exactly one active session in the server log`
2. Proof of completion: concrete checks a reviewer can execute and observe. Each item names the material completion claim, check, and expected observation. Require fresh evidence to be surfaced after the final relevant mutation because `/goal` evaluators judge the conversation, not hidden filesystem state; rerun any check a later change could invalidate. Use test commands, log greps, curl invocations, UI states, file diffs, metrics, or explicit artifacts. Prefer deterministic gates over model judgment. Cover every material completion claim, not every work item; require item-by-item evidence only when the user or a source of truth defines a bounded set whose complete coverage changes acceptance. For UI, connector, external-service, or production-runtime goals, require the final user-visible state and the source-owned state that can overwrite it; if the current environment cannot expose that state, require manual verification and name the exact observation needed.
3. Scope / constraints: include only files, modules, APIs, performance bounds, dependency limits, safety limits, compatibility requirements, subagent requirements, or cross-validation requirements that materially change what done means.
4. Out of scope: specific related work that must stay outside the goal. Omit this section when no boundary changes completion.

## Iterative Evaluator Goals

When the request asks to repeat an evaluator, reviewer, auditor, cleanup pass, verifier, or critique until clean, empty, or issue-free, treat its output as evidence for a live issue frontier, not the objective. Completion is an empty accepted frontier with current evaluator evidence adding no new trigger path; another pass requires a later mutation or new external evidence.

In the goal file, require:

- the named evaluator or skill that owns issue classification
- a live issue frontier with each accepted item carrying a trigger path, evidence, impact, and owner
- each mutation round to report how the frontier changed: resolved, newly discovered with new trigger evidence, regression from the last fix, repeated prior issue, speculative claim without new evidence, or manual/runtime/product gap
- progress evidence after each mutation: validation output, source evidence, runtime evidence, or explicit manual gap
- a stop-and-report condition when the loop repeats the same root cause, the next fix would undo a prior fix, new work is mostly caused by the last fix, or the evaluator keeps producing claims without new evidence

Do not require a hard round budget unless the user asks for one or the executor skill owns a runtime safety cap. Do not freeze the issue set at the first pass. New findings can enter when they add a new trigger path, source-of-truth evidence, or a real regression. If a named evaluator skill has a loop or fix policy, reference that skill as the owner instead of restating its full rules.

## Process

1. Use slash-command arguments when the runtime supplies them; otherwise use the user's accompanying request. Do not treat a literal `$ARGUMENTS` token as input. If both are empty, ask for one sentence describing the desired end state.
2. Use the deferred pre-Goal grounding path only when the user explicitly orders requirements gathering or research to finish before the Goal is drafted, created, or started. Do not infer it because the Goal itself is to research, investigate, discover, or gather requirements; keep that work inside the Goal.
3. In the deferred path, use available read-only tools and applicable research skills only to resolve acceptance questions derived from the request. Follow a source only while it directly informs an unresolved acceptance question needed to state the Objective, every material constraint, or Proof. Stop when every such question has current source-of-truth evidence or is recorded in Proof or Scope as an exact manual check or unverified gap. Do not mutate state or execute the Goal. Map only material findings into the existing Goal Structure as drafting input, not completion evidence; do not add a research section or dossier. Record unavailable, stale, or conflicting material evidence as an unverified gap in Proof or Scope. For mutable sources, add a completion check that rereads them after the final relevant mutation.
4. On the immediate path, decide whether Objective and Proof can be drafted from the input. Do not treat length alone or missing repo matches as ambiguity.
5. On the immediate path, if named symbols, files, modules, or behaviors would make the proof sharper, do one read-only grounding pass before asking: one search-only `rg` or `fd` lookup, then read the most relevant file, doc, or call site. Do not use preprocessors, exec actions, command substitution, or shell operators, and do not mutate state during grounding.
6. Ask at most one specific question. In the deferred path, ask only if an unresolved choice would materially change acceptance; in the immediate path, ask only if the user request lacks an observable outcome or success evidence after optional grounding.
7. For iterative evaluator requests, apply Iterative Evaluator Goals before drafting Proof of completion and Scope.
8. Draft the goal in the structure above. Bias toward specificity over length.
9. Resolve `${SET_GOAL_OUTPUT_DIR:-/tmp}` and the resulting file path to absolute paths, create the directory, then write exactly the drafted goal text with one trailing newline. Use `YYYYMMDD-HHMMSS-<short-slug>.md`; make the slug lowercase ASCII, hyphenated, and outcome-based.
10. Read the file back and verify its content equals the drafted goal text after both strings are normalized to exactly one trailing newline. Verification is internal; do not output the verification result.
11. If verification fails, use the failure output shape below.
12. If verification succeeds, follow the output contract below.
13. Stop after the paste handoff; the callable-tool branch continues executing the goal instead.

## Output Contract

After read-back verification succeeds, emit either a callable goal tool invocation or a two-line paste handoff. No summaries, file path explanations, or additional commentary around it.

If the runtime exposes a callable goal tool such as `create_goal` or equivalent, invoke it with the argument `Read <absolute-file-path> and use its contents as the goal.` Pass only this short pointer, never the drafted goal body: goal objective fields can be length-capped. If creation reports an unfinished goal, report the conflict once and include status output only when a callable status tool is exposed; do not retry. For any other creation failure, report the non-sensitive error once and stop without blind retries. After the call succeeds, continue executing the goal in the same thread.

Otherwise, when the harness exposes `/goal` only as user input and has no callable goal tool, the entire assistant message is exactly two paragraphs separated by a blank line. The first paragraph is the literal string `Run next:` and the second is `/goal Read <absolute-file-path> before acting. Use its contents as the goal. Completion requires every Proof of completion item in that file to have current evidence surfaced in this conversation and every material constraint to hold. Reading or restating the file is not completion.` Nothing else appears before, between, or after these paragraphs.

## Failure Output

If file writing or read-back verification fails, output exactly `file write failed: <reason>`, one blank line, then the goal body. Do not include a `/goal` command.

## Anti-Patterns

- Steps disguised as goals: `1. read file X 2. modify Y 3. run tests`.
- Vague success: `make the code cleaner`, `improve performance`, `fix the bug`.
- Self-report validation: `the agent confirms the change works`.
- Subagent self-report as proof without master-side evidence.
- Generic obligations in Scope: `use the existing code style`, `don't break tests`.
- A proof that cannot be phrased as an observable prediction (command output, log line, UI state): that is a vibe, not a gate. Sharpen it or mark it manual verification.
- Padding for length or exhaustive enumeration not required by acceptance.
- Putting `/goal` or surrounding prose inside the goal file.
