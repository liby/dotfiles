# `--cx` Delegation

## Contract

- Main session owns the review.
- Delegates inspect independently and return candidate findings with citations.
- Delegate agreement is a lead to verify, not proof.
- Main session verifies every forwarded finding against the live checkout or MR worktree.
- The helper may fetch refs and create transient review worktrees or snapshot objects.

## Invocation

Run from the target repository root. Resolve the helper from the active skill directory.

```bash
REVIEW_SKILL_DIR="${REVIEW_SKILL_DIR:-$HOME/.claude/skills/review}"
REVIEW_HELPER="$REVIEW_SKILL_DIR/scripts/codex-review.sh"
[ -f "$REVIEW_HELPER" ] || REVIEW_HELPER="$REVIEW_SKILL_DIR/scripts/executable_codex-review.sh"

run_review() {
  unset REVIEW_CWD BASE_REF SCOPE BROAD_OUT BROAD_ERR OPINIONATED_OUT IS_TRANSIENT
  local out
  if out=$(bash "$REVIEW_HELPER"); then
    eval "$out"
  else
    echo "codex-review.sh failed; aborting review" >&2
    return 1
  fi
}
run_review
```

Supported forms:

```bash
bash "$REVIEW_HELPER"                                                    # local mode, auto base
bash "$REVIEW_HELPER" --base origin/main                                 # local mode, explicit base
bash "$REVIEW_HELPER" --include-untracked                                # local mode, include untracked files
bash "$REVIEW_HELPER" <gitlab-mr-url>                                    # GitLab MR mode
```

The helper supports local diffs and GitLab MR URLs. Other hosts can still be reviewed by the main session, but this helper is not their checkout mechanism.

MR mode requires a local clone of the target repo at cwd. If no remote matches the MR URL, the helper errors and asks the caller to cd into the matching clone.

After `eval`, read:

- `$REVIEW_CWD`: repo root or transient review worktree
- `$BASE_REF`: resolved base, empty for working-tree scope
- `$SCOPE`: `branch` or `working-tree`
- `$IS_TRANSIENT`: `1` when `$REVIEW_CWD` is helper-created, otherwise `0`
- `$BROAD_OUT`: JSON envelope. Extract prose with `jq -r .codex.stdout "$BROAD_OUT"`.
- `$BROAD_ERR`: stderr from the broad review path.
- `$OPINIONATED_OUT`: `codex exec` stdout. Read the whole file and extract cited findings.

If `$REVIEW_CWD` is transient, remove it after reading outputs:

```bash
if ! git worktree remove --force "$REVIEW_CWD" >/dev/null 2>&1; then
  echo "review cleanup failed for transient worktree" >&2
fi
```

Branch-scope snapshots include committed changes plus tracked dirty changes. Untracked files are omitted unless `--include-untracked` is passed. The helper refuses secret-like names in committed, tracked dirty, and included untracked paths.

## Filter

Forward only when:

- category matches the review skill's priorities
- cited path and line exist
- trigger path is concrete
- project impact is realistic
- main session verified the cited code or behavior

Investigate when:

- a plausible contract risk lacks source-of-truth evidence
- delegate and main session disagree on facts
- delegates agree but runtime or validation evidence is still needed

Drop when:

- style, formatting, or preference has no trigger
- a defensive guard request lacks observed failure or contract evidence
- the finding depends on a mode the project does not run
- the cited file is outside scope and the diff did not change a shared contract that reaches it

## Conflicts

When candidates recommend opposing changes:

1. Re-open both cited paths.
2. Identify the shared contract or source of truth.
3. Trace each trigger through direct callers or readers.
4. Run the cheapest validation that can settle the fact, if one exists.
5. Classify each claim as forward, investigate, or drop.

Rank survivors by contract, semantic correctness, ownership boundary, failure behavior, security, scope, and tests.

Do not average conflicting recommendations into a blended fix.

## Output

Rewrite forwarded findings into the main skill's output shape.
