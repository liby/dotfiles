#!/usr/bin/env bash
# PostToolUse hook for Bash.
# Scans command output for leaked secrets and warns the model not to repeat them.

source "$(dirname "$0")/_lib.sh"

require_jq

INPUT=$(cat)
OUTPUT="$(echo "$INPUT" | jq -r '(.tool_response.stdout // "") + " " + (.tool_response.stderr // "")')"

LEAKED=""

# Token charset matches what real secrets contain (alnum + base64/JWT/url-safe punctuation).
# Excludes shell/template syntax ($ { } < > ` ' "), so source-code placeholders like
# `Bearer ${apiToken}` or "TOKEN=${REAL_TOKEN}" don't trip the scanner.
TOKEN='[A-Za-z0-9._~+/=-]'
QUOTE="[\"']?"

# Bearer tokens
echo "$OUTPUT" | grep -qEi "Bearer\s+${TOKEN}{20,}" && LEAKED="${LEAKED}Bearer token, "

# API key prefixes (OpenAI, Slack, GitHub, Anthropic, Stripe, AWS)
echo "$OUTPUT" | grep -qE '\b(sk-(proj-)?[a-zA-Z0-9]{20,}|xoxb-[a-zA-Z0-9-]{20,}|gh[pso]_[a-zA-Z0-9]{36}|sk-ant-[a-zA-Z0-9-]{20,}|[sr]k_(live|test)_[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16})' && LEAKED="${LEAKED}API key, "

# Env secret assignments (NAME=value where NAME looks secret-like)
echo "$OUTPUT" | grep -qEi "\b(TOKEN|SECRET|PASSWORD|CREDENTIAL|API_KEY|AUTH|PRIVATE_KEY)=${QUOTE}${TOKEN}{16,}" && LEAKED="${LEAKED}env secret, "

# DSN/URL with embedded credentials (scheme://user:pass@host)
echo "$OUTPUT" | grep -qE "[a-z]+://[^:/@[:space:]]+:${TOKEN}{8,}@" && LEAKED="${LEAKED}URL credential, "

# Auth headers
echo "$OUTPUT" | grep -qEi "(Authorization|X-Api-Key|X-Auth-Token):\s*${QUOTE}((Bearer|Basic|Token)\s+)?${TOKEN}{16,}" && LEAKED="${LEAKED}auth header, "

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
