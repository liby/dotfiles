#!/usr/bin/env bash
# Ask reasons are user-only; repeat modify_ warnings as additionalContext.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

require_jq
command -v chezmoi &>/dev/null || exit 0

input=$(cat) || exit 0
file_path=$(jq -r '.tool_input.file_path // empty' <<<"$input") || exit 0
[[ "$file_path" == /* ]] || exit 0

source_path=$(chezmoi source-path "$file_path" 2>/dev/null) || exit 0
[[ -n "$source_path" ]] || exit 0

case "${source_path##*/}" in
  encrypted_*|create_encrypted_*|modify_encrypted_*)
    decision="deny"
    reason="This target has an encrypted chezmoi source. Follow the repository's encrypted-file workflow; do not edit ciphertext directly."
    ;;
  modify_*)
    decision="ask"
    reason="This target is partially managed by chezmoi. Edit unmanaged keys here; edit managed keys in the source and run chezmoi apply: $source_path"
    ;;
  *)
    decision="deny"
    reason="This target is managed by chezmoi. Edit the source and run chezmoi apply: $source_path"
    ;;
esac

jq -n --arg decision "$decision" --arg reason "$reason" '
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": $decision,
      "permissionDecisionReason": $reason
    }
  }
  | if $decision == "ask" then
      .hookSpecificOutput.additionalContext = $reason
    else
      .
    end
'
