# Auto-Fix Loop (`--fix`)

When `--fix` is passed, auto-apply fixes and loop until the review is clean, then run finishing passes and summarize.

**Loop convergence means the chosen reviewer found no Keep findings in the latest sample.** It is not proof of feature correctness — the reviewer has inherent sampling variance and framing limits, and cross-file invariants are the category most likely to slip through.

## Setup

Main session, once before round 1 — `/review` re-invocations detect the baseline file and must skip this branch:

```bash
BASELINE_FILE="$(git rev-parse --git-dir)/review-fix-baseline"
if [ ! -f "$BASELINE_FILE" ]; then
  BASELINE=$(git stash create); [ -z "$BASELINE" ] && BASELINE=$(git rev-parse HEAD)
  echo "$BASELINE" > "$BASELINE_FILE"
fi
```

The baseline isolates the fix loop's changes from any pre-existing uncommitted work.

## Loop

1. Report findings from this round.
2. Apply the recommended fix direction directly to the code in the main session.
3. Re-invoke `/review` with the same flags (including `--fix`) to verify. **This must be the same whole-feature review as Round 1 — same flags, same `--base` / `--scope`, no custom prompt, no narrowed scope, no "verify the fix from Round N-1" framing.** For `--cx`, this means the fixed `task` prompt defined in [delegation.md](delegation.md), byte-for-byte identical every round. Scope narrowing between rounds is how cross-file invariants slip through: each round must re-run the same broad sweep so a round-N fix that breaks a round-K invariant is still caught.
4. Loop until the review reports no Keep findings (see [delegation.md](delegation.md) for the Keep / Skip / Rewrite classification). A real Keep is a real Keep regardless of severity. Track each Keep across rounds by identity `(file path, line range, title)`, not by raw count — `{A}→{B}→{A}` oscillation keeps count at 1, and `{A,B}→{B,C}→{C,D}` sliding keeps count at 2, but neither is progress.

   Stall conditions (any one stops the loop early):
   - **Oscillation**: a finding retired in an earlier round reappears (same identity) in a later round — a fix re-introduced something a prior fix cleared.
   - **No forward progress**: two consecutive rounds where the prior round's Keep set loses zero members in the current round — the loop is treading water or sliding.
   - **Hard backstop**: 10 total rounds. Past that, the feature needs a human design pass, not more loop iterations.

   On any stall, abort and hand off: report the outstanding Keep findings with file/line evidence, preserve `$BASELINE_FILE` **and the worktree** so the user can inspect partial progress via `git diff "$(cat "$BASELINE_FILE")"`, and do not proceed to finishing passes or the summary — both assume clean convergence.
5. Run `/simplify`, then `/deslop`, as finishing passes (those skills auto-fix by design).
6. Summarize with `git diff "$(cat "$BASELINE_FILE")"`, then clean up: `rm "$BASELINE_FILE"` and `git worktree remove "$TMPDIR/review-<mr-number>"`. The baseline file is the source of truth and survives compaction — do not rely on session memory for what was changed.

## Composition with `--cc` / `--cx`

Delegation and `--fix` are orthogonal: delegation controls *who* reviews; `--fix` controls *what the main session does after the review returns*. All autofix state (baseline, loop, finishing passes, summary) lives in the main session.

Per [delegation.md](delegation.md), the delegate receives `/review` with all flags stripped — it reports findings and exits, never drives the loop. The flow is symmetric regardless of which model is delegated to:

1. Main session creates the baseline (setup above, idempotent across rounds).
2. Main session delegates one review round to the chosen reviewer (Codex for `--cx`, Claude Code for `--cc`); the delegate returns findings.
3. Main session applies fixes, then re-invokes `/review` with the same flags → back to step 2. The re-invocation goes through the same delegation path, not a custom prompt.
4. On a clean round (no Keep findings), main session runs `/simplify` then `/deslop` directly (finishing passes are not delegated).
5. Main session diffs against the baseline, summarizes, then removes both the baseline file and the review worktree.
