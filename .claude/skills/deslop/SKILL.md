---
name: deslop
description: Remove AI-generated code slop from the current branch. Use when the user says "deslop", "remove slop", or asks to clean up AI-generated code.
context: fork
allowed-tools:
  - Bash(git symbolic-ref:*)
  - Bash
  - Read
  - Edit
  - Grep
  - Glob
---

## Task

Check the diff against the default branch (use `git symbolic-ref refs/remotes/origin/HEAD` to detect main/master) and remove all AI-generated slop introduced in this branch.

## What to remove

- Extra comments a human wouldn't add or inconsistent with the rest of the file
- Unnecessary defensive checks or try/catch blocks (especially from trusted/validated code paths)
- Fallbacks for scenarios that can't happen or are already guaranteed by upstream code
- Casts to `any` to work around type issues
- Any style inconsistent with the surrounding file

## Output

Report a 1-3 sentence summary of changes at the end.
