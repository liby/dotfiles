#!/usr/bin/env bash
# codex-review.sh: dispatch dual Codex review for local changes or a GitLab MR.
# Output KEY=VAL lines to stdout for caller `eval`.
#
# Usage:
#   scripts/codex-review.sh                              # local mode, auto-resolve base
#   scripts/codex-review.sh --base <ref>                 # local mode, explicit base
#   scripts/codex-review.sh --include-untracked          # local mode, include untracked files
#   scripts/codex-review.sh <gitlab-mr-url>              # MR mode
#
# Output (stdout):
#   REVIEW_CWD=<path>
#   BASE_REF=<ref or empty>
#   SCOPE=branch|working-tree
#   BROAD_OUT=<path to JSON envelope>
#   BROAD_ERR=<path to broad path stderr>
#   OPINIONATED_OUT=<path to codex exec stdout>
#   IS_TRANSIENT=0|1
#
# Caller reads outputs and removes REVIEW_CWD when IS_TRANSIENT=1.
# On failure, this script cleans its own worktree.

set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

OWNED_WORKTREE=""
BROAD_PID=""
OPINIONATED_PID=""
cleanup_owned_worktree() {
  for pid in "$BROAD_PID" "$OPINIONATED_PID"; do
    [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null || true
  done
  if [ -n "$BROAD_PID$OPINIONATED_PID" ]; then
    sleep 1
    for pid in "$BROAD_PID" "$OPINIONATED_PID"; do
      [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null || true
      [ -n "$pid" ] && wait "$pid" 2>/dev/null || true
    done
  fi
  [ -n "$OWNED_WORKTREE" ] && git worktree remove --force "$OWNED_WORKTREE" >/dev/null 2>&1 || true
}

MR_URL=""
BASE_REF=""
INCLUDE_UNTRACKED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base)              BASE_REF="$2"; shift 2 ;;
    --include-untracked) INCLUDE_UNTRACKED=1; shift ;;
    -h|--help)           sed -n '2,20p' "$0" >&2; exit 0 ;;
    https://*/-/merge_requests/*) MR_URL="$1"; shift ;;
    https://*)           echo "codex-review.sh: helper supports GitLab MR URLs only; review other hosts in the main session" >&2; exit 2 ;;
    *) echo "codex-review.sh: unsupported argument; use local mode flags or an HTTPS GitLab MR URL" >&2; exit 2 ;;
  esac
done

for cmd in git jq; do
  require_command "$cmd"
done

for cmd in claude node codex; do
  require_command "$cmd"
done

CODEX_ROOT=$(claude plugin list --json | jq -r '.[] | select(.id == "codex@openai-codex" and .enabled == true) | .installPath')
if [ -z "$CODEX_ROOT" ] || [ ! -f "$CODEX_ROOT/scripts/codex-companion.mjs" ]; then
  echo "codex-review.sh: codex plugin not installed or disabled" >&2
  exit 3
fi

: "${TMPDIR:=/tmp}"

