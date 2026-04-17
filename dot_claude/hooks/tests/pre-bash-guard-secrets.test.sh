#!/usr/bin/env bash
# Test harness for pre-bash-guard-secrets.sh.
# Pipes fake PreToolUse payloads into the hook and asserts the exit code:
#   exit 2 = blocked, exit 0 = allowed.
# Run: bash pre-bash-guard-secrets.test.sh

set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-bash-guard-secrets.sh"
[ -x "$HOOK" ] || HOOK="$(cd "$(dirname "$0")/.." && pwd)/executable_pre-bash-guard-secrets.sh"

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

section "Env dump commands"
run_case BLOCK 'printenv'
run_case BLOCK 'printenv HOME'
run_case BLOCK 'env'
run_case BLOCK 'env | grep HOME'
run_case BLOCK 'declare -xp'
run_case BLOCK 'export -p'
run_case BLOCK 'set'
run_case BLOCK 'set | grep FOO'
run_case PASS  'set -e'
run_case PASS  'env FOO=bar some-command'

section ".env files"
run_case BLOCK 'cat .env'
run_case BLOCK 'cat .env.local'
run_case BLOCK 'cat .env.production'
run_case BLOCK 'cat /path/to/.env'
run_case BLOCK 'cat ./project/.env'
run_case BLOCK 'tar czf backup.tgz .env'
run_case BLOCK 'sed -n 1,5p .env'
run_case BLOCK 'cat ".env"'
run_case BLOCK 'cat .env; echo done'
run_case PASS  'cat .env.example'
run_case PASS  'cat .env.sample'
run_case PASS  'cat .env.template'
run_case PASS  'cat .env.age'
run_case PASS  "grep -E 'process\.env\.\w+' cli.js"
run_case PASS  'grep "process.env.ANTHROPIC_API_KEY" cli.js'
run_case PASS  'rg process.env cli.js'
run_case PASS  "grep -r 'CLAUDE_CODE_' node_modules/"

section "Sensitive files"
run_case BLOCK 'cat ~/.npmrc'
run_case BLOCK 'cat /etc/ssl/private.key'
run_case BLOCK 'cat key.pem'
run_case BLOCK 'cat auth.json'
run_case BLOCK 'cat ~/.zsh_history'
run_case BLOCK 'cat ~/.zprofile'
run_case BLOCK 'cat ~/.gnupg/private-keys-v1.d/foo.key'
run_case PASS  'cat key.pem.pub'
run_case PASS  "grep '.pem.config' file.js"
run_case PASS  "grep '.key.serialize()' cli.js"
run_case PASS  "grep 'auth.json.parse' cli.js"

section "SSH private keys"
run_case BLOCK 'cat ~/.ssh/id_rsa'
run_case PASS  'cat ~/.ssh/id_rsa.pub'

section "curl verbose"
run_case BLOCK 'curl -v https://example.com'
run_case BLOCK 'curl --verbose https://example.com'
run_case PASS  'curl https://example.com'

section "Credential-fetching commands"
run_case BLOCK 'gh auth token'
run_case PASS  'gh auth status'

section "Compound commands (segment splitting)"
run_case PASS  'grep foo log; rm .env'
run_case BLOCK 'cd foo && cat .env'
run_case BLOCK 'grep .env file; echo ok'
run_case BLOCK 'echo ok && cat ~/.ssh/id_rsa'
run_case BLOCK 'test -e .env || cat .env'
run_case BLOCK 'cd foo && env'
run_case BLOCK 'echo hi; printenv'
run_case PASS  'echo "foo;bar baz"'
run_case PASS  'echo foo\;bar'
run_case PASS  "echo 'foo;bar'"

section "Command substitution (\$() and backticks)"
# Secret reads inside $() and `...` must still block — the subshell closer
# was missing from the trailing path-boundary class before this fix.
run_case BLOCK 'echo $(cat .env)'
run_case BLOCK 'echo $(cat auth.json)'
run_case BLOCK 'result=$(cat .env.production)'
run_case BLOCK 'echo `cat .env`'
run_case BLOCK 'echo `cat ~/.ssh/id_rsa`'

section "Heredoc body stripping"
# Body of a heredoc is not executable — parse_command must strip it so the
# rule engine does not scan literal lines like "cat .env".
run_case PASS  $'cat <<EOF\ncat .env\nEOF'
run_case PASS  $'cat <<END-1\ncat .env\nEND-1'
run_case PASS  $'cat <<EOF_1\nprintenv\nEOF_1'
run_case PASS  $'cat <<\'END\'\ncat .env\nEND'
run_case PASS  $'cat <<-END\n\tcat .env\nEND'
# Opening heredoc itself with secret in the command line still blocks
run_case BLOCK $'cat .env <<EOF\nsome body\nEOF'

section "echo/printf referencing secret variables"
run_case BLOCK 'echo "$API_KEY"'
run_case BLOCK 'echo "$GITHUB_TOKEN"'
run_case BLOCK 'echo $MY_SECRET'
run_case BLOCK 'printf "%s" "$DB_PASSWORD"'
run_case BLOCK 'echo "${ANTHROPIC_API_KEY}"'
run_case PASS  'echo "hello"'
run_case PASS  'echo "$HOME"'
run_case PASS  'printf "%s\n" "$USER"'

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
