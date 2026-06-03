---
name: deslop
description: Run a closing cleanup pass after AI-generated edits, especially after `/review --fix`, to remove generated-code artifacts and catch type-driven refactors that are wrong at runtime. Use when the user says "/deslop", "deslop", or asks for final generated-code cleanup before validation.
context: fork
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Bash(fd:*)
  - Read
  - Edit
---

Clean only the resolved diff for: $ARGUMENTS

## Resolve Scope

Build the cleanup scope from both sources, then de-duplicate paths:

1. Branch-relative diff against upstream when set, otherwise remote default branch when available. This catches committed but unmerged work.
2. Working-tree diff against `HEAD`, including staged and unstaged tracked files. This catches local edits made after the branch diff.

If branch-relative diff setup fails because no upstream or remote default branch is available, continue with the working-tree diff and report that branch scope was skipped. If a working-tree diff command fails, report the command and stderr summary before stopping. If both scopes are empty, report `no changes to review` and stop.

Do not edit a hunk unless it is inside the resolved diff and clearly belongs to the current AI-generated change. If ownership is unclear, report it as a candidate instead of changing it.

## Cleanup Checks

Remove or rewrite only when the current diff introduced the issue:

- comments a human maintainer would not add: restating adjacent code, repeating what a nearby file or the cited source already states, or styling inconsistently with nearby files
- unnecessary defensive checks, broad `try`/`catch`, or fallbacks for impossible states
- casts to `any` or similar escapes that hide a type problem
- helpers, config switches, or compatibility paths that only rename one caller
- wrappers that don't add what they claim: memoization or caching around already-stable or already-cheap values, normalization of already-clean data, conversions to a form the input is already in
- orphans created by the current diff: unused imports, unreferenced variables or types, unreachable functions, exports no longer used by any caller
- style that conflicts with the surrounding file and is limited to the edited hunk

## Type-Driven Refactor Check

AI edits often trust type signatures over runtime data. For each diff hunk that removes a guard, fallback, optional chain, derived value, or normalization because the type appears stricter:

1. Inspect the actual data source when locally available: fixtures, JSON samples, generated API output, schema comments, or adjacent parsing tests.
2. Keep the refactor only when runtime evidence matches the type contract.
3. If runtime data violates the type contract, restore the guard or derivation and add a short comment naming the source of dirty data.
4. If runtime evidence is unavailable, report a manual verification candidate instead of guessing.

## Validation

Discover the cheapest existing validation from local instructions, `package.json`, `Makefile`, `justfile`, task config, or adjacent tests. Run the command, scoped to changed files when the tool supports it. Request permission if the tool policy does not pre-approve it. Do not run dev/start/serve commands unless the user explicitly asked for that environment.

If no validation command is available, say exactly what was searched.

## Output

Return:

- Changed: files and one-line reason for each edit, or `none`
- Candidates left: ownership-unclear or runtime-unverified items
- Validation: command and pass/fail, or skipped reason
