#!/usr/bin/env bash
# Test harness for pre-bash-policy.sh.
# Pipes fake PreToolUse payloads into the hook and asserts the exit code:
#   exit 2 = blocked, exit 0 = allowed.
# Run: bash pre-bash-policy.test.sh

set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-bash-policy.sh"
[ -x "$HOOK" ] || HOOK="$(cd "$(dirname "$0")/.." && pwd)/executable_pre-bash-policy.sh"

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
  local expected="$1" cmd="$2" payload rc actual
  payload=$(jq -nc --arg c "$cmd" '{tool_input: {command: $c}}')
  echo "$payload" | bash "$HOOK" >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) actual=PASS ;;
    2) actual=BLOCK ;;
    *) actual="ERR($rc)" ;;
  esac
  if [ "$actual" = "$expected" ]; then
    printf '  ok   %-5s  %s\n' "$actual" "$cmd"
    PASS=$((PASS + 1))
  else
    printf '  FAIL want=%-5s got=%-5s  %s\n' "$expected" "$actual" "$cmd"
    FAIL=$((FAIL + 1))
  fi
}

section "find -> fd"
run_case BLOCK 'find . -name "*.tmp"'
run_case BLOCK 'echo x && find / -type f'
run_case PASS  'fd -H voyageai site-packages'
run_case PASS  'echo "find me a file"'

section "dev/start/serve"
run_case BLOCK 'npm run dev'
run_case BLOCK 'pnpm dev'
run_case PASS  'npm run build'

section "rg clustered -r (--replace) misuse"
run_case BLOCK 'rg -rn "full_resync" retl_asset.py'
run_case BLOCK 'rg -Hrn pattern .'
run_case BLOCK 'rg "quoted pattern" -rn file.py'
run_case BLOCK 'cd /tmp && rg -rn foo'
run_case BLOCK "rg -r '' -n pattern file.py"
run_case BLOCK $'echo building\nrg -rn foo src/'
run_case BLOCK $'rg \\\n-rn pattern .'

section "rg legitimate usage"
run_case PASS  'rg -n foo file.py'
run_case PASS  'rg -A3 -B2 pattern src/'
run_case PASS  'rg --replace n full_resync file.py'
run_case PASS  'rg -e -rn file.py'
run_case PASS  'rg -- -rn file.py'
run_case PASS  'rg -g "*.ts" MIN_ORDER src/'

section "rg token outside command position"
run_case PASS  'grep -e rg -rn dot_claude/CLAUDE.md'
run_case PASS  'grep -rn pattern dir/'
run_case PASS  'rg foo src/ | sort -rn | head'

section "quoted mentions and heredocs"
run_case PASS  "echo 'rg -rn is misparsed as replace'"
run_case PASS  'git commit -m "block rg -rn misuse in hook"'
run_case PASS  $'git commit -m "fix hook\n\nmention rg -rn in body"'
run_case PASS  $'cat <<EOF\nrg -rn foo\nEOF'
run_case BLOCK $'cat <<EOF\nbody\nEOF\nrg -rn foo src/'
run_case PASS  'rg -e "-rn" file.py'

section "rg --include"
run_case BLOCK 'rg --include="*.ts" MIN_ORDER src/'
run_case BLOCK 'rg pattern src --include "*.py"'

section "rg BRE alternation"
run_case BLOCK "rg 'a\|b' src/"
run_case BLOCK 'rg "a\|b" src/'
run_case BLOCK 'rg "a\\|b" src/'
run_case BLOCK "rg -e 'foo\|bar' ."
run_case BLOCK "rg -- '-a\|b' ."
run_case PASS  'rg a\|b src/'
run_case PASS  "rg 'a|b' src/"
run_case PASS  "rg '\\\\|' file.txt"
run_case PASS  'rg -F "a\|b" src/'
run_case PASS  "rg 'a\|b' -F ."
run_case PASS  "rg --fixed-strings 'a\|b' src/"
run_case BLOCK "rg -F 'a\|b' . ; rg 'x\|y' ."
run_case PASS  "grep 'a\|b' file"
run_case PASS  "git commit -m 'fix rg a\|b usage'"
run_case PASS  "rg 'foo' src | grep 'a\|b'"

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
