#!/usr/bin/env bash
# PreToolUse hook for Bash
# Blocks commands that would print secret values to stdout/stderr.

CMD=$(jq -r '.tool_input.command // empty')

# Commands that dump all env vars
if echo "$CMD" | grep -qEw '(printenv|^env\s*$)'; then
  echo '{"decision":"block","reason":"Blocked: dumps all environment variables including secrets."}' >&2
  exit 2
fi

# Reading .env files (cat/head/tail/less/more/bat/grep)
if echo "$CMD" | grep -qE '\b(cat|head|tail|less|more|bat|grep)\b.*\.env'; then
  echo '{"decision":"block","reason":"Blocked: reading .env file contents would expose secrets."}' >&2
  exit 2
fi

# curl -v / --verbose prints Authorization headers
if echo "$CMD" | grep -qE '\bcurl\b.*(\s-v\b|\s--verbose\b)'; then
  echo '{"decision":"block","reason":"Blocked: curl verbose prints HTTP headers including Authorization."}' >&2
  exit 2
fi

# echo/printf referencing secret variable names
if echo "$CMD" | grep -qEi '(echo|printf)\s.*\$\{?\w*(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL|API_KEY)\}?'; then
  echo '{"decision":"block","reason":"Blocked: printing secret variable values."}' >&2
  exit 2
fi

echo '{}'
