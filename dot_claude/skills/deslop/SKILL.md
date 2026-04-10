---
name: deslop
description: Remove AI-generated code slop from the current branch. Use as a finishing pass after code review — when user says "收尾", "clean up", or asks to run simplify + deslop together. Run sequentially after /simplify, not in parallel.
context: fork
allowed-tools:
  - Bash(git:*)
  - Read
  - Edit
  - Grep
  - Glob
---

## Task

Get the diff to review via `git diff $(git symbolic-ref refs/remotes/origin/HEAD)` — this captures both committed and uncommitted changes against the remote default branch. If the diff is empty, report "no changes to review" and exit. Remove all AI-generated slop found in the diff.

## What to remove

- Extra comments a human wouldn't add or inconsistent with the rest of the file
- Unnecessary defensive checks or try/catch blocks (especially from trusted/validated code paths)
- Fallbacks for scenarios that can't happen or are already guaranteed by upstream code
- Casts to `any` to work around type issues
- Any style inconsistent with the surrounding file

## Output

Report a 1-3 sentence summary of changes at the end.
