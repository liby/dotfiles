#!/usr/bin/env bash
# Secret and structured file cases for pre-tool-guard.py.
# Pipes fake PreToolUse payloads into the hook and asserts the exit code:
#   exit 2 = blocked, exit 0 = no hook decision.
# Run: bash pre-tool-guard-secrets.test.sh

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
mkdir -p "$TEST_HOME/.ssh/config.d" "$TEST_HOME/.ssh/known_hosts.backup" \
  "$TEST_HOME/.ssh/keys" "$TEST_HOME/.ssh/directory.pub" "$TEST_HOME/project"
touch "$TEST_HOME/.ssh/private" "$TEST_HOME/.ssh/id.pub" \
  "$TEST_HOME/.ssh/config" "$TEST_HOME/.ssh/config.work" \
  "$TEST_HOME/.ssh/allowed_signers" "$TEST_HOME/.ssh/known_hosts.old" \
  "$TEST_HOME/.ssh/config.d/private" "$TEST_HOME/.ssh/config.d/nested.pub" \
  "$TEST_HOME/.ssh/known_hosts.backup/private" "$TEST_HOME/.ssh/keys/nested.pub" \
  "$TEST_HOME/.ssh/directory.pub/private" \
  "$TEST_HOME/project/file.txt"
ln -s "$TEST_HOME/.ssh" "$TEST_HOME/project/ssh-link"
ln -s "$TEST_HOME/.ssh/private" "$TEST_HOME/project/key-link"
ln -s "$TEST_HOME/.ssh/id.pub" "$TEST_HOME/project/public-link"
ln -s "$TEST_HOME/.ssh/private" "$TEST_HOME/.ssh/deceptive.pub"
ln -s "$TEST_HOME/project" "$TEST_HOME/project-link"

section() {
  printf '\n== %s ==\n' "$1"
}

run_case() {
  local expected="$1" cmd="$2" hook_path="${3:-$PATH}" payload output rc actual
  payload=$(jq -nc --arg c "$cmd" '{tool_input: {command: $c}}')
  output=$(printf '%s' "$payload" | env -i HOME="$TEST_HOME" PATH="$hook_path" /usr/bin/python3 -I "$HOOK" 2>/dev/null)
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

run_file_case() {
  local expected="$1" path="$2" tool="${3:-Read}" payload rc actual
  payload=$(jq -nc --arg p "$path" --arg t "$tool" --arg cwd "$TEST_HOME/project" \
    '{tool_name: $t, cwd: $cwd, tool_input: {file_path: $p}}')
  echo "$payload" | env -i HOME="$TEST_HOME" PATH="$PATH" /usr/bin/python3 -I "$HOOK" >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) actual=PASS ;;
    2) actual=BLOCK ;;
    *) actual="ERR($rc)" ;;
  esac
  if [ "$actual" = "$expected" ]; then
    printf '  ok   %-5s  %s %s\n' "$actual" "$tool" "$path"
    PASS=$((PASS + 1))
  else
    printf '  FAIL want=%-5s got=%-5s  %s %s\n' "$expected" "$actual" "$tool" "$path"
    FAIL=$((FAIL + 1))
  fi
}

