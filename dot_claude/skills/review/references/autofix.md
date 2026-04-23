# Auto-Fix Loop (`--fix`)

When `--fix` is passed, auto-apply fixes and loop until the review is clean, then run finishing passes and summarize.

## Setup

Main session, once before round 1 — `/review` re-invocations detect the baseline file and must skip this branch:

```bash
BASELINE_FILE="$(git rev-parse --git-dir)/review-fix-baseline"
if [ ! -f "$BASELINE_FILE" ]; then
  # Snapshot the full working-tree state (tracked + staged + untracked) through a
  # temp index so the baseline is a self-contained commit we can diff against at
  # termination. `git stash create [-u]` doesn't work here: without -u it drops
  # untracked, and with -u it puts untracked on a side parent whose content is
  # invisible when diffing the primary commit directly.
  TMP_INDEX=$(mktemp)
  GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD
  GIT_INDEX_FILE="$TMP_INDEX" git add -A
  BASELINE_TREE=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree)
  rm "$TMP_INDEX"
  BASELINE=$(git commit-tree "$BASELINE_TREE" -p HEAD -m "review-fix-baseline")
  echo "$BASELINE" > "$BASELINE_FILE"
fi
```

The baseline is a detached commit object capturing the full working-tree state at round-1 entry. The fix loop's changes are anything that diverges from it at termination — including modifications to pre-existing untracked files and net-new files autofix created.

## Loop

`--fix` is local-mode only (see SKILL.md). It wraps a single review in an apply-fix-and-re-review loop; it does not change what a single review does.

The per-round flow:

1. Run the review against the user's live checkout (no per-round worktree rebuild — `--fix` reads files directly each round, which naturally reflects the previous round's applied fixes). Every round uses the same invocation: same flags, no custom prompt, no "verify the fix from Round N-1" framing. Scope narrowing between rounds is how cross-file invariants slip through — a round-N fix that breaks a round-K invariant only surfaces if the same broad sweep runs again.
    - Plain `--fix` = main session reviews directly, reading the checkout with the Read tool and Bash-driven search (`rg`/`ugrep`, `fd`/`bfs`) per SKILL.md.
    - `--fix --cx` = main session invokes [`scripts/codex-review.sh`](../scripts/codex-review.sh) with the same `--base` / `--remote` / `--platform` flags every round and merges both Codex paths per [delegation.md](delegation.md). The script is idempotent given unchanged HEAD / upstream / origin/HEAD.
2. Apply recommended fixes directly to the checkout in the main session.
3. Run existing validation commands (tests, lint, typecheck) if cheap. Required for `--cx`: the broad path is `read-only` sandboxed and the opinionated path's validation only runs inside a transient snapshot worktree, so neither can verify fixes against the user's real checkout. Main-session validation after applying Keep fixes is load-bearing.
4. If the merged Keep set is non-empty → next round (step 1). If empty → convergence, follow [Termination](#termination).

## Termination

At termination (either path below) run the summary diff via the helper below. It builds a matching post-fix snapshot through its own temp index, so `git diff` compares two self-contained commits — no `git add -A` on the user's real index, no pre-existing untracked pollution, and any autofix changes to pre-existing untracked files show up too:

```bash
summary_diff() {
  local baseline_file="$1"
  local baseline_sha
  baseline_sha=$(cat "$baseline_file")
  local tmp_index
  tmp_index=$(mktemp)
  GIT_INDEX_FILE="$tmp_index" git read-tree HEAD
  GIT_INDEX_FILE="$tmp_index" git add -A
  local final_tree
  final_tree=$(GIT_INDEX_FILE="$tmp_index" git write-tree)
  rm "$tmp_index"
  local final_sha
  final_sha=$(git commit-tree "$final_tree" -p "$baseline_sha" -m "review-fix-final")
  git diff "$baseline_sha" "$final_sha"
  rm -f "$baseline_file"
}
```

Both exit paths share the same finishing sequence. Do not skip `/simplify` and `/deslop` on the round-budget path — they operate on the accumulated diff, not on Keep findings, so they apply regardless of whether the loop converged.

Shared sequence (run in order for both paths):

1. `/simplify`
2. `/deslop`
3. `summary_diff "$BASELINE_FILE"` — emit inline
4. Output the exit block (convergence summary or round-budget handoff, per below)
5. `rm -f "$BASELINE_FILE"`

Language: all prose in the exit block is Chinese per SKILL.md `## Output`. English stays inside code identifiers, `file:line` citations, quoted code, and fixed label terms (`Applied Keep` / `Skip` / `Drop` / `Not fixed` / `Baseline` / `P1`/`P2`/`P3`). The round-budget handoff's "reached round budget — user judgment needed" label is a fixed English tag; the reasons attached to each `Not fixed` item are Chinese.

#### Convergence (primary exit)

`|Keep|` reaches 0 at the end of a round. Output the Convergence Summary (see below) as the exit block.

#### Round budget (secondary exit, after 5 rounds)

Check `|Keep|` at the end of each round. If `|Keep| == 0`, take the convergence path above. If round 5 ends with `|Keep| > 0`, the loop's output becomes the handoff. The exit block contains:

1. remaining Keep findings as `Not fixed`, labeled "reached round budget — user judgment needed" (each reason in Chinese)
2. `Baseline: <sha>` inline

## Convergence Summary Format

On convergence exit, output (per SKILL.md `## Output`: bucket labels and `file:line` stay English, prose is Chinese):

- Applied Keep: N
- Applied Rewrite (real-part-only): M
- Skip: X  (defensive-guard without trigger, unverified contract risk, runtime-verification-required)
- Drop: Y  (explicitly NOT — generic style, unwarranted performance/maintainability nits)
- Not fixed: Z  with `file:line` and reason per item
- Needs manual verification: K  runtime-verification Skips per SKILL.md `## Output → --fix termination output`. Each entry: `file:line`, one-line claim, observation to make (page / endpoint / two tabs / DB row).

Main session counts these buckets directly from per-round filter decisions. No schema required.

Keep "Needs manual verification" separate from "Not fixed": the former is Skips left for human judgment; the latter is Keeps the main session tried to apply and couldn't.
