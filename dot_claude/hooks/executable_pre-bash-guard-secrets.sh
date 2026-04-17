#!/usr/bin/env bash
# PreToolUse hook for Bash.
# Blocks commands that read sensitive files or print secret values.
# Each top-level segment (split on unquoted ; && ||) is checked independently,
# so `cd foo && cat .env` evaluates per-op rather than as one concatenated
# string (which would misfire on e.g. `grep foo log; rm .env`).

source "$(dirname "$0")/_lib.sh"

require_jq
CMD=$(parse_command) || exit 0

# Path-boundary patterns below use [[:space:]] not \t — BSD grep ERE treats
# \t inside [] as literal '\' and 't', which would let backslash-prefixed
# strings (e.g. 'process\.env' inside source code) bypass the leading boundary.
READ_CMDS='cat|head|tail|less|more|bat|grep|sed|awk|base64|xxd|od|openssl|cp|tee|tar|source'
SENSITIVE_FILES='\.npmrc|\.zsh_history|\.zprofile|private-keys-v1\.d|\.pem|\.key|auth\.json'
# Trailing path boundary: end-of-string or shell token separator. Backtick and
# `)` matter for command-substitution (`$(cat .env)`, `` `cat .env` ``).
PATH_END='($|[[:space:]/"'"'"'>;|&)`])'

while IFS= read -r SEG; do
  [ -z "$SEG" ] && continue

  # Env dump commands
  if echo "$SEG" | grep -qE '\b(printenv|declare\s+-xp|export\s+-p|typeset\s+-xp)\b'; then
    block "dumps environment variables including secrets."
  fi
  if echo "$SEG" | grep -qE '(^|\|)\s*env\s*(\||>|$)'; then
    block "dumps environment variables including secrets."
  fi
  if echo "$SEG" | grep -qE '(^|\|)\s*set\s*(\||>|$)' && \
    ! echo "$SEG" | grep -qE '(^|\|)\s*set\s+-'; then
    block "dumps shell variables including secrets."
  fi

  # .env files (exclude non-secret variants: .example, .sample, .template, .age)
  if echo "$SEG" | grep -qE "\b($READ_CMDS)\b.*(^|[[:space:]/=\"'])\.env(\.(local|production|staging|development))?$PATH_END" && \
    ! echo "$SEG" | grep -qE '\.env\.(example|sample|template|age)\b'; then
    block "reading .env file contents would expose secrets."
  fi

  # Sensitive files (read command + sensitive filename pattern)
  if echo "$SEG" | grep -qE "\b($READ_CMDS)\b.*($SENSITIVE_FILES)$PATH_END" && \
    ! echo "$SEG" | grep -qE "(\.pem|\.key)\.pub$PATH_END"; then
    block "reading sensitive file contents."
  fi

  # SSH private keys (~/.ssh/id_* excluding .pub)
  if echo "$SEG" | grep -qE "\b($READ_CMDS)\b.*\.ssh/id_"; then
    if echo "$SEG" | grep -oE '\S*\.ssh/id_\S*' | grep -qvE '\.pub$'; then
      block "reading SSH private key."
    fi
  fi

  # curl -v / --verbose prints Authorization headers
  if echo "$SEG" | grep -qE '\bcurl\b.*(\s-v\b|\s--verbose\b)'; then
    block "curl verbose prints HTTP headers including Authorization."
  fi

  # Credential-fetching commands
  if echo "$SEG" | grep -qE '\bgh\s+auth\s+token\b'; then
    block "gh auth token prints GitHub credentials."
  fi

  # echo/printf referencing secret variable names
  if echo "$SEG" | grep -qEi '(echo|printf)\s.*\$\{?\w*(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL|API_KEY)\}?'; then
    block "printing secret variable values."
  fi
done < <(echo "$CMD" | split_segments)

exit 0
