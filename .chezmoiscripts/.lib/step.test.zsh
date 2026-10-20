#!/bin/zsh
set -euo pipefail
setopt extended_glob
unset CHEZMOI_VERBOSE

lib=${0:A:h}/step.zsh
test_root=$(mktemp -d "${TMPDIR:-/tmp}/step-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

mkdir "$test_root/bin"
path=("$test_root/bin" $path)
export FIXTURE_ARGS=$test_root/args FIXTURE_EXIT
export FIXTURE_STDOUT='stdout\text' FIXTURE_STDERR='stderr\text'
# The fixture prints text its command line does not contain, so finding that text proves its output
# appeared; the backslash shows the output arrives unchanged. It records its arguments and fails if
# stdin has data.
cat >"$test_root/bin/fixture" <<'EOF'
#!/bin/sh
if read -r line; then exit 9; fi
printf '%s|' "$@" >"$FIXTURE_ARGS"
printf '%s\n' "$FIXTURE_STDOUT"
printf '%s\n' "$FIXTURE_STDERR" >&2
exit "$FIXTURE_EXIT"
EOF
chmod +x "$test_root/bin/fixture"
cmd=(fixture 'a b' "it's" '' '$HOME')

# Runs `step` on the fixture, with an optional prefix assignment and redirection, in a script that
# sources the library. stdin carries data so that a command reading it instead of /dev/null is caught.
run() {
  FIXTURE_EXIT=$1
  rm -f -- $FIXTURE_ARGS
  code=0
  out=$(print -r -- "stdin data" |
    zsh -c "set -euo pipefail; source ${(q)lib}; ${2-} step ${(j: :)${(@q)cmd}} ${3-}; exit 0" 2>"$test_root/err") ||
    code=$?
  err=$(<"$test_root/err")
  lines=("${(@f)err}")
}

# Each scenario states its whole outcome, so no part of it can change unnoticed: the exit status,
# the exact stdout, one pattern per stderr line, and the arguments the fixture received.
expect() {
  local want_code=$1 want_out=$2 i
  shift 2
  [[ $code == $want_code && $out == $want_out && ${#lines} == $# ]] || return 1
  for (( i = 1; i <= $#; i++ )); do
    [[ $lines[i] == ${~argv[i]} ]] || return 1
  done
  [[ $(<$FIXTURE_ARGS) == "${(pj:|:)cmd[2,-1]}|" ]]
}

fail() {
  print -u2 -lr -- "FAIL: $1" "stdout: ${(V)out}" "stderr: ${(V)err}"
  exit 1
}

# A status line is a marker and the command. The markers are free to change, so the first runs
# learn them; every status line after that must use the right one.
run 0
label=${lines[1]#* } succeeded=${lines[1]%% *}
run 37
failed=${lines[1]%% *}
run 0 CHEZMOI_VERBOSE=1
running=${lines[1]%% *}
markers=($succeeded $failed $running)
(( ${#${(@u)markers}} == 3 )) && [[ $markers != *$'\e'* ]] ||
  fail "success, failure, and running lines carry distinct markers without escape codes"
{ eval "rerun=($label)" && [[ ${(pj:\0:)rerun} == "${(pj:\0:)cmd}" ]] } ||
  fail "the status line reruns as the exact command"
label_pattern=${(b)label}
succeeded_line="${(b)succeeded} $label_pattern" failed_line="${(b)failed} $label_pattern"
running_line="${(b)running} $label_pattern"
replayed=("*${(b)FIXTURE_STDOUT}" "*${(b)FIXTURE_STDERR}")

run 0
expect 0 '' $succeeded_line || fail "success prints one status line, to stderr"

run 37
expect 37 '' "$failed_line *37*" $replayed ||
  fail "failure prints the exit status, replays both streams to stderr, and stops the script"

run 0 CHEZMOI_VERBOSE=1
expect 0 $FIXTURE_STDOUT $running_line ${(b)FIXTURE_STDERR} $succeeded_line ||
  fail "verbose streams output between status lines"

run 37 CHEZMOI_VERBOSE=1
expect 37 $FIXTURE_STDOUT $running_line ${(b)FIXTURE_STDERR} "$failed_line *37*" ||
  fail "verbose stops the script on failure"

# With stdout sent to stderr too, one stream shows whether output arrived while the command ran.
run 0 CHEZMOI_VERBOSE=1 '>&2'
expect 0 '' $running_line ${(b)FIXTURE_STDOUT} ${(b)FIXTURE_STDERR} $succeeded_line ||
  fail "verbose shows the output while the command runs"

# stderr is not a terminal here, so the terminal path is forced after sourcing; detecting the
# terminal stays untested. The running line comes first, and the result overwrites it; a marker
# may carry color here.
open=$'\e[?7l' close=$'\e[?7h\r\e[K'
in_place="${(b)open}*${(b)running}* $label_pattern${(b)close}"
run 0 step_tty=1
expect 0 '' "$in_place*${(b)succeeded}* $label_pattern" ||
  fail "the terminal shows the command in place, then its result"

# 1 is the commonest failure status.
run 1 step_tty=1
expect 1 '' "$in_place*${(b)failed}* $label_pattern *1*" $replayed ||
  fail "the terminal replays a failed command's output"

print -r -- "step library tests passed"
