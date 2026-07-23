#!/usr/bin/env bash
# Shared utilities for Claude Code hooks.

# block — deny a PreToolUse action and exit.
# Usage: block "reason message"
# Callers must have invoked require_jq first; this writes the structured deny
# response on stdout per the PreToolUse hookSpecificOutput protocol.
block() {
  jq -n --arg reason "DENIED: $1 Do NOT bypass this restriction or retry the same blocked command." '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 2
}

# parse_command — read stdin, extract .tool_input.command verbatim.
# Returns 1 if command is empty. Usage: CMD=$(parse_command) || exit 0
# Deliberately NO heredoc stripping: consumers are deny hooks, where a
# heuristic parser that mistakes lookalike `<<TOKEN` text for an opener
# deletes executable lines from the inspected text — a fail-open deny
# bypass. Scanning heredoc bodies as if they were commands only false-
# blocks (fail-closed), which is the accepted trade.
parse_command() {
  local input cmd
  input=$(cat)
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty') || return 1
  [ -n "$cmd" ] || return 1
  printf '%s\n' "$cmd"
}

# require_jq — exit 0 (allow through) if jq is not available.
require_jq() {
  command -v jq &>/dev/null || exit 0
}

# split_segments — read a shell command from stdin and emit one top-level
# segment per line, splitting on unquoted `;`, `&&`, `||`. Respects single
# and double quotes plus backslash escapes. Parens are not tracked, so a
# separator inside `$( )` splits like any other.
split_segments() {
  awk '
  {
    sq = 0; dq = 0; out = ""; n = length($0);
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1);
      nc = (i < n) ? substr($0, i + 1, 1) : "";
      if (c == "\\" && !sq && nc != "") { out = out c nc; i++; continue; }
      if (c == "\047" && !dq) { sq = !sq; out = out c; continue; }
      if (c == "\"" && !sq) { dq = !dq; out = out c; continue; }
      if (!sq && !dq) {
        if (c == ";") { if (out != "") print out; out = ""; continue; }
        if (c == "&" && nc == "&") { if (out != "") print out; out = ""; i++; continue; }
        if (c == "|" && nc == "|") { if (out != "") print out; out = ""; i++; continue; }
      }
      out = out c;
    }
    if (length(out) > 0) print out;
  }'
}
