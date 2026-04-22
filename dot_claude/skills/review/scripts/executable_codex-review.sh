#!/usr/bin/env bash
# codex-review.sh — resolve target, optionally build MR/PR worktree, run both Codex
# review paths in parallel. Output `KEY=VAL` lines to stdout for `eval` by caller.
#
# Usage:
#   scripts/codex-review.sh                              # local mode, auto-resolve base
#   scripts/codex-review.sh --base <ref>                 # local mode, explicit base
#   scripts/codex-review.sh --mr <number>                # MR/PR mode (default remote: origin)
#   scripts/codex-review.sh --mr <number> --remote upstream  # fork workflow: PR lives on upstream
#
# Output (stdout):
#   REVIEW_CWD=<path>
#   BASE_REF=<ref or empty>
#   SCOPE=branch|working-tree
#   BROAD_OUT=<path to /codex:review JSON envelope>
#   OPINIONATED_OUT=<path to codex exec stdout>
#
# The caller (main review session) reads BROAD_OUT and OPINIONATED_OUT, runs the
# Filter step from delegation.md, and — whenever REVIEW_CWD differs from the repo
# root (MR/PR mode, or local mode where a dirty-tree snapshot worktree was built)
# — removes it with `git worktree remove --force "$REVIEW_CWD"`. On any non-zero
# exit the script cleans the worktree itself so no stdout parsing is needed.

set -euo pipefail

# Track transient worktrees we create (MR/PR head, or local dirty-tree snapshot)
# so any exit path — success, hard-fail on dual-path failure, or unexpected error —
# cleans them up instead of leaving `/tmp/review-*` dirs behind.
OWNED_WORKTREE=""
cleanup_owned_worktree() {
  [ -n "$OWNED_WORKTREE" ] && git worktree remove --force "$OWNED_WORKTREE" >/dev/null 2>&1 || true
}

MR_NUMBER=""
BASE_REF=""
REMOTE="origin"
PLATFORM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mr)       MR_NUMBER="$2"; shift 2 ;;
    --base)     BASE_REF="$2"; shift 2 ;;
    --remote)   REMOTE="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0" >&2; exit 0 ;;
    *) echo "codex-review.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

CODEX_ROOT=$(claude plugin list --json | jq -r '.[] | select(.id == "codex@openai-codex" and .enabled == true) | .installPath')
if [ -z "$CODEX_ROOT" ] || [ ! -f "$CODEX_ROOT/scripts/codex-companion.mjs" ]; then
  echo "codex-review.sh: codex plugin not installed or disabled" >&2
  exit 3
fi

: "${TMPDIR:=/tmp}"

if [ -n "$MR_NUMBER" ]; then
  # Include the process id so parallel reviews of the same MR number on different
  # repos (or retries of the same review) don't clobber each other's worktrees.
  REVIEW_CWD="${TMPDIR%/}/review-$MR_NUMBER-$$"
  REMOTE_URL=$(git remote get-url "$REMOTE")
  # Normalize into HOST/OWNER/[SUBGROUPS/]REPO for gh -R (which accepts
  # `[HOST/]OWNER/REPO`). The `:<digits>/` rule strips an SSH/HTTPS port before
  # it collides with the SSH-shortcut `host:path` separator. glab -R only
  # documents `OWNER/REPO`, `GROUP/NAMESPACE/REPO`, or a full URL, so we pass
  # the raw remote URL to glab below instead of this slug.
  REPO_SLUG=$(printf '%s' "$REMOTE_URL" | sed -E 's|\.git/?$||; s|^[^:]+://||; s|^[^:]+@||; s|:[0-9]+/|/|; s|:|/|')
  # Platform detection: explicit --platform wins; otherwise fall back to a
  # hostname substring probe, which only catches vanilla github.com / gitlab.com.
  # Self-hosted instances whose domain contains neither string must pass --platform.
  if [ -z "$PLATFORM" ]; then
    case "$REMOTE_URL" in
      *github*) PLATFORM="github" ;;
      *gitlab*) PLATFORM="gitlab" ;;
    esac
  fi
  BASE_NAME=""
  case "$PLATFORM" in
    github)
      command -v gh >/dev/null || { echo "codex-review.sh: gh CLI required for GitHub PR mode" >&2; exit 4; }
      HEAD_REF="pull/$MR_NUMBER/head"
      [ -n "$BASE_REF" ] || BASE_NAME=$(gh pr view "$MR_NUMBER" -R "$REPO_SLUG" --json baseRefName -q .baseRefName)
      ;;
    gitlab)
      command -v glab >/dev/null || { echo "codex-review.sh: glab CLI required for GitLab MR mode" >&2; exit 4; }
      HEAD_REF="merge-requests/$MR_NUMBER/head"
      [ -n "$BASE_REF" ] || BASE_NAME=$(glab mr view "$MR_NUMBER" -R "$REMOTE_URL" --output json | jq -r .target_branch)
      ;;
    *)
      echo "codex-review.sh: cannot infer platform for $REMOTE ($REMOTE_URL); pass --platform github|gitlab" >&2
      exit 4
      ;;
  esac
  # Refresh the base branch alongside the PR/MR head so merge-base runs against the
  # remote's current tip, not a stale local branch — reviewer's local `main` may lag.
  if [ -n "$BASE_NAME" ]; then
    echo "codex-review.sh: fetching $REMOTE $BASE_NAME + $HEAD_REF" >&2
    git fetch "$REMOTE" "$BASE_NAME" >&2
    BASE_REF="$REMOTE/$BASE_NAME"
  else
    echo "codex-review.sh: fetching $REMOTE $HEAD_REF (base=$BASE_REF)" >&2
  fi
  git fetch "$REMOTE" "$HEAD_REF" >&2
  git worktree remove --force "$REVIEW_CWD" >/dev/null 2>&1 || true
  git worktree add --detach "$REVIEW_CWD" FETCH_HEAD >&2
  OWNED_WORKTREE="$REVIEW_CWD"
  SCOPE=branch
