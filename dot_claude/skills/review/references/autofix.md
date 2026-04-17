# Auto-Fix Loop (`--fix`)

When `--fix` is passed, auto-apply fixes and loop until the review is clean, then run finishing passes and summarize.

## Setup

Main session, once before round 1 — `/review` re-invocations detect the baseline file and must skip this branch:

```bash
BASELINE_FILE="$(git rev-parse --git-dir)/review-fix-baseline"
if [ ! -f "$BASELINE_FILE" ]; then
  BASELINE=$(git stash create); [ -z "$BASELINE" ] && BASELINE=$(git rev-parse HEAD)
  echo "$BASELINE" > "$BASELINE_FILE"
fi
```

`git stash create` captures working tree + index as a dangling commit without touching either. The baseline isolates the fix loop's changes from any pre-existing uncommitted work.

## Loop

1. Report findings from this round.
2. Apply the recommended fix direction directly to the code in the main session.
3. Re-invoke `/review` with the same flags (including `--fix`) to verify.
4. Loop until the review reports no actionable findings.
5. Run `/simplify`, then `/deslop`, as finishing passes (those skills auto-fix by design).
6. Summarize with `git diff "$(cat "$BASELINE_FILE")"`, then `rm "$BASELINE_FILE"`. The baseline file is the source of truth and survives compaction — do not rely on session memory for what was changed.

## Composition with `--cc` / `--cx`

Delegation and `--fix` are orthogonal: delegation controls *who* reviews; `--fix` controls *what the main session does after the review returns*. All autofix state (baseline, loop, finishing passes, summary) lives in the main session.

Per [delegation.md](delegation.md), the delegate receives `/review` with all flags stripped — it reports findings and exits, never drives the loop. The flow is symmetric regardless of which model is delegated to:

1. Main session creates the baseline (setup above, idempotent across rounds).
2. Main session delegates one review round to the chosen reviewer (Codex for `--cx`, Claude Code for `--cc`); the delegate returns findings.
3. Main session applies fixes, then re-invokes `/review` with the same flags → back to step 2.
4. On a clean round, main session runs `/simplify` then `/deslop` directly (finishing passes are not delegated).
5. Main session diffs against the baseline and summarizes.
