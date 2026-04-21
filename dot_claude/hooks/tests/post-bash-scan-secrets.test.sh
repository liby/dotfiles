#!/usr/bin/env bash
# Test harness for post-bash-scan-secrets.sh.
# Pipes fake PostToolUse payloads into the hook and asserts whether the scanner
# emits a leak warning. Each case states the categories it expects to fire
# (comma-joined, in scanner order) or "none" for a clean output.
# Run: bash post-bash-scan-secrets.test.sh

set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/post-bash-scan-secrets.sh"
[ -x "$HOOK" ] || HOOK="$(cd "$(dirname "$0")/.." && pwd)/executable_post-bash-scan-secrets.sh"

if [ ! -r "$HOOK" ]; then
  echo "cannot find hook script at $HOOK" >&2
  exit 1
fi

PASS=0
FAIL=0

section() {
  printf '\n== %s ==\n' "$1"
}

run_case() {
  local expected="$1" payload="$2" warn actual
  warn=$(printf '{"tool_response":{"stdout":%s,"stderr":""}}' \
    "$(printf '%s' "$payload" | jq -Rs .)" \
    | bash "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // ""')
  if [ -z "$warn" ]; then
    actual="none"
  else
    actual=$(echo "$warn" | sed -nE 's/.*potential secrets \(([^)]*)\).*/\1/p')
  fi
  if [ "$actual" = "$expected" ]; then
    printf '  ok   %-40s  %s\n' "$actual" "$payload"
    PASS=$((PASS + 1))
  else
    printf '  FAIL want=%-30s got=%-30s  %s\n' "$expected" "$actual" "$payload"
    FAIL=$((FAIL + 1))
  fi
}

section "Template/placeholder source code (must NOT warn)"
# These are the false-positive cases that motivated tightening the regexes:
# source code containing $-interpolation, template literals, or angle-bracket
# placeholders should not look like a leaked secret.
run_case none 'Authorization: `Bearer ${apiToken}`'
run_case none "'Authorization': \`Bearer \${apiToken}\`,"
run_case none 'TOKEN=${REAL_TOKEN}'
run_case none 'API_KEY={{ env.API_KEY }}'
run_case none 'mysql://user:${PASSWORD}@host'
run_case none 'Authorization: <YOUR_TOKEN_HERE>'
run_case none 'export TOKEN="$MY_TOKEN"'

section "Bearer tokens"
run_case 'Bearer token, auth header' 'Authorization: Bearer abcdef1234567890XYZQRS'
run_case 'Bearer token, auth header' 'Authorization: "Bearer abcdef1234567890XYZQRS"'
run_case 'Bearer token'              'curl -H "Bearer abcdef1234567890XYZQRS" https://x'

section "Vendor API key prefixes"
run_case 'API key' 'key=sk-aaaaaaaaaaaaaaaaaaaa'
run_case 'API key, env secret' 'token=ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
run_case 'API key' 'slack=xoxb-aaaaaaaaaaaaaaaaaaaaaaaa'
run_case 'API key' 'anthropic=sk-ant-aaaaaaaaaaaaaaaaaaaa'
run_case 'API key' 'stripe=sk_live_aaaaaaaaaaaaaaaaaaaa'
run_case 'API key' 'aws=AKIAIOSFODNN7EXAMPLE'

section "Env secret assignments"
run_case 'API key, env secret' 'TOKEN=ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
run_case 'env secret'          'PASSWORD=correcthorsebatterystaple'
run_case 'env secret'          'PRIVATE_KEY="aaaaaaaaaaaaaaaaaaaaaaaa"'

section "URL credentials"
run_case 'URL credential' 'mysql://user:correcthorsebatterystaple@host'
run_case 'URL credential' 'postgres://admin:supersecretpwd123@db.example.com'

section "Auth headers (non-Bearer)"
run_case 'auth header' 'X-Api-Key: aaaaaaaaaaaaaaaaaaaa'
run_case 'auth header' 'X-Auth-Token: aaaaaaaaaaaaaaaaaaaa'
run_case 'auth header' 'Authorization: Basic dXNlcjpwYXNzd29yZA=='
run_case 'auth header' 'Authorization: Token aaaaaaaaaaaaaaaaaaaa'

section "Clean output (must NOT warn)"
run_case none 'Hello, world!'
run_case none 'commit abc123 by alice'
run_case none 'GET /api/users 200 OK'
run_case none 'Authorization required'
run_case none 'TOKEN= # unset for now'

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