if [ -n "$MR_URL" ]; then
  command -v glab >/dev/null || { echo "codex-review.sh: glab CLI required for GitLab MR mode" >&2; exit 4; }

  # GitLab MR URLs only. Other hosts are reviewed by the caller, not this helper.
  MR_PATH="merge_requests"
  MR_NUMBER=$(printf '%s' "$MR_URL" | sed -nE "s|.*/-/${MR_PATH}/([0-9]+).*|\\1|p")
  REPO_URL=$(printf '%s' "$MR_URL"  | sed -nE "s|^(https://[^/]+/.+)/-/${MR_PATH}/[0-9]+.*|\\1|p")
  if [ -z "$MR_NUMBER" ] || [ -z "$REPO_URL" ]; then
    echo "codex-review.sh: not a supported GitLab MR URL" >&2
    exit 4
  fi
  REPO_SLUG=$(normalize_repo_slug "$REPO_URL")
  if [ -n "$BASE_REF" ]; then
    echo "codex-review.sh: --base is not supported with GitLab MR URLs" >&2
    exit 2
  fi

  # Require a local clone that has a matching remote.
  REMOTE=""
  for r in $(git remote 2>/dev/null); do
    url=$(git remote get-url "$r" 2>/dev/null) || continue
    remote_slug=$(normalize_repo_slug "$url")
    [ "$remote_slug" = "$REPO_SLUG" ] && { REMOTE="$r"; break; }
  done
  if [ -z "$REMOTE" ]; then
    echo "codex-review.sh: no matching local remote; cd into the local clone" >&2
    exit 4
  fi

  # Include pid so parallel reviews do not clobber worktrees.
  REVIEW_CWD="${TMPDIR%/}/review-$MR_NUMBER-$$"
  HEAD_REF="merge-requests/$MR_NUMBER/head"
  # Fetch base and MR head before creating the review worktree.
  BASE_NAME=$(glab mr view "$MR_NUMBER" -R "$REPO_URL" --output json 2>/dev/null | jq -r .target_branch)
  if [ -z "$BASE_NAME" ] || [ "$BASE_NAME" = "null" ]; then
    echo "codex-review.sh: failed to resolve MR target branch" >&2
    exit 4
  fi
  echo "codex-review.sh: fetching base and MR head" >&2
  if ! git fetch --quiet "$REMOTE" "$BASE_NAME" 2>/dev/null; then
    echo "codex-review.sh: failed to fetch MR target branch" >&2
    exit 4
  fi
  BASE_REF=$(git rev-parse FETCH_HEAD)
  if ! git fetch --quiet "$REMOTE" "$HEAD_REF" 2>/dev/null; then
    echo "codex-review.sh: failed to fetch MR head" >&2
    exit 4
  fi
  validate_git_diff_paths "$BASE_REF" FETCH_HEAD
  git worktree remove --force "$REVIEW_CWD" >/dev/null 2>&1 || true
  if ! git worktree add --detach "$REVIEW_CWD" FETCH_HEAD >/dev/null 2>&1; then
    echo "codex-review.sh: failed to create transient review worktree" >&2
    exit 4
  fi
  OWNED_WORKTREE="$REVIEW_CWD"
  SCOPE=branch