run_grep_case() {
  local expected="$1" path="$2" cwd="$3" glob="${4:-}" payload output rc actual
  payload=$(jq -nc --arg p "$path" --arg cwd "$cwd" --arg g "$glob" '
    {tool_name: "Grep", cwd: $cwd, tool_input: {pattern: "synthetic"}}
    | if $p != "" then .tool_input.path = $p else . end
    | if $g != "" then .tool_input.glob = $g else . end')
  output=$(cd "$TEST_HOME" && printf '%s' "$payload" | env -i HOME="$TEST_HOME" PATH="$PATH" /usr/bin/python3 -I "$HOOK")
  rc=$?
  actual="ERR($rc)"
  if [ "$rc" -eq 0 ] && [ -z "$output" ]; then
    actual=PASS
  elif [ "$rc" -eq 2 ] && jq -e '
    .hookSpecificOutput | .hookEventName == "PreToolUse"
    and .permissionDecision == "deny"
    and (.permissionDecisionReason | contains("Narrow the search"))
  ' <<<"$output" >/dev/null; then
    actual=BLOCK
  fi
  if [ "$actual" = "$expected" ]; then
    printf '  ok   %-5s  Grep path=%s cwd=%s\n' "$actual" "${path:-<default>}" "${cwd:-<default>}"
    PASS=$((PASS + 1))
  else
    printf '  FAIL want=%-5s got=%-5s  Grep path=%s cwd=%s\n' "$expected" "$actual" "$path" "$cwd"
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
run_case BLOCK 'export'
run_case BLOCK 'export | wc -l'
run_case PASS  'export FOO=bar'
run_case PASS  'export FOO'
run_case PASS  'printf "%s" "export"'
run_case BLOCK 'set'
run_case BLOCK 'set | grep FOO'
run_case PASS  'set -e'
run_case BLOCK 'set 2>/dev/null'
run_case BLOCK 'typeset -x'
run_case PASS  'declare -p GUARD_PROBE'
run_case PASS  'declare -f'
run_case PASS  'declare "$FLAGS"'
run_case PASS  './scripts/export'
run_case PASS  'env set'
run_case PASS  'command set'
run_case PASS  'env FOO=bar some-command'
run_case BLOCK 'env -0'
run_case BLOCK 'env -i'
run_case BLOCK 'env -'
run_case BLOCK 'env NAME="$VALUE"'
run_case PASS  'env NAME="$VALUE" some-command'

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
run_case BLOCK 'cat .env .env.example'
run_case BLOCK 'cat .env.example .env'
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
run_case PASS  'cat key.key.pub'
run_case BLOCK 'cat private.key public.key.pub'
run_case BLOCK 'cat public.key.pub private.key'
run_case PASS  "grep '.pem.config' file.js"
run_case PASS  "grep '.key.serialize()' cli.js"
run_case PASS  "grep 'auth.json.parse' cli.js"

section "~/.ssh: private material blocked, client config and public keys readable"
run_case BLOCK 'cat ~/.ssh/id_rsa'
run_case BLOCK 'cat ~/.ssh/deploy-key'
run_case BLOCK 'head "$HOME/.ssh/server.pem"'
run_case BLOCK 'cat ~/.ssh/config ~/.ssh/deploy-key'
run_case BLOCK 'cat .ssh/id_ed25519'
run_case PASS  'cat .ssh/id_ed25519.pub'
run_case PASS  'cat .ssh/config'
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
run_case BLOCK 'cat ~/.ssh/config.backup/private'
run_case BLOCK 'cat .ssh/known_hosts.backup/private'
run_case BLOCK 'cat ~/.ssh/directory.pub/private'
run_case PASS  'cat ~/.ssh/keys/nested.pub'
run_case PASS  'cat ~/.ssh/config.backup/nested.pub'
run_file_case BLOCK "$TEST_HOME/.ssh/config.d/private"
run_file_case BLOCK "$TEST_HOME/.ssh/known_hosts.backup/private"
run_file_case PASS  "$TEST_HOME/.ssh/config.work"
run_file_case PASS  "$TEST_HOME/.ssh/keys/nested.pub"
run_file_case BLOCK "$TEST_HOME/project/key-link"
run_file_case BLOCK 'key-link'
run_file_case BLOCK 'ssh-link/private'
run_file_case BLOCK "$TEST_HOME/.ssh/deceptive.pub"
run_file_case BLOCK "$TEST_HOME/.ssh/config.d"
run_file_case BLOCK "$TEST_HOME/.ssh/directory.pub"
run_file_case PASS  'public-link'
run_file_case PASS  'file.txt'
run_file_case BLOCK 'key-link' Edit
run_file_case PASS  'public-link' Edit
run_file_case PASS  '~/.ssh/new.pub' Write
run_file_case PASS  '~/.ssh/config.new' Write
run_file_case PASS  'new-file.txt' Write
run_file_case BLOCK 'ssh-link/new-private' Write

section "Grep SSH scope uses cwd and canonical metadata"
run_grep_case BLOCK "$TEST_HOME/.ssh/private" "$TEST_HOME/project"
run_grep_case BLOCK "$TEST_HOME/.ssh" "$TEST_HOME/project"
run_grep_case BLOCK "$TEST_HOME" "$TEST_HOME/project" '*.js'
run_grep_case BLOCK "$TEST_ROOT" "$TEST_HOME/project" '!**/.ssh/**'
run_grep_case BLOCK '/' "$TEST_HOME/project"
run_grep_case BLOCK '.ssh' "$TEST_HOME"
run_grep_case BLOCK '../.ssh/private' "$TEST_HOME/project"
run_grep_case BLOCK '' "$TEST_HOME"
run_grep_case BLOCK '' ''
run_grep_case BLOCK 'project/ssh-link' "$TEST_HOME"
run_grep_case BLOCK 'project/key-link' "$TEST_HOME"
run_grep_case BLOCK '.ssh/deceptive.pub' "$TEST_HOME"
run_grep_case BLOCK '.ssh/config.d' "$TEST_HOME"
run_grep_case BLOCK '.ssh/config.d/private' "$TEST_HOME"
run_grep_case BLOCK '.ssh/known_hosts.backup/private' "$TEST_HOME"
run_grep_case BLOCK '.ssh/known_hosts.backup' "$TEST_HOME"
run_grep_case BLOCK '.ssh/directory.pub' "$TEST_HOME"
run_grep_case BLOCK '.ssh/directory.pub/private' "$TEST_HOME"
if [ -d "$TEST_HOME/.SSH" ]; then
  run_grep_case BLOCK '.SSH/private' "$TEST_HOME"
fi
run_grep_case PASS  '~/.ssh/id.pub' "$TEST_HOME/project"
run_grep_case PASS  '.ssh/config' "$TEST_HOME"
run_grep_case PASS  '.ssh/config.work' "$TEST_HOME"
run_grep_case PASS  '.ssh/allowed_signers' "$TEST_HOME"
run_grep_case PASS  '.ssh/known_hosts.old' "$TEST_HOME"
run_grep_case PASS  '.ssh/keys/nested.pub' "$TEST_HOME"
run_grep_case PASS  '.ssh/config.d/nested.pub' "$TEST_HOME"
run_grep_case PASS  "$TEST_HOME/project" "$TEST_HOME"
run_grep_case PASS  'file.txt' "$TEST_HOME/project"
run_grep_case PASS  '' "$TEST_HOME/project"
run_grep_case PASS  'project-link' "$TEST_HOME"

section "curl verbose"
run_case BLOCK 'curl -v https://example.com'
run_case BLOCK 'curl --verbose https://example.com'
run_case BLOCK 'curl -sv https://example.test'
run_case BLOCK 'curl --trace - https://example.test'
run_case BLOCK 'curl --trace=- https://example.test'
run_case BLOCK 'curl --trace-ascii - https://example.test'
run_case BLOCK 'curl --trace-ascii=- https://example.test'
run_case PASS  'curl https://example.com'
run_case PASS  'curl -s https://example.test'
run_case PASS  'curl --trace-time https://example.test'

section "Credential-fetching commands"
run_case BLOCK 'gh auth token'
run_case BLOCK 'gh auth status --show-token'
run_case BLOCK 'gh auth status -t'
run_case BLOCK 'gh auth status --show-token=false'
run_case BLOCK 'gh auth status -t --show-token=false'
run_case BLOCK 'gh auth status -at'
run_case BLOCK 'gh auth status -th example.test'
run_case PASS  'gh auth status'
run_case PASS  'gh auth status --hostname example.test'
run_case PASS  'gh auth status --hostname -t'
run_case PASS  "gh auth status --template '-t' --json hosts"
run_case PASS  'gh auth status -- -t'
run_case PASS  'printf "%s" "gh auth status --show-token"'
run_case PASS  "printf '%s' '|' gh auth status -t"
run_case BLOCK 'printf done | gh auth status -at'
run_case BLOCK 'gh auth status -t # --help'
run_case BLOCK 'gh auth status -t > --show-token=false'
run_case PASS  'gh auth status > -t'

section "Compound commands and static words"
run_case PASS  'grep foo log; rm .env'
run_case BLOCK 'cd foo && cat .env'
run_case BLOCK 'grep .env file; echo ok'
run_case BLOCK 'echo ok && cat ~/.ssh/id_rsa'
run_case BLOCK 'test -e .env || cat .env'
run_case BLOCK 'cd foo && env'
run_case BLOCK 'echo hi; printenv'
run_case BLOCK 'true; env'
run_case BLOCK 'true && export'
run_case BLOCK 'true; set'
run_case PASS  'echo "foo;bar baz"'
run_case PASS  'echo foo\;bar'
run_case PASS  "echo 'foo;bar'"
run_case BLOCK $'cat \\\n  .env'
run_case BLOCK $'cat \\\n  auth.json'
run_case BLOCK $'ca\\\nt .env'
run_case PASS  $'cat \\\n  .env.example'
run_case PASS  $'printf "%s" "hello\\\nworld"'
run_case PASS  $'printf "%s" "hello\nworld"'
run_case BLOCK $'cat "\\\n.env"'
run_case BLOCK "printf '%s' file\\ #1; env"
run_case BLOCK "printf '%s' file\\)#1; env"
run_case BLOCK $'printf "%s" file\\\n#1; env'
run_case BLOCK "printf '%s' 'file '#1; env"
run_case BLOCK 'printf "%s" "file "#1; env'
run_case PASS  "printf '%s' file #1; env"
run_case PASS  $'printf "%s" file \\\n#1; env'
run_case PASS  'printf "%s" file; # comment; env'
run_case BLOCK $'# a comment ending in a backslash \\\nenv'
run_case PASS  $'# a comment ending in a backslash \\\necho safe'

section "Command substitution (\$() and backticks)"
run_case BLOCK 'echo $(cat .env)'
run_case BLOCK 'echo $(cat auth.json)'
run_case BLOCK 'result=$(cat .env.production)'
run_case BLOCK 'echo `cat .env`'
run_case BLOCK 'echo `cat ~/.ssh/id_rsa`'

section "Sensitive signatures also match heredoc data"
run_case BLOCK $'cat <<EOF\ncat .env\nEOF'
run_case BLOCK $'git commit -m "$(cat <<\'EOF\'\ndocs mention cat .env here\nEOF\n)"'
run_case PASS  $'cat <<EOF\nhello world\nEOF'
run_case BLOCK $'cat .env <<EOF\nsome body\nEOF'
run_case BLOCK $'rg \'<<TOKEN\' src/\ncat .env\nTOKEN'
run_case BLOCK $'echo "<<EOF is the marker"\ncat .env\nEOF'
run_case BLOCK $'cat <<EOF\ntext with an unmatched apostrophe: \x27\nEOF\nenv'

section "echo/printf referencing secret variables"
run_case BLOCK 'echo "$API_KEY"'
run_case BLOCK 'echo "$GITHUB_TOKEN"'
run_case BLOCK 'echo $MY_SECRET'
run_case BLOCK 'printf "%s" "$DB_PASSWORD"'
run_case BLOCK 'echo "${ANTHROPIC_API_KEY}"'
run_case BLOCK 'echo "${value:-$API_KEY}"'
run_case PASS  'echo "hello"'
run_case PASS  'echo "$HOME"'
run_case PASS  'printf "%s\n" "$USER"'
run_case BLOCK 'printf "%s" "\$API_KEY"'
run_case PASS  "printf '%s' '$'API_KEY"

section "Sensitive signatures do not depend on parsing native Zsh"
run_case BLOCK 'repeat 2 do cat .env; done'
run_case BLOCK 'repeat 2 cat .env'
run_case BLOCK '{ printf ready; } always { cat .env; }'
run_case BLOCK 'repeat 2 do cat .env; done' "$TEST_ROOT"

section "Sensitive signatures also match literal examples and comments"
run_case BLOCK "printf '%s' 'gh auth token'"
run_case BLOCK "printf '%s' 'printenv'"
run_case BLOCK $'python3 <<\'PY\'\nprint("cat .env")\nPY'
run_case BLOCK $'python3 - <<\'PY\'\n# cat .env\nprint("done")\nPY'
run_case BLOCK "python3 -c 'print(\"done\")' 'cat .env'"

section "Normal clients consume their own credential inputs"
run_case PASS  'node --env-file=.env.local app.js'
run_case PASS  'dotenvx run -f .env -- bun test'
run_case PASS  'npm --userconfig ~/.npmrc install'
run_case PASS  'ssh -i ~/.ssh/deploy-key example.test'
run_case BLOCK 'GH_HOST=github.test /opt/homebrew/bin/gh auth status -t'
run_case PASS  "env -S 'client arguments'"

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
