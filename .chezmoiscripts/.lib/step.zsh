step_tty=0 step_yellow= step_green= step_red= step_reset=
if [[ -t 2 ]]; then
  step_tty=1 step_yellow=$'\e[33m' step_green=$'\e[32m' step_red=$'\e[31m' step_reset=$'\e[0m'
fi

# Pass one external command, never a shell function: zsh suspends `set -e` inside a function called
# here, so it would continue past its first failure. stdin is /dev/null so that a prompt on stdin
# ends the command instead of waiting unseen. The label is the exact command, so it can be copied
# from a failed line and rerun.
step() {
  local label=${(j: :)${(q-)@}} output= code=0
  if [[ -n ${CHEZMOI_VERBOSE-} ]]; then
    print -u2 -r -- "$step_yellow◔$step_reset $label"
    "$@" </dev/null || code=$?
  else
    # Autowrap is off for this one write so the terminal keeps a long label on one row, which
    # `\r\e[K` can clear; a wrapped line would leave its upper rows on screen.
    (( step_tty )) && print -u2 -nr -- $'\e[?7l'"$step_yellow◔$step_reset $label"$'\e[?7h'
    output=$("$@" 2>&1 </dev/null) || code=$?
    (( step_tty )) && print -u2 -n -- $'\r\e[K'
  fi
  if (( code )); then
    print -u2 -r -- "$step_red✗$step_reset $label (exit $code)"
    [[ -n $output ]] && print -u2 -rl -- "${(@)${(@f)output}/#/  }"
    return $code
  fi
  print -u2 -r -- "$step_green✓$step_reset $label"
}
