#!/usr/bin/env bash
# Create a scoped baseline object for /review --fix.
# Input is a NUL-delimited file of repo-relative paths the fixer may touch.
# Stdout prints the baseline commit id. Stderr prints refusal or usage errors.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "review-fix-baseline.sh: usage: review-fix-baseline.sh <nul-delimited-fix-scope-file>" >&2
  exit 2
fi

FIX_SCOPE_FILE="$1"
if [ ! -f "$FIX_SCOPE_FILE" ]; then
  echo "review-fix-baseline.sh: fix scope file does not exist" >&2
  exit 2
fi

RESTORE_NOCASEMATCH=0
shopt -q nocasematch || RESTORE_NOCASEMATCH=1
shopt -s nocasematch

REFUSED=0
while IFS= read -r -d '' path; do
  [ -z "$path" ] && continue
  case "$path" in
    .env*|.env*/*|*/.env*|*/.env*/*|*.pem|*.key|*.p12|*.pfx|*.crt|*.cer|\
    id_rsa|id_dsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519|\
    .ssh|*/.ssh|*/.ssh/*|.ssh/*|*.history|.*_history|*/.*_history|*.log|*.log/*|log|logs|*/log|*/logs|log/*|logs/*|*/log/*|*/logs/*|\
    *credential*|*secret*|*token*)
      REFUSED=$((REFUSED + 1))
      ;;
  esac
done < "$FIX_SCOPE_FILE"

if [ "$REFUSED" -gt 0 ]; then
  echo "review-fix-baseline.sh: refusing $REFUSED secret-like fix path(s)" >&2
  exit 4
fi

[ "$RESTORE_NOCASEMATCH" -eq 1 ] && shopt -u nocasematch

TMP_INDEX=$(mktemp)
FIX_SCOPE_NUL=$(mktemp)
cleanup() {
  rm -f "$TMP_INDEX" "$FIX_SCOPE_NUL"
}
trap cleanup EXIT

: > "$FIX_SCOPE_NUL"
while IFS= read -r -d '' path; do
  [ -z "$path" ] && continue
  printf ':(literal)%s\0' "$path" >> "$FIX_SCOPE_NUL"
done < "$FIX_SCOPE_FILE"

GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD
GIT_INDEX_FILE="$TMP_INDEX" git add --pathspec-from-file="$FIX_SCOPE_NUL" --pathspec-file-nul
BASELINE_TREE=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree)
BASELINE=$(git commit-tree "$BASELINE_TREE" -p HEAD -m "review-fix-baseline")
printf '%s\n' "$BASELINE"
