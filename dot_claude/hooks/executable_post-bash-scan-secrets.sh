#!/usr/bin/env bash
# PostToolUse and PostToolUseFailure hook for Bash.
# Scans command output with gitleaks and warns the model not to repeat what it finds.

set -o pipefail

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name')
# Only rule IDs leave the scanner, so the warning never carries a value. When
# the scan cannot run, the hook exits non-zero, which Claude Code shows as a
# hook error instead of passing the output as clean.
RULES=$(printf '%s' "$INPUT" | jq -r '
  if .hook_event_name == "PostToolUseFailure" then .error // ""
  else (.tool_response.stdout // "") + "\n" + (.tool_response.stderr // "")
  end' |
  /opt/homebrew/bin/gitleaks stdin --config "${0%/*}/post-bash-scan-secrets.toml" \
    --no-banner --redact --log-level error --exit-code 0 --report-format json --report-path - |
  jq -r '[.[].RuleID] | unique | join(", ")') || exit

if [[ -n "$RULES" ]]; then
  jq -n --arg event "$EVENT" --arg rules "$RULES" '{
    "hookSpecificOutput": {
      "hookEventName": $event,
      "additionalContext": ("WARNING: Command output contains potential secrets (" + $rules + "). DO NOT repeat, quote, or reference these values in your response.")
    }
  }'
else
  echo '{}'
fi