else
  REVIEW_CWD=$(git rev-parse --show-toplevel)
  # Preserve explicit --base; rewind guards apply only to auto base.
  BASE_EXPLICIT=""
  [ -n "$BASE_REF" ] && BASE_EXPLICIT=1
  # Use branch scope only when HEAD is ahead of the candidate base.
  if [ -z "$BASE_REF" ]; then
    if UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
      [ -n "$(git rev-list "$UPSTREAM..HEAD" --max-count=1 2>/dev/null)" ] && BASE_REF="$UPSTREAM"
    fi
  fi
  # If HEAD was rewritten to match upstream, review the prior snapshot delta.
  if [ -z "$BASE_REF" ] && [ -n "${UPSTREAM:-}" ] && \
     [ "$(git rev-parse HEAD 2>/dev/null)" = "$(git rev-parse "$UPSTREAM" 2>/dev/null)" ]; then
    PREV=$(git rev-parse HEAD@{1} 2>/dev/null) || PREV=""
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
    if [ -n "$PREV" ] && [ "$PREV" != "$HEAD_SHA" ] && \
       [ "$(git rev-parse HEAD^ 2>/dev/null)" = "$(git rev-parse "${PREV}^" 2>/dev/null)" ]; then
      BASE_REF="$PREV"
      echo "codex-review.sh: HEAD == $UPSTREAM but HEAD@{1} ($PREV) shares HEAD's parent; reviewing prior snapshot delta, base=HEAD@{1}" >&2
    fi
  fi
  if [ -z "$BASE_REF" ]; then
    if ORIGIN_HEAD=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
      CANDIDATE="${ORIGIN_HEAD#refs/remotes/}"
      [ -n "$(git rev-list "$CANDIDATE..HEAD" --max-count=1 2>/dev/null)" ] && BASE_REF="$CANDIDATE"
    fi
  fi
  # Fallback for repos without @{upstream} or origin/HEAD.
  if [ -z "$BASE_REF" ]; then
    for CANDIDATE in main master trunk; do
      [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$CANDIDATE" ] && continue
      git show-ref --verify --quiet "refs/heads/$CANDIDATE" || continue
      [ -n "$(git rev-list "$CANDIDATE..HEAD" --max-count=1 2>/dev/null)" ] && { BASE_REF="$CANDIDATE"; break; }
    done
  fi
  # If HEAD is behind default branch, pending work belongs to working-tree scope.
  if [ -z "$BASE_EXPLICIT" ] && [ -n "$BASE_REF" ] && \
     ORIGIN_HEAD=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
    if git merge-base --is-ancestor HEAD "${ORIGIN_HEAD#refs/remotes/}" 2>/dev/null; then
      BASE_REF=""
    fi
  fi
  [ -n "$BASE_REF" ] && SCOPE=branch || SCOPE=working-tree

  # Branch scope snapshots tracked dirty changes into a stable worktree.
  # Untracked files require explicit opt-in because local artifacts may be private.
  if [ "$SCOPE" = "branch" ]; then
    validate_git_diff_paths "$BASE_REF" HEAD
  fi
  TMP_CHANGED=$(mktemp)
  git_dirty_paths_nul "$TMP_CHANGED"
  validate_path_file_nul "$TMP_CHANGED" || { rm "$TMP_CHANGED"; exit 4; }

  TMP_UNTRACKED=$(mktemp)
  git ls-files -z --others --exclude-standard > "$TMP_UNTRACKED"
  UNTRACKED_REVIEW_NOTE=""
  if [ -s "$TMP_UNTRACKED" ]; then
    if [ -n "$INCLUDE_UNTRACKED" ]; then
      validate_path_file_nul "$TMP_UNTRACKED" || { rm "$TMP_CHANGED" "$TMP_UNTRACKED"; exit 4; }
      UNTRACKED_REVIEW_NOTE="Untracked files are in scope because --include-untracked was set. Parse 'git ls-files -z --others --exclude-standard', then inspect those files."
      UNTRACKED_COUNT=$(tr -cd '\0' < "$TMP_UNTRACKED" | wc -c | tr -d ' ')
      echo "codex-review.sh: --include-untracked set; including $UNTRACKED_COUNT untracked file(s)" >&2
    else
      UNTRACKED_REVIEW_NOTE="Untracked files exist but are out of scope for this delegate run because --include-untracked was not set."
    fi
  fi
  if [ "$SCOPE" = "working-tree" ] && [ -s "$TMP_UNTRACKED" ] && [ -z "$INCLUDE_UNTRACKED" ]; then
    echo "codex-review.sh: refusing working-tree --cx with omitted untracked files; pass --include-untracked after pruning private artifacts" >&2
    rm "$TMP_CHANGED" "$TMP_UNTRACKED"
    exit 4
  fi

  if [ "$SCOPE" = "branch" ]; then
    if [ -s "$TMP_UNTRACKED" ] && [ -z "$INCLUDE_UNTRACKED" ]; then
      echo "codex-review.sh: untracked files omitted from branch-scope --cx; pass --include-untracked to include them, or use working-tree review" >&2
    fi
    TMP_INDEX=$(mktemp)
    TMP_CHANGED_NUL=$(mktemp)
    TMP_UNTRACKED_NUL=$(mktemp)
    path_file_nul_to_literal_pathspec "$TMP_CHANGED" "$TMP_CHANGED_NUL"
    path_file_nul_to_literal_pathspec "$TMP_UNTRACKED" "$TMP_UNTRACKED_NUL"
    GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD
    if [ -s "$TMP_CHANGED" ]; then
      GIT_INDEX_FILE="$TMP_INDEX" git add -A --pathspec-from-file="$TMP_CHANGED_NUL" --pathspec-file-nul
    fi
    if [ -n "$INCLUDE_UNTRACKED" ]; then
      if [ -s "$TMP_UNTRACKED" ]; then
        GIT_INDEX_FILE="$TMP_INDEX" git add --pathspec-from-file="$TMP_UNTRACKED_NUL" --pathspec-file-nul
      fi
    fi
    SNAPSHOT_TREE=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree)
    rm "$TMP_INDEX" "$TMP_CHANGED_NUL" "$TMP_UNTRACKED_NUL"
    SNAPSHOT=$(git commit-tree "$SNAPSHOT_TREE" -p HEAD -m "review-snapshot")
    REVIEW_CWD="${TMPDIR%/}/review-snapshot-$$"
    git worktree remove --force "$REVIEW_CWD" >/dev/null 2>&1 || true
    if ! git worktree add --detach "$REVIEW_CWD" "$SNAPSHOT" >/dev/null 2>&1; then
      echo "codex-review.sh: failed to create transient review worktree" >&2
      exit 4
    fi
    OWNED_WORKTREE="$REVIEW_CWD"
  fi
  rm "$TMP_CHANGED" "$TMP_UNTRACKED"
fi

# Clean transient worktree on any unpublished exit.
trap cleanup_owned_worktree EXIT

BROAD_OUT=$(mktemp)
BROAD_ERR=$(mktemp)
OPINIONATED_OUT=$(mktemp)
SKILL_PATH="$(cd "$(dirname "$0")/.." && pwd -P)/SKILL.md"

