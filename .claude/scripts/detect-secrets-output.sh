#!/usr/bin/env bash
# PostToolUse hook for Bash
# Scans command output for leaked secrets and warns.

INPUT=$(cat)
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // empty')
STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // empty')
OUTPUT="$STDOUT $STDERR"

LEAKED=""

# Bearer tokens, known API key prefixes, env secret assignments, auth headers
echo "$OUTPUT" | grep -qEi 'Bearer\s+[A-Za-z0-9._~+/=-]{20,}' && LEAKED="${LEAKED}Bearer token, "
echo "$OUTPUT" | grep -qE '\b(sk-[a-zA-Z0-9]{20,}|xoxb-[a-zA-Z0-9-]{20,}|gh[po]_[a-zA-Z0-9]{36})' && LEAKED="${LEAKED}API key, "
echo "$OUTPUT" | grep -qEi '(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL|API_KEY)=[^ ]{16,}' && LEAKED="${LEAKED}env secret, "
echo "$OUTPUT" | grep -qEi '(Authorization|X-Api-Key):\s*.{16,}' && LEAKED="${LEAKED}auth header, "

if [[ -n "$LEAKED" ]]; then
  LEAKED="${LEAKED%, }"
  jq -n --arg leaked "$LEAKED" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("WARNING: Command output contains potential secrets (" + $leaked + "). DO NOT repeat, quote, or reference these values in your response.")
    }
  }'
else
  echo '{}'
fi
