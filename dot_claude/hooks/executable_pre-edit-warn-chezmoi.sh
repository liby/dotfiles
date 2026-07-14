#!/usr/bin/env bash
# Ask before Edit/Write changes a deployed chezmoi target.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

require_jq
command -v chezmoi &>/dev/null || exit 0

input=$(cat) || exit 0
file_path=$(jq -r '.tool_input.file_path // empty' <<<"$input") || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input") || exit 0
[[ -n "$file_path" ]] || exit 0

case "$file_path" in
  /*) target=$file_path ;;
  '~') target=$HOME ;;
  '~/'*) target="$HOME/${file_path#\~/}" ;;
  *)
    [[ "$cwd" == /* ]] || exit 0
    target="$cwd/$file_path"
    ;;
esac

source_path=$(chezmoi source-path "$target" 2>/dev/null) || exit 0
[[ -n "$source_path" ]] || exit 0

case "${source_path##*/}" in
  encrypted_*|create_encrypted_*|modify_encrypted_*)
    reason="This target is managed from an encrypted chezmoi source. Follow the repository's encrypted-file workflow and never edit the encrypted source directly."
    ;;
  modify_*)
    reason="This target is partially managed by chezmoi. Review the modifier and its managed fragment before changing the target: $source_path"
    ;;
  *)
    reason="This is a chezmoi-managed target. Edit the source instead: $source_path"
    ;;
esac

jq -n --arg reason "$reason" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": $reason
  }
}'
