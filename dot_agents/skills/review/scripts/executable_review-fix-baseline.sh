#!/usr/bin/env bash
# Create a scoped baseline object for /review --fix.
# Input is a NUL-delimited file of repo-relative paths the fixer may touch.
# Stdout prints the baseline commit id. Stderr prints refusal or usage errors.

set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

if [ "$#" -ne 1 ]; then
  echo "${0##*/}: usage: ${0##*/} <nul-delimited-fix-scope-file>" >&2
  exit 2
fi

FIX_SCOPE_FILE="$1"
if [ ! -f "$FIX_SCOPE_FILE" ]; then
  echo "${0##*/}: fix scope file does not exist" >&2
  exit 2
fi
# An empty scope would snapshot zero paths yet print a plausible baseline id;
# a later rollback against it would overwrite scope files with HEAD content.
if [ ! -s "$FIX_SCOPE_FILE" ]; then
  echo "${0##*/}: empty fix scope file" >&2
  exit 2
fi

validate_path_file_nul "$FIX_SCOPE_FILE" || exit 4

TMP_INDEX=$(mktemp)
FIX_SCOPE_NUL=$(mktemp)
cleanup() { rm -f "$TMP_INDEX" "$FIX_SCOPE_NUL"; }
trap cleanup EXIT

path_file_nul_to_literal_pathspec "$FIX_SCOPE_FILE" "$FIX_SCOPE_NUL"

GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD
GIT_INDEX_FILE="$TMP_INDEX" git add --pathspec-from-file="$FIX_SCOPE_NUL" --pathspec-file-nul
BASELINE_TREE=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree)
BASELINE=$(git commit-tree "$BASELINE_TREE" -p HEAD -m "review-fix-baseline")
printf '%s\n' "$BASELINE"
