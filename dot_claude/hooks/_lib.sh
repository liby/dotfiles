#!/usr/bin/env bash
# Shared utilities for Claude Code hooks.

# block — deny a PreToolUse action and exit.
# Usage: block "reason message"
block() {
  if command -v jq &>/dev/null; then
    jq -n --arg reason "DENIED: $1 Do NOT bypass this restriction or retry the same blocked command." '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": $reason
      }
    }'
    jq -n --arg reason "Blocked: $1" '{decision: "block", reason: $reason}' >&2
  else
    echo "Blocked: $1" >&2
  fi
  exit 2
}

# parse_command — read stdin, extract .tool_input.command, strip heredoc content.
# Returns 1 if command is empty. Usage: CMD=$(parse_command) || exit 0
parse_command() {
  local input cmd
  input=$(cat)
  cmd=$(echo "$input" | jq -r '.tool_input.command // empty') || return 1
  [ -z "$cmd" ] && return 1
  echo "$cmd" | awk '
    /<<-?[ ]*[\x27"]*[A-Za-z_]+[\x27"]*[ ]*$/ {
      delim=$NF; gsub(/[\x27"-]/, "", delim); skip=1; next
    }
    skip && $0 == delim { skip=0; next }
    !skip'
}

# require_jq — exit 0 (allow through) if jq is not available.
require_jq() {
  command -v jq &>/dev/null || exit 0
}
