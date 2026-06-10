# Fix Policy

`--fix` runs after normal review. It does not change what counts as a finding.

## Contract

- Review phase is read-only.
- Fix phase runs in a fresh write-capable fix-orchestrator subagent.
- Fixes apply only to a local writable checkout.
- Remote MR/PR worktrees are report-only.
- Initial accepted findings seed a live review frontier.
- The fix-orchestrator edits only unresolved frontier items classified as `fix` or `rewrite`, plus regressions it introduced.
- A new finding can enter the frontier only when it has a new trigger path, source-of-truth evidence, realistic impact, and owner, or when it is a real regression from the fix.

## Inputs

Pass:

- repo root: the real writable working tree from `git rev-parse --show-toplevel`, never `$REVIEW_CWD` (a `--cx` transient review worktree is read-only and may be removed after review)
- review scope and base
- initial accepted findings with severity, `path:line`, root cause, allowed touch paths or direct dependents, and validation command or manual gap
- validation commands discovered during review
- local instructions already read

Do not pass skipped, dropped, manual-verification, repeated, speculative, or raw delegate transcript content into the mutating context. If transcript evidence is needed, pass only the bounded citation or command result.

## Secret Path Denylist

Before any baseline, snapshot, or edit, list the paths the fix-orchestrator may touch. Stop without reading or adding a path when it matches:

- `.env*` or any path segment under `.env*`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.crt`, `*.cer`
- `authorized_keys` or `known_hosts`
- `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`, or `.ssh/`
- names containing `credential`, `secret`, or `token`, case-insensitive
- `*.history` or `*.log`

The machine copy in `scripts/_lib.sh` is authoritative for `--cx` script paths and is a superset (adds log directories and `.*_history`); update both together.

## Triage

Classify each frontier item before editing:

- `fix`: root cause is clear and local evidence is sufficient.
- `rewrite`: finding is real, but the suggested fix is partly wrong.
- `manual`: runtime evidence, product judgment, destructive action, credentials, or external access is required.
- `drop`: trigger path no longer applies in the current checkout.

P1 and P2 findings may enter automatic mutation. P3 findings enter automatic mutation only when the user explicitly asked, they block P1 or P2 validation, or they are a regression from the fix. Drop P3 polish, broad cleanup, and unrelated maintainability suggestions unless they block an unresolved frontier item.

A post-fix candidate can enter as `new-real` only when it has a new trigger path, new evidence, realistic impact, and belongs to the original review scope. Reworded prior issues, candidates without new evidence, and broad adjacent cleanup stay out of the mutating frontier.

## Baseline

Before the first edit, write `$FIX_SCOPE_FILE` as NUL-delimited repo-relative paths the current review scope permits the fixer to touch. Include initial frontier paths and direct dependents likely required by fixes. Do not include unrelated dirty files. Then run:

```bash
REVIEW_SKILL_DIR="${REVIEW_SKILL_DIR:-$HOME/.agents/skills/review}"
BASELINE_HELPER="$REVIEW_SKILL_DIR/scripts/review-fix-baseline.sh"
BASELINE=$(bash "$BASELINE_HELPER" "$FIX_SCOPE_FILE") || exit $?
```

The script snapshots only fix-scope paths and prints the baseline id. Do not use `git stash create`. Do not snapshot all tracked dirty files. Do not add untracked files unless the frontier item cites them, the user asked to include them, and the denylist has no match.

## Edit Rules

- Re-read cited files and direct dependents.
- Fix root cause plus direct dependents.
- Prefer loud failure over silent fallback when the invariant should hold.
- Batch findings only when they share the same root cause and no unrelated module is touched.
- Clean only orphans introduced by the fix.
- Do not run broad refactors, format sweeps, dependency swaps, or cleanup skills unless a frontier item requires them.
- If a later accepted item needs a path outside the baseline fix scope, report it as scope expansion and stop before editing that path unless the user confirms.

## Validation

Run the cheapest existing validation that exercises the changed path. Do not run dev/start/serve commands unless the user explicitly requested that environment.

If validation cannot cover the finding, state the remaining manual observation.

## Re-Review

After edits, re-review changed files, direct dependents, touched generated artifacts, and validation output. If `--cx` was used and another mutation round depends on more evidence, the main session may rerun `/review --cx` against the same original scope. The fix-orchestrator must not broaden the review target.

Classify post-fix findings:

- `resolved`: frontier item is fixed and covered by validation or named manual evidence.
- `accepted-still-open`: accepted finding remains after the fix attempt.
- `regression-from-fix`: introduced by the fix.
- `new-real`: newly discovered issue in the original review scope with a new trigger path, source-of-truth evidence, realistic impact, and owner.
- `repeated-or-reworded`: same root cause or same trigger path without new evidence.
- `speculative`: lacks observed trigger, impact, source evidence, or reachable path.
- `manual`: requires runtime evidence, product judgment, credentials, destructive action, or external access.

Only `accepted-still-open`, `new-real`, and `regression-from-fix` can trigger automatic mutation. `new-real` must stay inside the baseline fix scope. `regression-from-fix` is the fixer's rollback or repair responsibility, not proof that the goal expanded. Report `repeated-or-reworded`, `speculative`, and `manual` without fixing them.

## Termination

Stop when:

- all `fix` and `rewrite` items are resolved and validation has run,
- the next change would cross the baseline fix scope,
- the next step requires runtime evidence, product judgment, credentials, destructive action, or external access,
- no local writable checkout is available,
- the same root cause, trigger path, or fix area repeats without new evidence,
- the next change would undo a prior fix without a new source-of-truth reason,
- new accepted work is mostly regressions introduced by the current fix loop,
- the same strategy fails twice,
- or a user-provided, harness-provided, or executor-owned safety cap is reached.

Do not invent a numeric round budget. Use a numeric cap only when the user, harness, or executor skill supplies one. One round means triage, edit, validation, and re-review of changed files plus direct dependents. Reuse the same fix-orchestrator across rounds so baseline, diff, validation history, and frontier changes stay visible. Start a replacement only after scope drift, state confusion, context contamination, or crash; pass the same frontier, baseline id, and prior round summary.

Return:

- Applied Fix: count and citations
- Applied Rewrite: count and citations
- Drop: count and reasons
- Manual: count, citations, and required observation
- Not fixed: citations and reason
- Frontier: resolved, new-real, regression-from-fix, repeated-or-reworded, speculative, manual, and still-open counts
- Progress: what changed since the previous round, with evidence
- Validation: commands and verdicts
- Baseline: snapshot id when used
