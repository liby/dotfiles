#!/usr/bin/env bash
# PostToolUse hook for Skill.
# When a code review skill is invoked, remind AI to run /simplify then /deslop as finishing passes.

source "$(dirname "$0")/_lib.sh"
require_jq

INPUT=$(cat)

SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')

if [ -z "$SKILL" ]; then
  exit 0
fi

# Match any review-related skill
case "$SKILL" in
  *review*)
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": "IMPORTANT: After completing this code review, run /simplify then /deslop sequentially as finishing passes. Report all findings — do NOT auto-fix without user approval."
      }
    }'
    ;;
  *)
    echo '{}'
    ;;
esac
