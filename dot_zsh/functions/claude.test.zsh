#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h:h}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/claude-launcher.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

test_home=$test_root/home
test_bin=$test_root/bin
trace_file=$test_root/trace
mode_file=$test_home/.config/claude-code/mode
mkdir -p "$test_home/.zsh/functions" "${mode_file:h}" "$test_bin"
cp "$repo_root/dot_zshenv" "$test_home/.zshenv"
cp "$repo_root/dot_zsh/functions/claude" "$test_home/.zsh/functions/claude"

{
  print -r -- '#!/bin/zsh -f'
  print -r -- 'print -r -- "claude ${(qqq)@}" >> "$TRACE_FILE"'
} > "$test_bin/claude"
{
  print -r -- '#!/bin/zsh -f'
  print -r -- 'if [[ ${1-} == --list ]]; then'
  print -r -- '  print -r -- envchain-list >> "$TRACE_FILE"'
  print -r -- '  print -r -- "${NAMESPACE_LIST-}"'
  print -r -- '  exit 0'
  print -r -- 'fi'
  print -r -- '[[ ${1-} == claude-gateway && ${2-} == claude ]] || exit 64'
  print -r -- 'print -r -- "envchain ${(qqq)@}" >> "$TRACE_FILE"'
  print -r -- 'shift 2'
  print -r -- 'exec "$FAKE_CLAUDE" "$@"'
} > "$test_bin/envchain"
chmod +x "$test_bin/claude" "$test_bin/envchain"

typeset -a isolated_env=(
  HOME="$test_home"
  ZDOTDIR="$test_home"
  XDG_CONFIG_HOME="$test_home/.config"
  PATH="$test_bin:/usr/bin:/bin"
  TRACE_FILE="$trace_file"
  FAKE_CLAUDE="$test_bin/claude"
)

assert_equal() {
  local actual=$1 expected=$2 label=$3
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -- "FAIL: $label"
    print -u2 -- "expected: ${(qqq)expected}"
    print -u2 -- "actual:   ${(qqq)actual}"
    exit 1
  fi
}

format_call() {
  local command=$1
  shift
  print -r -- "$command ${(qqq)@}"
}

run_claude() {
  local mode=$1
  local namespace_list=$2
  shift 2
  : > "$trace_file"
  print -rn -- "$mode" > "$mode_file"
  /usr/bin/env -i "${isolated_env[@]}" NAMESPACE_LIST="$namespace_list" /bin/zsh -c 'claude "$@"' synthetic "$@"
}

resolution=$(/usr/bin/env -i "${isolated_env[@]}" /bin/zsh -c 'autoload +X claude; print -r -- "$(whence -w claude)|${functions_source[claude]-}"')
assert_equal "$resolution" "claude: function|$test_home/.zsh/functions/claude" "non-interactive zsh did not load the isolated launcher"

typeset -a claude_args=(
  --resume
  "session with spaces"
  ""
  '*'
)
expected_claude=$(format_call claude "${claude_args[@]}")
typeset -a gateway_args=(claude-gateway claude "${claude_args[@]}")
expected_gateway=$'envchain-list\n'"$(format_call envchain "${gateway_args[@]}")"$'\n'"$expected_claude"

run_claude subscription claude-gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "subscription mode did not call only the native Claude executable"

run_claude gateway claude-gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_gateway" "gateway mode did not route through the isolated envchain namespace"

run_claude subscription claude-gateway --gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_gateway" "--gateway did not override the persisted subscription mode"

run_claude gateway claude-gateway --subscription "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "--subscription did not override the persisted gateway mode"

missing_error_file=$test_root/missing-namespace.err
if run_claude gateway unavailable "${claude_args[@]}" 2> "$missing_error_file"; then
  print -u2 -- "FAIL: gateway mode accepted a missing namespace"
  exit 1
fi
assert_equal "$(< "$trace_file")" "envchain-list" "missing namespace invoked a Claude executable"
assert_equal "$(< "$missing_error_file")" "claude: envchain namespace claude-gateway not found" "missing namespace did not fail with the launcher error"

print -r -- "claude launcher tests passed"
