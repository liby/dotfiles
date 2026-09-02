#!/usr/bin/env bash
# Test harness for pre-bash-guard-secrets.sh.
# Pipes fake PreToolUse payloads into the hook and asserts the exit code:
#   exit 2 = blocked, exit 0 = allowed.
# Run: bash pre-bash-guard-secrets.test.sh

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/pre-bash-guard-secrets.sh"
[ -x "$HOOK" ] || HOOK="$(cd "$(dirname "$0")" && pwd)/executable_pre-bash-guard-secrets.sh"

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

run_file_case() {
  local expected="$1" path="$2" payload rc actual
  payload=$(jq -nc --arg p "$path" '{tool_name: "Read", tool_input: {file_path: $p}}')
  echo "$payload" | bash "$HOOK" >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) actual=PASS ;;
    2) actual=BLOCK ;;
    *) actual="ERR($rc)" ;;
  esac
  if [ "$actual" = "$expected" ]; then
    printf '  ok   %-5s  Read %s\n' "$actual" "$path"
    PASS=$((PASS + 1))
  else
    printf '  FAIL want=%-5s got=%-5s  Read %s\n' "$expected" "$actual" "$path"
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
run_case BLOCK 'rg E2B_API_KEY .env.local'
run_case BLOCK 'rg secret .env'
run_case BLOCK 'rg -n foo /path/to/.env'
run_case BLOCK 'rg API_KEY .env.production'
run_case BLOCK 'ag pattern .env'
run_case BLOCK 'ack token .env.staging'
run_case PASS  'cat .env.example'
run_case PASS  'cat .env.sample'
run_case PASS  'cat .env.template'
run_case PASS  'cat .env.age'
run_case PASS  "grep -E 'process\.env\.\w+' cli.js"
run_case PASS  'grep "process.env.ANTHROPIC_API_KEY" cli.js'
run_case PASS  'rg process.env cli.js'
run_case PASS  'rg "process.env.E2B_API_KEY" cli.js'
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

section "~/.ssh: private material blocked, client config and public keys readable"
run_case BLOCK 'cat ~/.ssh/id_rsa'
run_case BLOCK 'cat ~/.ssh/deploy-key'
run_case BLOCK 'head "$HOME/.ssh/server.pem"'
run_case BLOCK 'cat ~/.ssh/config ~/.ssh/deploy-key'
run_case PASS  'cat ~/.ssh/id_rsa.pub'
run_case PASS  'cat ~/.ssh/config'
run_case PASS  'cat ~/.ssh/config.work'
run_case PASS  'cat ~/.ssh/allowed_signers'
run_case PASS  'grep github ~/.ssh/known_hosts'
run_case PASS  'echo $(cat ~/.ssh/id_rsa.pub)'
run_case PASS  'ssh -i ~/.ssh/deploy-key example.test'
run_file_case BLOCK '/Users/me/.ssh/id_ed25519'
run_file_case BLOCK '/Users/me/.ssh/deploy-key'
run_file_case PASS  '/Users/me/.ssh/id_ed25519.pub'
run_file_case PASS  '/Users/me/.ssh/config.work'
run_file_case PASS  '/Users/me/.zshrc'

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
# The trailing path boundary must include the subshell closer so secret reads
# inside $() and `...` still block.
run_case BLOCK 'echo $(cat .env)'
run_case BLOCK 'echo $(cat auth.json)'
run_case BLOCK 'result=$(cat .env.production)'
run_case BLOCK 'echo `cat .env`'
run_case BLOCK 'echo `cat ~/.ssh/id_rsa`'

section "Heredoc bodies (intentional fail-closed)"
# Heredoc bodies are scanned as command text: no heuristic parser can
# safely tell a real `<<DELIM` opener from lookalike text, and misreading
# one deletes executable lines from the inspected command — a fail-open
# deny bypass. False-blocking a body that quotes a deny signature is the
# accepted trade (see parse_command in _lib.sh).
run_case BLOCK $'cat <<EOF\ncat .env\nEOF'
run_case BLOCK $'git commit -m "$(cat <<\'EOF\'\ndocs mention cat .env here\nEOF\n)"'
# Benign heredoc bodies still pass — only signature-bearing lines block.
run_case PASS  $'cat <<EOF\nhello world\nEOF'
# Opening heredoc itself with secret in the command line still blocks
run_case BLOCK $'cat .env <<EOF\nsome body\nEOF'
# Lookalike <<WORD text must never swallow a real command that follows it
# (the fail-open direction this design rules out).
run_case BLOCK $'rg \'<<TOKEN\' src/\ncat .env\nTOKEN'
run_case BLOCK $'echo "<<EOF is the marker"\ncat .env\nEOF'

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