else
  REVIEW_CWD=$(git rev-parse --show-toplevel)
  # Only auto-promote to branch scope when HEAD has commits ahead of the candidate
  # base; otherwise `<base>..HEAD` is empty and the broad path would review nothing,
  # silently hiding dirty working-tree changes from a review that claims to cover them.
  if [ -z "$BASE_REF" ]; then
    if UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
      [ -n "$(git rev-list "$UPSTREAM..HEAD" --max-count=1 2>/dev/null)" ] && BASE_REF="$UPSTREAM"
    fi
  fi
  if [ -z "$BASE_REF" ]; then
    if ORIGIN_HEAD=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
      CANDIDATE="${ORIGIN_HEAD#refs/remotes/}"
      [ -n "$(git rev-list "$CANDIDATE..HEAD" --max-count=1 2>/dev/null)" ] && BASE_REF="$CANDIDATE"
    fi
  fi
  # Final fallback: when neither @{upstream} nor origin/HEAD is configured (common
  # on bare clones or locally-initialized repos), probe standard default branches
  # so a topic branch with only committed changes still gets a branch-scope review.
  if [ -z "$BASE_REF" ]; then
    for CANDIDATE in main master trunk; do
      [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$CANDIDATE" ] && continue
      git show-ref --verify --quiet "refs/heads/$CANDIDATE" || continue
      [ -n "$(git rev-list "$CANDIDATE..HEAD" --max-count=1 2>/dev/null)" ] && { BASE_REF="$CANDIDATE"; break; }
    done
  fi
  [ -n "$BASE_REF" ] && SCOPE=branch || SCOPE=working-tree

  # Branch scope always snapshots to a transient worktree so the delegate's
  # workspace-write sandbox (set below) cannot touch the user's real checkout.
  # Dirty-tree reasoning: companion's resolveReviewTarget(baseRef) forces
  # mode=branch and diffs only mergeBase..HEAD (git.mjs:142+265), so uncommitted
  # changes fall out of the broad path. Materialize a snapshot commit on a
  # detached worktree so both paths see committed + staged + unstaged + untracked.
  # `git stash create [-u]` won't work: without -u it drops untracked; with -u it
  # parks untracked on a side parent, so a detached worktree of the stash commit
  # still wouldn't contain them. Build the snapshot through a temp index instead.
  # Clean-tree case: `git add -A` is a no-op and we snapshot HEAD directly; the
  # worktree isolation still matters because the delegate may run validation
  # commands that write build artifacts, coverage, or cache files.
  # Working-tree scope skips this: the companion's --scope working-tree expects
  # uncommitted diffs in the cwd, and committing them into a snapshot erases
  # exactly what that scope is designed to review.
  if [ "$SCOPE" = "branch" ]; then
    TMP_INDEX=$(mktemp)
    GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD
    GIT_INDEX_FILE="$TMP_INDEX" git add -A
    SNAPSHOT_TREE=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree)
    rm "$TMP_INDEX"
    SNAPSHOT=$(git commit-tree "$SNAPSHOT_TREE" -p HEAD -m "review-snapshot")
    REVIEW_CWD="${TMPDIR%/}/review-snapshot-$$"
    git worktree remove --force "$REVIEW_CWD" >/dev/null 2>&1 || true
    git worktree add --detach "$REVIEW_CWD" "$SNAPSHOT" >&2
    OWNED_WORKTREE="$REVIEW_CWD"
  fi
fi

# Any exit from here on — success, hard-fail, unexpected error — must clean up
# the transient worktree we created. The normal success path disarms the trap
# after publishing outputs so the caller owns the cleanup.
trap cleanup_owned_worktree EXIT

BROAD_OUT=$(mktemp)
OPINIONATED_OUT=$(mktemp)
# Resolve SKILL.md next to this script (skill-root/scripts/this-file → skill-root/SKILL.md)
# rather than hardcoding $HOME/.claude/..., so the opinionated path reads the same
# SKILL.md the user is currently editing (e.g. chezmoi source tree before `chezmoi apply`).
SKILL_PATH="$(cd "$(dirname "$0")/.." && pwd -P)/SKILL.md"

