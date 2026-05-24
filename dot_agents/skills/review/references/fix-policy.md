# Fix Policy

`--fix` runs after normal review. It does not change what counts as a finding.

## Contract

- Review phase is read-only.
- Fix phase runs in a fresh write-capable fix-orchestrator subagent.
- Fixes apply only to a local writable checkout.
- Remote MR/PR worktrees are report-only.
- The accepted finding set freezes before the first edit.
- The fix-orchestrator edits only to address frozen accepted findings and regressions it introduced.

## Inputs

Pass:

- repo root
- review scope and base
- frozen accepted findings with severity, `path:line`, root cause, allowed touch paths or direct dependents, and validation command or manual gap
- validation commands discovered during review
- local instructions already read

Do not pass skipped, dropped, manual-verification, pre-existing, adjacent, post-fix new findings, or raw delegate transcript content into the mutating context. If transcript evidence is needed, pass only the bounded citation or command result.

## Secret Path Denylist

Before any baseline, snapshot, or edit, list the paths the fix-orchestrator may touch. Stop without reading or adding a path when it matches:

- `.env*` or any path segment under `.env*`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.crt`, `*.cer`
- `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`, or `.ssh/`
- names containing `credential`, `secret`, or `token`, case-insensitive
- `*.history` or `*.log`

## Triage

Classify each accepted finding before editing:

- `fix`: root cause is clear and local evidence is sufficient.
- `rewrite`: finding is real, but the suggested fix is partly wrong.
- `manual`: runtime evidence, product judgment, destructive action, credentials, or external access is required.
- `drop`: trigger path no longer applies in the current checkout.

P1 and P2 findings may enter automatic mutation. P3 findings enter automatic mutation only when the user explicitly asked, they block P1 or P2 validation, or they are a regression from the fix. Drop P3 polish, broad cleanup, and unrelated maintainability suggestions unless they block a frozen accepted finding.

## Baseline

Before the first edit, write `$FIX_SCOPE_FILE` as NUL-delimited repo-relative accepted-finding paths or direct dependents. Then run:

```bash
REVIEW_SKILL_DIR="${REVIEW_SKILL_DIR:-$HOME/.claude/skills/review}"
BASELINE_HELPER="$REVIEW_SKILL_DIR/scripts/review-fix-baseline.sh"
[ -f "$BASELINE_HELPER" ] || BASELINE_HELPER="$REVIEW_SKILL_DIR/scripts/executable_review-fix-baseline.sh"
BASELINE=$(bash "$BASELINE_HELPER" "$FIX_SCOPE_FILE") || exit $?
```

The script snapshots only fix-scope paths and prints the baseline id. Do not use `git stash create`. Do not snapshot all tracked dirty files. Do not add untracked files unless the accepted finding cites them, the user asked to include them, and the denylist has no match.

## Edit Rules

- Re-read cited files and direct dependents.
- Fix root cause plus direct dependents.
- Prefer loud failure over silent fallback when the invariant should hold.
- Batch findings only when they share the same root cause and no unrelated module is touched.
- Clean only orphans introduced by the fix.
- Do not run broad refactors, format sweeps, dependency swaps, or cleanup skills unless an accepted finding requires them.

## Validation

Run the cheapest existing validation that exercises the changed path. Do not run dev/start/serve commands unless the user explicitly requested that environment.

If validation cannot cover the finding, state the remaining manual observation.

## Re-Review

After edits, re-review changed files, direct dependents, touched generated artifacts, and validation output. If `--cx` was used and another mutation round depends on more evidence, the main session may rerun `/review --cx` against the same original scope. The fix-orchestrator must not broaden the review target.

Classify post-fix findings:

- `accepted-still-open`: accepted finding remains after the fix attempt.
- `regression-from-fix`: introduced by the fix.
- `new-preexisting`: existed before the fix but was not accepted.
- `adjacent-new`: noticed nearby but not needed for the accepted finding.

Only `accepted-still-open` and `regression-from-fix` can trigger automatic mutation. `regression-from-fix` is the fixer's rollback responsibility, not a new accepted finding. Report `new-preexisting` and `adjacent-new` without fixing them.

## Termination

Stop when:

- all `fix` and `rewrite` items are resolved and validation has run,
- the next change would cross the frozen accepted finding boundary,
- the next step requires runtime evidence, product judgment, credentials, destructive action, or external access,
- no local writable checkout is available,
- the same finding fails twice with the same strategy,
- or the round budget is reached.

Default round budget is 3. One round means triage, edit, validation, and re-review of changed files plus direct dependents. Reuse the same fix-orchestrator across rounds so baseline, diff, and validation history stay visible. Start a replacement only after scope drift, state confusion, context contamination, or crash; pass the same frozen set and remaining budget.

Return:

- Applied Fix: count and citations
- Applied Rewrite: count and citations
- Drop: count and reasons
- Manual: count, citations, and required observation
- Not fixed: citations and reason
- Observed outside frozen set: severity, citation, and separate follow-up direction
- Validation: commands and verdicts
- Baseline: snapshot id when used
