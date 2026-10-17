#!/usr/bin/env bash
# Test harness for post-bash-scan-secrets.sh.
# Pipes successful and failed Bash payloads into the hook and checks which ones
# draw a warning. gitleaks owns the default detection rules, so these cases
# cover the hook's own contract: which payload fields reach the scanner, the
# rules its config adds, the event it answers, that a warning names rules
# without echoing the value, and that a failed scan is not reported as clean.
# Secrets are generated per run, because the scanner treats low-entropy
# fixtures as fake and a committed realistic token would trip secret scanning.
# Run: bash post-bash-scan-secrets.test.sh

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/executable_post-bash-scan-secrets.sh"

if [ ! -r "$HOOK" ]; then
  echo "cannot find hook script at $HOOK" >&2
  exit 1
fi

PASS=0
FAIL=0

# GitHub Actions starts steps with SIGPIPE ignored, so tr reading /dev/urandom
# directly would never stop after head exits; a bounded read lets it finish.
random() {
  head -c 1024 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c "$1"
}

report() { # <label> <ok>
  if $2; then
    printf '  ok   %s\n' "$1"
    PASS=$((PASS + 1))
  else
    printf '  FAIL %s\n' "$1"
    FAIL=$((FAIL + 1))
  fi
}

payload() { # <event> <stdout-or-error> [stderr]
  jq -nc --arg event "$1" --arg text "$2" --arg stderr "${3:-}" '
    {hook_event_name: $event, tool_name: "Bash"} +
    if $event == "PostToolUseFailure" then {error: $text, is_interrupt: false}
    else {tool_response: {stdout: $text, stderr: $stderr}} end'
}

# run_case <label> <warn|none> <event> <stdout-or-error> [stderr]
run_case() {
  local label="$1" expected="$2" event="$3" result warn ok=false
  result=$(payload "$event" "$4" "${5:-}" | bash "$HOOK")
  warn=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.additionalContext // ""')
  if [ "$expected" = none ]; then
    [ "$result" = "{}" ] && ok=true
  elif [ -n "$warn" ] && [ "$(printf '%s' "$result" | jq -r '.hookSpecificOutput.hookEventName')" = "$event" ] &&
    [[ "$warn" != *"$SECRET"* ]]; then
    ok=true
  fi
  report "$label" $ok
}

SECRET="ghp_$(random 36)"
run_case "stdout leak warns" warn PostToolUse "token: $SECRET"
run_case "stderr leak warns" warn PostToolUse "done" "token: $SECRET"
run_case "failed command leak warns" warn PostToolUseFailure $'Exit code 1\n'"token: $SECRET"
SECRET=$(random 40)
run_case "curl -v Authorization header warns" warn PostToolUse "> Authorization: Bearer $SECRET"
SECRET=$(random 40)
run_case "dumped request header warns, escaped JSON included" warn PostToolUse "{\"request\": \"{\\\"Authorization\\\": \\\"Bearer $SECRET\\\"}\"}"
SECRET=$(printf 'app:%s' "$(random 8)" | base64)
run_case "short Basic credential warns" warn PostToolUse "> Authorization: Basic $SECRET"
SECRET=$(printf '%s:%s' "$(random 20)" "$(random 22)" | base64)
run_case "ApiKey credential warns" warn PostToolUse "> Authorization: ApiKey $SECRET"
SECRET="$(random 10):$(random 10)"
run_case "URL password warns, colons included" warn PostToolUse "DATABASE_URL=postgres://app:$SECRET@db.internal:5432/app"
run_case "clean output stays silent" none PostToolUse 'GET /api/users 200 OK'
run_case "header placeholders stay silent" none PostToolUse $'> Authorization: Bearer undefined\ncurl -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN"'
run_case "URL placeholders stay silent" none PostToolUse $'postgres://app:<password>@db.internal/app\npostgres://app:${DB_PASSWORD_1}@db.internal/app'
run_case "URL example passwords stay silent" none PostToolUse $'https://user:password@db.internal/\nhttps://admin:changeme@db.internal/'
run_case "clean failure stays silent" none PostToolUseFailure 'Exit code 1: file not found'

# A scan that cannot run must not pass the output as clean: without the config
# beside the hook, or without jq on PATH, the hook has to exit with an error
# instead of printing {}.
unscanned() { # <label> <hook> [env args...]
  local label="$1" hook="$2" result status ok=false
  shift 2
  result=$(payload PostToolUse 'GET /api/users 200 OK' | env "$@" /bin/bash "$hook" 2>/dev/null)
  status=$?
  [ "$status" -ne 0 ] && [ -z "$result" ] && ok=true
  report "$label" $ok
}
lone=$(mktemp -d)
cp "$HOOK" "$lone/post-bash-scan-secrets.sh"
unscanned "scan without its config is not reported as clean" "$lone/post-bash-scan-secrets.sh"
rm -rf "$lone"
unscanned "scan without jq is not reported as clean" "$HOOK" PATH=/bin

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