echo "codex-review.sh: dispatching (scope=$SCOPE, base=${BASE_REF:-<none>}, cwd=$REVIEW_CWD)" >&2

# Journal contract: SKILL.md §Self-improve Journal says writes are main-session
# only, but delegates historically read the opening sentence ("write one entry...")
# and attempt to append from the sandbox, producing PermissionError noise in every
# --cx session. Pin the prohibition in the prompt itself so it lands before
# SKILL.md's own wording is reached.
JOURNAL_INSTRUCTION="Do not write to ~/.claude/skills/review/journal.md — that file is main-session only. Instead, end your output with a 'Journal suggestions' block: 1-3 bullets, each prefixed with one of 'Over-specified:', 'Under-specified:', 'Rule that saved me:', or 'Odd behavior:', and each citing a file:line or concrete behavior. Skip the block entirely if you have nothing concrete — do not pad."

# Sandbox selection hinges on whether REVIEW_CWD is a transient worktree we own
# (MR/PR mode or local branch mode) or the user's real checkout (local working-tree
# mode, which cannot be snapshotted without erasing the uncommitted diff the
# companion reviews). Only the transient case is safe for workspace-write; the
# real-checkout case must stay read-only so delegate-triggered validation never
# writes into the user's tree.
if [ -n "$OWNED_WORKTREE" ]; then
  SANDBOX_ARGS=(--sandbox workspace-write)
  # --add-dir extends writability to tool-manager roots outside the worktree —
  # proto-managed pnpm/pnpx shims materialize under ~/.proto on first invocation.
  # Pre-create ~/.proto so cold-start machines still get it allowlisted; probe
  # other pnpm caches without creating them (they're tool-specific, not universal).
  mkdir -p "$HOME/.proto"
  SANDBOX_ARGS+=(--add-dir "$HOME/.proto")
  for extra in "$HOME/.cache/pnpm" "$HOME/.local/share/pnpm" "$HOME/Library/pnpm"; do
    [ -d "$extra" ] && SANDBOX_ARGS+=(--add-dir "$extra")
  done
else
  SANDBOX_ARGS=(--sandbox read-only)
fi

if [ "$SCOPE" = "branch" ]; then
  node "$CODEX_ROOT/scripts/codex-companion.mjs" review --wait --json \
    --cwd "$REVIEW_CWD" --base "$BASE_REF" --scope branch > "$BROAD_OUT" 2>&1 &
  BROAD_PID=$!
  codex exec --ephemeral "${SANDBOX_ARGS[@]}" -C "$REVIEW_CWD" \
    "Follow the review skill at $SKILL_PATH. Review the current worktree against base $BASE_REF. Output findings per the skill's Output section. $JOURNAL_INSTRUCTION" \
    > "$OPINIONATED_OUT" 2>&1 &
  OPINIONATED_PID=$!
else
  node "$CODEX_ROOT/scripts/codex-companion.mjs" review --wait --json \
    --cwd "$REVIEW_CWD" --scope working-tree > "$BROAD_OUT" 2>&1 &
  BROAD_PID=$!
  codex exec --ephemeral "${SANDBOX_ARGS[@]}" -C "$REVIEW_CWD" \
    "Follow the review skill at $SKILL_PATH. Review the current worktree's uncommitted changes. Output findings per the skill's Output section. $JOURNAL_INSTRUCTION" \
    > "$OPINIONATED_OUT" 2>&1 &
  OPINIONATED_PID=$!
fi

BROAD_EXIT=0; OPINIONATED_EXIT=0
wait "$BROAD_PID" || BROAD_EXIT=$?
wait "$OPINIONATED_PID" || OPINIONATED_EXIT=$?

[ "$BROAD_EXIT" -ne 0 ] && echo "codex-review.sh: broad path exit=$BROAD_EXIT (output in $BROAD_OUT)" >&2
[ "$OPINIONATED_EXIT" -ne 0 ] && echo "codex-review.sh: opinionated path exit=$OPINIONATED_EXIT (output in $OPINIONATED_OUT)" >&2

# --cx's contract is "both Codex paths in parallel, merge findings". Any single-path
# failure means the merged findings are incomplete; the caller would then treat the
# surviving path's clean prose as full convergence. Fail loud instead.
if [ "$BROAD_EXIT" -ne 0 ] || [ "$OPINIONATED_EXIT" -ne 0 ]; then
  echo "codex-review.sh: dual-path review incomplete — not publishing outputs" >&2
  exit 5
fi

# Shell-escape values so callers can `eval "$(scripts/codex-review.sh)"` even when
# the repo path or any output path contains spaces or shell metacharacters.
printf 'REVIEW_CWD=%q\nBASE_REF=%q\nSCOPE=%q\nBROAD_OUT=%q\nOPINIONATED_OUT=%q\n' \
  "$REVIEW_CWD" "$BASE_REF" "$SCOPE" "$BROAD_OUT" "$OPINIONATED_OUT"

# Hand ownership of the worktree to the caller; they decide when to remove it.
trap - EXIT
