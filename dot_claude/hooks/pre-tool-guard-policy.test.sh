#!/usr/bin/env bash
# Command policy cases for pre-tool-guard.py.
# Pipes fake PreToolUse payloads into the hook and asserts the exit code:
#   exit 2 = blocked, exit 0 = no hook decision.
# Run: bash pre-tool-guard-policy.test.sh

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/pre-tool-guard.py"
[ -x "$HOOK" ] || HOOK="$(cd "$(dirname "$0")" && pwd)/executable_pre-tool-guard.py"

if [ ! -r "$HOOK" ]; then
  echo "cannot find hook script at $HOOK" >&2
  exit 1
fi

PASS=0
FAIL=0
TEST_ROOT=$(mktemp -d)
TEST_HOME="$TEST_ROOT/home"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_HOME"

section() {
  printf '\n== %s ==\n' "$1"
}

run_case() {
  local expected="$1" cmd="$2" payload output rc actual
  payload=$(jq -nc --arg c "$cmd" '{tool_input: {command: $c}}')
  output=$(printf '%s' "$payload" | env -i HOME="$TEST_HOME" PATH="$PATH" /usr/bin/python3 -I "$HOOK" 2>/dev/null)
  rc=$?
  actual="ERR($rc)"
  if [ "$rc" -eq 0 ] && [ -z "$output" ]; then
    actual=PASS
  elif [ "$rc" -eq 2 ] && jq -e '
    .hookSpecificOutput | .hookEventName == "PreToolUse"
    and .permissionDecision == "deny"
    and (.permissionDecisionReason | startswith("DENIED: "))
  ' <<<"$output" >/dev/null; then
    actual=BLOCK
  fi
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
run_case BLOCK 'npm --prefix web run dev'
run_case BLOCK 'pnpm --filter web dev'
run_case BLOCK 'pnpm -w dev'
run_case BLOCK 'pnpm --workspace-root dev'
run_case BLOCK 'npm -w web run dev'
run_case BLOCK 'yarn --cwd web start'
run_case BLOCK 'bun run --silent serve'
run_case BLOCK 'NODE_ENV=development npm run dev'
run_case BLOCK 'env NODE_ENV=development npm run dev'
run_case BLOCK 'command npm run dev'
run_case BLOCK 'command -- npm run dev'
run_case BLOCK 'env -i PATH="$PATH" npm run dev'
run_case BLOCK 'env -u NODE_ENV npm run dev'
run_case BLOCK 'env -u -- - - npm run dev'
run_case BLOCK 'exec pnpm dev'
run_case BLOCK 'cd web && npm run "dev"'
run_case BLOCK $'npm \\\nrun dev'
run_case PASS  'npm run build'
run_case PASS  'command -v npm'
run_case PASS  'command -V npm'
run_case PASS  'env -u dev npm test'
run_case PASS  'env NODE_ENV=test npm test'
run_case PASS  'env -- - npm run dev'
run_case PASS  'env GUARD_PROBE=x - npm run dev'
run_case PASS  "rg 'npm run dev' README.md"
run_case PASS  "printf '%s\\n' 'npm run dev'"
run_case PASS  'git commit -m "document npm run dev"'
run_case PASS  'npm --prefix dev run build'
run_case PASS  'pnpm --filter dev test'
run_case PASS  'pnpm -w build'
run_case PASS  'npm -w dev run build'
run_case PASS  'pnpm -C dev run build'

section "Common execution prefixes"
run_case BLOCK 'nohup npm run dev > /tmp/dev.log 2>&1 &'
run_case BLOCK 'nohup -- pnpm dev'
run_case BLOCK 'env NODE_ENV=development nohup pnpm dev'
run_case PASS  './scripts/exec npm run dev'
run_case PASS  'command -v npm'
run_case PASS  'env -- - npm run dev'

section "comments and literal hash words"
run_case BLOCK $'echo done # don\'t edit\nnpm run dev'
run_case BLOCK $'echo done # "unfinished quote\nyarn start'
run_case BLOCK $'# comment ending in a backslash \\\npnpm serve'
run_case PASS  $'echo done # don\'t edit\nnpm run build'
run_case PASS  'echo done; # npm run dev'
run_case PASS  "rg pattern . # 'a\\|b' --include=x -rn"
run_case BLOCK $'echo done # don\'t edit\nrg -rn pattern .'
run_case BLOCK 'echo file\ #literal; npm run dev'
run_case BLOCK 'echo file\)#literal; yarn start'
run_case BLOCK 'echo ""#literal; pnpm serve'
run_case BLOCK "echo ''#literal; npm run dev"
run_case BLOCK 'echo "#literal"; npm run dev'
run_case BLOCK 'echo \#literal; npm run dev'
run_case BLOCK $'echo file\\\n#literal; npm run dev'
run_case PASS  $'echo file \\\n# npm run dev'
run_case PASS  'echo ""#literal; npm run build'

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
run_case PASS  $'cat <<EOF\nplain body text\nEOF'
run_case PASS  $'cat <<EOF\nbody\nEOF\nrg -rn foo src/'
run_case PASS  'rg -e "-rn" file.py'
run_case BLOCK $'rg \'<<TOKEN\' src/\nfind . -name x\nTOKEN'
run_case PASS  $'git commit -m "$(cat <<\'EOF\'\nfix hook\nrg -rn foo mentioned\nEOF\n)"'

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

section "Native token and argument boundaries"
run_case BLOCK 'env "FOO=$BAR" npm run dev'
run_case BLOCK 'env FOO="$BAR" npm run dev'
run_case PASS  'env "${NAME}"=value npm run dev'
run_case PASS  'git commit -m "fix; find bug"'
run_case BLOCK '> output npm run dev'
run_case BLOCK 'nohup >output 2>&1 npm run dev'
run_case BLOCK "rg '-rn' x ."
run_case PASS  "printf '%s' '|' npm run dev"
run_case BLOCK "printf '%s' '|' ; npm run dev"
run_case PASS  "printf '%s' '{' npm run dev"

section "Complex shell execution stays outside precise policy checks"
run_case PASS  "sh -c 'npm run dev'"
run_case PASS  "eval 'rg -rn pattern README.md'"
run_case PASS  'if true; then npm run dev; fi'
run_case PASS  'echo $(find . -name x)'
run_case PASS  $'bash <<\'EOF\'\nrg -rn pattern .\nEOF'
run_case BLOCK $'cat <<EOF | rg -rn pattern README.md\nbody\nEOF'

section "Native lexer framing errors do not echo input"
payload=$(jq -nc --arg c "printf \$'\\0'" '{tool_input: {command: $c}}')
output=$(printf '%s' "$payload" | env -i HOME="$TEST_HOME" PATH="$PATH" /usr/bin/python3 -I "$HOOK" 2>"$TEST_ROOT/stderr")
rc=$?
if [ "$rc" -eq 1 ] && [ -z "$output" ] && [ "$(cat "$TEST_ROOT/stderr")" = 'PreToolUse guard could not inspect this input; normal permission checks still apply.' ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  printf '  FAIL lexer error protocol\n'
fi

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
