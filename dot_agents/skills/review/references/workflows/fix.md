# Fix Workflow

Load only when `--fix` was requested, after the read-only review has accepted findings, and before mutation. `--fix` does not change the Finding Bar.

Run fixes in a fresh write-capable fix-orchestrator subagent against a local writable checkout. Its frontier contains only accepted findings and regressions it introduces; a host-only review remains report-only.

## Inputs And Scope

Pass the writable repo root, review scope/base, repo instructions, and validation commands. For each fixable finding, pass severity, `path:line`, provenance, exact diff contribution, root cause, reachable trigger, decisive evidence, consequence, fix direction, remedy prerequisites, and direct dependents. Also pass absolute paths to `SKILL.md` and this file, requiring the fixer to read both completely before mutation. If either is inaccessible in its runtime, inline the Finding Bar plus this workflow's scope, baseline, secret-classifier, mutation, and stop rules. Do not pass dropped, manual, speculative, weak, repeated, or raw second-opinion content.

Before editing, create a NUL-delimited scope file containing only frontier paths and direct dependents the fixes may require. Exclude unrelated dirty files. Run the helper, which enforces the secret-path classifier and creates a scoped Git baseline:

```bash
REVIEW_SKILL_FILE="<absolute SKILL.md path passed to this fixer>"
REVIEW_SKILL_DIR="${REVIEW_SKILL_FILE%/SKILL.md}"
FIX_SCOPE_FILE=$(mktemp)
# Write allowed repo-relative paths to FIX_SCOPE_FILE as NUL-delimited records.
BASELINE=$(bash "$REVIEW_SKILL_DIR/scripts/review-fix-baseline.sh" "$FIX_SCOPE_FILE") || exit $?
```

Do not use `git stash create` or snapshot the whole working tree. Add an untracked file only when a frontier item cites it and the path classifier accepts it.

## Triage And Edit

Classify each item once:

- `fix`: evidence supports the root cause and remedy.
- `rewrite`: the finding is real but its proposed remedy is wrong or incomplete.
- `manual`: product judgment, runtime evidence, credentials, destructive action, or external access is required.
- `drop`: the trigger no longer applies or fails the Finding Bar.

P1 and P2 items may mutate automatically. P3 may mutate only when the user requested it, it blocks P1/P2 validation, or the fixer introduced it.

Fix the root cause and direct dependents inside the baseline scope. Do not perform broad refactors, formatting sweeps, dependency swaps, or cleanup unrelated to a frontier item. Stop before touching a path outside the scope and report the required expansion.

## Validate And Re-Review

Run the cheapest validation that exercises each fix and name any remaining manual observation. Re-review changed paths, direct dependents, generated artifacts, and validation output.

Classify the result as `resolved`, `still-open`, `regression-from-fix`, `new-real`, or `manual`. A `new-real` item must independently pass the Finding Bar and remain inside the baseline scope. Only `still-open`, `regression-from-fix`, and `new-real` may re-enter mutation.

Stop when all fixable items are resolved and validated, the next action crosses scope or authority, a candidate adds no new evidence, or the same strategy fails twice.

## Return

Report applied fixes or rewrites with citations, unresolved or manual items and reasons, validation commands and verdicts, the baseline id, and any scope stop.
