#!/usr/bin/env bash
# PreToolUse hook for Bash.
# Blocks commands that read sensitive files or print secret values.

source "$(dirname "$0")/_lib.sh"

require_jq
CMD=$(parse_command) || exit 0

# Env dump commands
if echo "$CMD" | grep -qE '\b(printenv|declare\s+-xp|export\s+-p|typeset\s+-xp)\b'; then
  block "dumps environment variables including secrets."
fi
if echo "$CMD" | grep -qE '(^|\|)\s*env\s*(\||>|$)'; then
  block "dumps environment variables including secrets."
fi
if echo "$CMD" | grep -qE '(^|\|)\s*set\s*(\||>|$)' && \
  ! echo "$CMD" | grep -qE '(^|\|)\s*set\s+-'; then
  block "dumps shell variables including secrets."
fi

# .env files (exclude non-secret variants: .example, .sample, .template, .age)
READ_CMDS='cat|head|tail|less|more|bat|grep|sed|awk|base64|xxd|od|openssl|cp|tee|tar|source'
if echo "$CMD" | grep -qE "\b($READ_CMDS)\b.*\.env(\.(local|production|staging|development))?\b" && \
  ! echo "$CMD" | grep -qE '\.env\.(example|sample|template|age)\b'; then
  block "reading .env file contents would expose secrets."
fi

# Sensitive files (read command + sensitive filename pattern)
SENSITIVE_FILES='\.npmrc|\.zsh_history|\.zprofile|private-keys-v1\.d|\.pem\b|\.key\b|auth\.json'
if echo "$CMD" | grep -qE "\b($READ_CMDS)\b.*($SENSITIVE_FILES)" && \
  ! echo "$CMD" | grep -qE '\.pem\.pub\b|\.key\.pub\b'; then
  block "reading sensitive file contents."
fi

# SSH private keys (~/.ssh/id_* excluding .pub)
if echo "$CMD" | grep -qE "\b($READ_CMDS)\b.*\.ssh/id_"; then
  if echo "$CMD" | grep -oE '\S*\.ssh/id_\S*' | grep -qvE '\.pub$'; then
    block "reading SSH private key."
  fi
fi

# curl -v / --verbose prints Authorization headers
if echo "$CMD" | grep -qE '\bcurl\b.*(\s-v\b|\s--verbose\b)'; then
  block "curl verbose prints HTTP headers including Authorization."
fi

# Credential-fetching commands
if echo "$CMD" | grep -qE '\bgh\s+auth\s+token\b'; then
  block "gh auth token prints GitHub credentials."
fi

# echo/printf referencing secret variable names
if echo "$CMD" | grep -qEi '(echo|printf)\s.*\$\{?\w*(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL|API_KEY)\}?'; then
  block "printing secret variable values."
fi

exit 0
