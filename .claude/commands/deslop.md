---
description: Remove AI-generated code slop from the current branch
allowed-tools:
  - Bash
  - Read
  - Edit
  - Grep
  - Glob
---

# Remove AI Code Slop

Check the diff against the default branch (use !`git symbolic-ref refs/remotes/origin/HEAD` to detect main/master), and remove all AI generated slop introduced in this branch.

This includes:
- Extra comments that a human wouldn't add or is inconsistent with the rest of the file
- Extra defensive checks or try/catch blocks that are abnormal for that area of the codebase (especially if called by trusted / validated codepaths)
- Unnecessary fallbacks for scenarios that can't happen or are already guaranteed by upstream code
- Casts to `any` to get around type issues
- Any other style that is inconsistent with the file

Report at the end with only a 1-3 sentence summary of what you changed.
