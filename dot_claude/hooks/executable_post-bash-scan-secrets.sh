#!/usr/bin/env bash
# PostToolUse hook for Bash.
# Scans command output for leaked secrets and warns the model not to repeat them.

source "$(dirname "$0")/_lib.sh"

require_jq

INPUT=$(cat)
OUTPUT="$(echo "$INPUT" | jq -r '(.tool_response.stdout // "") + " " + (.tool_response.stderr // "")')"

LEAKED=""

# Bearer tokens
echo "$OUTPUT" | grep -qEi 'Bearer\s+[A-Za-z0-9._~+/=-]{20,}' && LEAKED="${LEAKED}Bearer token, "

# API key prefixes (OpenAI, Slack, GitHub, Anthropic, Stripe, AWS)
echo "$OUTPUT" | grep -qE '\b(sk-(proj-)?[a-zA-Z0-9]{20,}|xoxb-[a-zA-Z0-9-]{20,}|gh[pso]_[a-zA-Z0-9]{36}|sk-ant-[a-zA-Z0-9-]{20,}|[sr]k_(live|test)_[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16})' && LEAKED="${LEAKED}API key, "

# Env secret assignments (NAME=value where NAME looks secret-like)
echo "$OUTPUT" | grep -qEi '\b(TOKEN|SECRET|PASSWORD|CREDENTIAL|API_KEY|AUTH|PRIVATE_KEY)=[^ ]{16,}' && LEAKED="${LEAKED}env secret, "

# DSN/URL with embedded credentials (scheme://user:pass@host)
echo "$OUTPUT" | grep -qE '[a-z]+://[^:]+:[^@]{8,}@' && LEAKED="${LEAKED}URL credential, "

# Auth headers
echo "$OUTPUT" | grep -qEi '(Authorization|X-Api-Key|X-Auth-Token):\s*.{16,}' && LEAKED="${LEAKED}auth header, "

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
