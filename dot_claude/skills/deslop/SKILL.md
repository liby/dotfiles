---
name: deslop
description: Closing-pass cleanup after AI edits. Removes generated code slop and catches type-driven refactors that broke runtime behavior. Closing step in the /review -> /simplify -> /deslop chain. Use when the user says "/deslop" or "deslop".
context: fork
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Read
  - Edit
---

## Identify changes

Resolve the diff to review using the first non-empty result from this order:

1. **Branch-relative**: against the upstream branch if set (`git diff @{upstream}...HEAD`), else against the remote default branch (`git diff $(git symbolic-ref --short refs/remotes/origin/HEAD)...HEAD`). Captures committed-but-not-merged work.
2. **Working-tree (incl. staged)**: `git diff HEAD`. Catches uncommitted local edits when the branch hasn't diverged yet (common when the user just edited files in the default branch without committing).

If both are empty, report "no changes to review" and exit. Otherwise run both cleanup sections below on the resolved diff.

## Remove slop

- Extra comments a human wouldn't add or inconsistent with the rest of the file
- Unnecessary defensive checks or try/catch blocks (especially from trusted/validated code paths)
- Fallbacks for scenarios that can't happen or are already guaranteed by upstream code
- Casts to `any` to work around type issues
- Any style inconsistent with the surrounding file

## Verify type-driven refactors

AI tools (including /simplify) extract their model of "what this field contains" from the type signature, not from runtime data. When the data violates the type contract, the AI's "fix" can be runtime-wrong: swapping a derived value for a typed field, removing a null check the type "proves" unneeded, deleting a fallback the type marks required, stripping optional chaining after narrowing, trusting a generated API-response type.

**For any such change in the diff, sample the actual data before keeping it**: grep fixtures, open the JSON the type maps to, or check a recent API response. If the field is missing, empty, non-unique, or otherwise violates the type contract, revert the change and add a code comment naming why the original guard or derivation is required (so the next /simplify pass doesn't undo the revert).

## Output

Report a 1-3 sentence summary of changes from each section at the end.
