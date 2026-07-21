#!/usr/bin/env bash
# PreToolUse hook for Bash.
# Blocks commands that have better alternatives (find → fd, dev/start/serve)
# and rg invocations carrying grep-style flags that rg reinterprets.

source "$(dirname "$0")/_lib.sh"

require_jq
CMD=$(parse_command) || exit 0

# Block find → suggest fd
if echo "$CMD" | grep -qE '(^|\||;|&&|\|\||\$\()\s*find\s'; then
  block "Use fd instead of find. fd has simpler syntax and respects .gitignore by default."
fi

# Block rg invocations whose unquoted tokens carry grep-style flags rg
# reinterprets: a single-dash letter cluster containing r invokes --replace
# (grep muscle memory: -rn, -nr, -rln), and --include is grep-only. Also block
# BRE-style alternation in any rg argument: rg reads \| as an escaped literal
# pipe, so a\|b silently matches nothing while exiting cleanly. utok strips
# quotes and escapes for flag matching; rtok reconstructs what rg receives
# after shell quoting: unquoted \| passes a plain | to rg and stays legal, and
# inside double quotes backslashes fold per bash (\\ \" \$ \` collapse, the
# rest keep the backslash), so "a\\|b" is still caught. The \| verdict is
# per-invocation: emitted at the next separator or end of input, and dropped
# when the invocation carries -F/--fixed-strings (pattern is literal there,
# and the deny message recommends -F). Fail-open by design: the whole command
# is one record so quote state spans newlines, detection arms only at a
# command-position rg (wrapper/prefix forms like xargs rg pass), and -- ends
# flag checks while the \| check stays armed for the pattern operand. Quoted
# mentions (commit messages), other commands' flags (sort -rn), \\| escaped-
# backslash patterns, and heredoc bodies (stripped by parse_command) pass.
# Known fail-closed edge, accepted as rare: quoted \| inside a trailing
# comment or herestring of an rg command still blocks.
RG_MISUSE=$(printf '%s' "$CMD" | awk '
  BEGIN { RS = "\x01"; cmdpos = 1 }
  function finish() {
    if (utok == "" && rtok == "") return
    if (inrg && rtok ~ /(^|[^\\])\\\|/) brehit = 1
    if (inrg && !optdone && (utok == "--fixed-strings" || (utok ~ /^-[A-Za-z]+$/ && utok ~ /F/))) fixed = 1
    if (skipnext) skipnext = 0
    else if (cmdpos && utok == "rg") inrg = 1
    else if (inrg && utok == "--") optdone = 1
    else if (inrg && !optdone && utok == "-e") skipnext = 1
    else if (inrg && !optdone && utok ~ /^-[A-Za-z]+$/ && utok ~ /r/) print "replace"
    else if (inrg && !optdone && utok ~ /^--include(=|$)/) print "include"
    cmdpos = 0; utok = ""; rtok = ""
  }
  function endinv() { if (brehit && !fixed) print "bre"; brehit = 0; fixed = 0 }
  function sep() { finish(); endinv(); inrg = 0; skipnext = 0; optdone = 0; cmdpos = 1 }
  {
    n = length($0)
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1); nc = (i < n) ? substr($0, i + 1, 1) : ""
      if (c == "\\" && !sq) {
        if (nc == "\n") { i++; continue }
        if (dq) { if (nc == "\\" || nc == "\"" || nc == "$" || nc == "`") rtok = rtok nc; else rtok = rtok c nc }
        else { utok = utok nc; rtok = rtok nc }
        i++; continue
      }
      if (c == "\047" && !dq) { sq = !sq; continue }
      if (c == "\"" && !sq) { dq = !dq; continue }
      if (sq || dq) { rtok = rtok c; continue }
      if (c == " " || c == "\t") { finish(); continue }
      if (c == "\n" || c == "|" || c == ";" || c == "&" || c == "(" || c == ")") { sep(); continue }
      utok = utok c; rtok = rtok c
    }
    finish(); endinv()
  }')
if [[ $RG_MISUSE == *replace* ]]; then
  block "rg is not grep: a clustered -r flag invokes --replace, which silently rewrites every match in the output while exiting 0. rg recurses with line numbers by default, so drop the flag entirely; for intentional replacement write --replace VALUE."
fi
if [[ $RG_MISUSE == *include* ]]; then
  block "rg has no --include flag. Filter files with -g GLOB (e.g. -g '*.ts') or a type filter like -t ts."
fi
if [[ $RG_MISUSE == *bre* ]]; then
  block "rg regex is not grep BRE: \\| is an escaped literal pipe, so a\\|b matches the literal text a|b and silently finds nothing. Write alternation as a|b; to match a literal pipe intentionally, use [|] or -F."
fi

# Block dev/start/serve commands (long-running servers; agent-run copies orphan and collide with the user's own)
if echo "$CMD" | grep -qE '(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|start|serve)\b'; then
  block "Do not run dev/start/serve commands, even when explicitly asked; do not retry. If a running app is needed, ask the user to run it in their own terminal (e.g. ! npm run dev). Otherwise verify through code review, type checking, and linting."
fi

exit 0