echo "codex-review.sh: dispatching (scope=$SCOPE, base=${BASE_REF:+set})" >&2

REVIEW_GUIDANCE="Report every issue you find, including uncertain and low-severity candidates. Include severity (P1/P2/P3) for each finding.

Read-only contract: do not edit files, do not run formatters, do not run fix commands, and do not run project commands that are expected to write caches or build artifacts. Read any file you reference before making claims about it."

if [ "$SCOPE" = "branch" ]; then
  COMPANION_SCOPE_ARGS=(--base "$BASE_REF" --scope branch)
  EXEC_PROMPT="Review the current worktree against base $BASE_REF, following the review skill at $SKILL_PATH. Output findings per the skill's Output section.

$REVIEW_GUIDANCE"
else
  COMPANION_SCOPE_ARGS=(--scope working-tree)
  EXEC_PROMPT="Review the current worktree's uncommitted changes, following the review skill at $SKILL_PATH. Output findings per the skill's Output section.

How to see the diff: run 'git diff HEAD' to see staged and unstaged changes together. Plain 'git diff' only shows unstaged hunks.

$UNTRACKED_REVIEW_NOTE

$REVIEW_GUIDANCE"
fi

node "$CODEX_ROOT/scripts/codex-companion.mjs" review --wait --json \
  --cwd "$REVIEW_CWD" "${COMPANION_SCOPE_ARGS[@]}" > "$BROAD_OUT" 2> "$BROAD_ERR" &
BROAD_PID=$!
codex exec --ephemeral --sandbox read-only -C "$REVIEW_CWD" "$EXEC_PROMPT" > "$OPINIONATED_OUT" 2>&1 &
OPINIONATED_PID=$!

BROAD_EXIT=0; OPINIONATED_EXIT=0
wait "$BROAD_PID" || BROAD_EXIT=$?
wait "$OPINIONATED_PID" || OPINIONATED_EXIT=$?

# Empty successful output is still a failed review path.
if [ "$BROAD_EXIT" -eq 0 ] && [ ! -s "$BROAD_OUT" ]; then
  BROAD_EXIT=124
  echo "codex-review.sh: broad path exit=0 but produced 0-byte output" >&2
elif [ "$BROAD_EXIT" -ne 0 ]; then
  echo "codex-review.sh: broad path exit=$BROAD_EXIT (stdout in $BROAD_OUT, $(wc -c <"$BROAD_OUT") bytes; stderr in $BROAD_ERR, $(wc -c <"$BROAD_ERR") bytes)" >&2
elif ! jq -e '.codex.stdout' "$BROAD_OUT" >/dev/null 2>&1; then
  BROAD_EXIT=125
  echo "codex-review.sh: broad path output is not the expected JSON envelope (stdout in $BROAD_OUT, stderr in $BROAD_ERR)" >&2
fi
if [ "$OPINIONATED_EXIT" -eq 0 ] && [ ! -s "$OPINIONATED_OUT" ]; then
  OPINIONATED_EXIT=124
  echo "codex-review.sh: opinionated path exit=0 but produced 0-byte output" >&2
elif [ "$OPINIONATED_EXIT" -ne 0 ]; then
  echo "codex-review.sh: opinionated path exit=$OPINIONATED_EXIT (output in $OPINIONATED_OUT, $(wc -c <"$OPINIONATED_OUT") bytes)" >&2
fi

# A single-path failure makes merged findings incomplete.
if [ "$BROAD_EXIT" -ne 0 ] || [ "$OPINIONATED_EXIT" -ne 0 ]; then
  echo "codex-review.sh: dual-path review incomplete; not publishing outputs" >&2
  exit 5
fi

# Shell-escape values for safe caller eval.
if [ -n "$OWNED_WORKTREE" ]; then
  IS_TRANSIENT=1
else
  IS_TRANSIENT=0
fi
printf 'REVIEW_CWD=%q\nBASE_REF=%q\nSCOPE=%q\nBROAD_OUT=%q\nBROAD_ERR=%q\nOPINIONATED_OUT=%q\nIS_TRANSIENT=%q\n' \
  "$REVIEW_CWD" "$BASE_REF" "$SCOPE" "$BROAD_OUT" "$BROAD_ERR" "$OPINIONATED_OUT" "$IS_TRANSIENT"

# Caller now owns any transient worktree.
trap - EXIT
