#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h:h:h:h}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/claude-launcher.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

test_home=$test_root/home
test_bin=$test_root/bin
trace_file=$test_root/trace
mode_file=$test_home/.config/claude-code/mode
launcher=$test_home/.local/share/claude-launcher/bin/claude
native=$test_home/.local/bin/claude
mkdir -p "${launcher:h}" "${native:h}" "${mode_file:h}" "$test_bin"
cp "$repo_root/dot_zshenv" "$test_home/.zshenv"
cp "$repo_root/dot_local/share/claude-launcher/bin/executable_claude" "$launcher"
# The gateway contract's variables, which together select the gateway in Claude Code.
gateway_vars=(ANTHROPIC_AUTH_TOKEN ANTHROPIC_VERTEX_BASE_URL ANTHROPIC_VERTEX_PROJECT_ID CLAUDE_CODE_SKIP_VERTEX_AUTH CLAUDE_CODE_USE_VERTEX)

{
  print -r -- '#!/bin/zsh -f'
  print -r -- 'local -a present; for name in ${=GATEWAY_VARS}; do [[ -n ${(P)name+x} ]] && present+=$name; done'
  print -r -- 'print -r -- "claude ${(qqq)@}${present:+ with $present}" >> "$TRACE_FILE"'
} > "$native"
# Like the real envchain, run the named command; a bare `claude` would loop back into the launcher.
{
  print -r -- '#!/bin/zsh -f'
  print -r -- 'if [[ ${1-} == --list ]]; then'
  # Listing one namespace decrypts its values, so the trace records it.
  print -r -- '  (( $# == 2 )) && { print -r -- "envchain --list $2" >> "$TRACE_FILE"; print -l -- ${=GATEWAY_VARS}; exit 0 }'
  print -r -- '  print -r -- "${NAMESPACE_LIST-}"'
  print -r -- '  exit 0'
  print -r -- 'fi'
  print -r -- '[[ ${1-} == claude-gateway && ${2-} == "$NATIVE_CLAUDE" ]] || { print -u2 -- "FAIL: envchain got ${(qqq)@}"; exit 64 }'
  print -r -- 'print -r -- "envchain ${(qqq)@}" >> "$TRACE_FILE"'
  print -r -- 'shift'
  print -r -- 'for name in ${=GATEWAY_VARS}; do export $name=synthetic; done'
  print -r -- 'exec "$@"'
} > "$test_bin/envchain"
chmod +x "$launcher" "$native" "$test_bin/envchain"

typeset -a isolated_env=(
  HOME="$test_home"
  ZDOTDIR="$test_home"
  XDG_CONFIG_HOME="$test_home/.config"
  PATH="$test_bin:/usr/bin:/bin"
  TRACE_FILE="$trace_file"
  NATIVE_CLAUDE="$native"
  GATEWAY_VARS="$gateway_vars"
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
  /usr/bin/env -i "${isolated_env[@]}" "${inherited_env[@]}" NAMESPACE_LIST="$namespace_list" /bin/zsh -c 'claude "$@"' synthetic "$@"
}
typeset -a inherited_env=()

# Pi runs commands in bash, which inherits PATH but no zsh functions.
for shell in /bin/zsh /bin/bash; do
  resolution=$(/usr/bin/env -i "${isolated_env[@]}" /bin/zsh -c '"$1" -c "command -v claude"' synthetic "$shell")
  assert_equal "$resolution" "$launcher" "$shell did not resolve claude to the launcher ahead of the native install"
done

typeset -a claude_args=(
  --resume
  "session with spaces"
  ""
  '*'
)
expected_claude=$(format_call claude "${claude_args[@]}")
typeset -a gateway_args=(claude-gateway "$native" "${claude_args[@]}")
expected_gateway="$(format_call envchain "${gateway_args[@]}")"$'\n'"$expected_claude with $gateway_vars"

run_claude subscription claude-gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "subscription mode did not call only the native Claude executable"

run_claude gateway claude-gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_gateway" "gateway mode did not route the native executable through the isolated envchain namespace"

run_claude subscription claude-gateway --gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_gateway" "--gateway did not override the persisted subscription mode"

run_claude gateway claude-gateway --subscription "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "--subscription did not override the persisted gateway mode"

# A claude started from inside a gateway session inherits the namespace's variables. Clearing them
# must not depend on envchain, which decrypts a namespace to list it and may be unavailable.
inherited_env=(${^gateway_vars}=inherited)
run_claude subscription claude-gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "subscription mode passed an inherited gateway variable to Claude or asked envchain for it"
inherited_env=()

missing_error_file=$test_root/missing-namespace.err
if run_claude gateway unavailable "${claude_args[@]}" 2> "$missing_error_file"; then
  print -u2 -- "FAIL: gateway mode accepted a missing namespace"
  exit 1
fi
assert_equal "$(< "$trace_file")" "" "missing namespace invoked a Claude executable"
assert_equal "$(< "$missing_error_file")" "claude: envchain namespace claude-gateway not found" "missing namespace did not fail with the launcher error"

print -r -- "claude launcher tests passed"
