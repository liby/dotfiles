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
cp "$repo_root/dot_zprofile" "$test_home/.zprofile"
cp "$repo_root/dot_local/share/claude-launcher/bin/executable_claude" "$launcher"
# The gateway contract's variables, which together select the gateway in Claude Code.
entry_vars=(ANTHROPIC_AUTH_TOKEN ANTHROPIC_VERTEX_BASE_URL ANTHROPIC_VERTEX_PROJECT_ID)
gateway_vars=($entry_vars CLAUDE_CODE_SKIP_VERTEX_AUTH CLAUDE_CODE_USE_VERTEX)

{
  print -r -- '#!/bin/zsh -f'
  print -r -- 'local -a present; for name in ${=GATEWAY_VARS}; do [[ -n ${(P)name+x} ]] && present+=$name=${(P)name}; done'
  print -r -- 'print -r -- "claude ${(qqq)@}${present:+ with $present}" >> "$TRACE_FILE"'
} > "$native"
# Exits 11, mk's status for an entry without program access, for UNGRANTED_ENTRY.
{
  print -r -- '#!/bin/zsh -f'
  print -r -- 'print -r -- "mk ${(qqq)@}" >> "$TRACE_FILE"'
  print -r -- '[[ $2 == "${UNGRANTED_ENTRY-}" ]] && exit 11'
  print -r -- 'print -rn -- "synthetic-${2#*/}"'
} > "$test_bin/mk"
chmod +x "$launcher" "$native" "$test_bin/mk"

typeset -a isolated_env=(
  HOME="$test_home"
  ZDOTDIR="$test_home"
  XDG_CONFIG_HOME="$test_home/.config"
  PATH="$test_bin:/usr/bin:/bin"
  TRACE_FILE="$trace_file"
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
  shift
  : > "$trace_file"
  print -rn -- "$mode" > "$mode_file"
  /usr/bin/env -i "${isolated_env[@]}" "${inherited_env[@]}" /bin/zsh -c 'claude "$@"' synthetic "$@"
}
typeset -a inherited_env=()

# Pi runs commands in bash, which inherits PATH but no zsh functions.
for shell in /bin/zsh /bin/bash; do
  resolution=$(/usr/bin/env -i "${isolated_env[@]}" /bin/zsh -c '"$1" -c "command -v claude"' synthetic "$shell")
  assert_equal "$resolution" "$launcher" "$shell did not resolve claude to the launcher ahead of the native install"
done
# Without a shell snapshot, Codex and Claude Code run commands in a non-interactive login shell.
resolution=$(/usr/bin/env -i "${isolated_env[@]}" /bin/zsh -lc 'print -r -- $path[1] ${HOMEBREW_PREFIX-}')
assert_equal "$resolution" "$test_home/.proto/shims /opt/homebrew" "a login shell did not load Homebrew's environment or put the zshenv toolchain back ahead of it"

typeset -a claude_args=(
  --resume
  "session with spaces"
  ""
  '*'
)
expected_claude=$(format_call claude "${claude_args[@]}")
expected_mk_gets=$(for name in $entry_vars; do format_call mk get claude-gateway/$name; done)
expected_gateway="$expected_mk_gets"$'\n'"$expected_claude with ANTHROPIC_AUTH_TOKEN=synthetic-ANTHROPIC_AUTH_TOKEN ANTHROPIC_VERTEX_BASE_URL=synthetic-ANTHROPIC_VERTEX_BASE_URL ANTHROPIC_VERTEX_PROJECT_ID=synthetic-ANTHROPIC_VERTEX_PROJECT_ID CLAUDE_CODE_SKIP_VERTEX_AUTH=1 CLAUDE_CODE_USE_VERTEX=1"

run_claude subscription "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "subscription mode did not call only the native Claude executable"

run_claude gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_gateway" "gateway mode did not give the native executable the gateway entries from mk and the switches"

run_claude subscription --gateway "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_gateway" "--gateway did not override the persisted subscription mode"

run_claude gateway --subscription "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "--subscription did not override the persisted gateway mode"

# A claude started from inside a gateway session inherits its variables. Clearing them must not
# depend on mk, which may be unavailable.
inherited_env=(${^gateway_vars}=inherited)
run_claude subscription "${claude_args[@]}"
assert_equal "$(< "$trace_file")" "$expected_claude" "subscription mode passed an inherited gateway variable to Claude or ran mk"
inherited_env=()

# An entry without program access must stop the launch with mk's status rather than start Claude
# without that variable.
inherited_env=(UNGRANTED_ENTRY=claude-gateway/ANTHROPIC_VERTEX_PROJECT_ID)
launch_status=0
run_claude gateway "${claude_args[@]}" || launch_status=$?
assert_equal "$launch_status $(< "$trace_file")" "11 $expected_mk_gets" "a failed mk get did not stop the launch with its status"
inherited_env=()

print -r -- "claude launcher tests passed"
