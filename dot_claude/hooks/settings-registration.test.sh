#!/usr/bin/env bash
# Registration test for the Claude hooks subtree in
# .chezmoitemplates/claude/settings.json.
# The script tests in this directory prove hook behavior; this test proves the
# managed settings still run each hook on the events and tools it handles. The modify
# template replaces the whole top-level "hooks" key with the template value, so
# the template subtree is the deployed end state. The test blanks {{...}} spans
# and parses the rest as JSON.
# Run: bash settings-registration.test.sh
# CLAUDE_SETTINGS_TEMPLATE overrides the template path for fixture tests.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="${CLAUDE_SETTINGS_TEMPLATE:-$HERE/../../.chezmoitemplates/claude/settings.json}"

if [ ! -r "$TEMPLATE" ]; then
  echo "cannot find settings template at $TEMPLATE" >&2
  exit 1
fi

PASS=0
FAIL=0

check() {
  local desc="$1" ok="$2"
  if [ "$ok" = true ]; then
    printf '  ok   %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf '  FAIL %s\n' "$desc"
    FAIL=$((FAIL + 1))
  fi
}

HOOKS_JSON=$(perl -ne 'next if /^\s*\{\{.*\}\}\s*$/; s/\{\{.*?\}\}/null/g; print' "$TEMPLATE" | jq '.hooks' 2>/dev/null)
if [ -z "$HOOKS_JSON" ] || [ "$HOOKS_JSON" = "null" ]; then
  echo "FAIL: template did not parse to JSON with a hooks key" >&2
  exit 1
fi

# expect_runs <event> <tool|""> <command>: an entry under <event> whose matcher
# selects <tool> runs <command>. Claude Code reads a matcher as a tool-name
# pattern and an empty or "*" matcher as every tool, so this checks coverage
# rather than how the matcher is spelled.
expect_runs() {
  local event="$1" tool="$2" command="$3" ok
  ok=$(jq --arg e "$event" --arg t "$tool" --arg c "$command" '
    [.[$e][]? | (.matcher // "") as $m
     | select($t == "" or $m == "" or $m == "*" or ($t | test("^(" + $m + ")$")))
     | .hooks[]? | select(.command == $c and .type == "command")]
    | length >= 1' <<<"$HOOKS_JSON")
  check "$event${tool:+ $tool} runs $command" "$ok"
}

section() {
  printf '\n== %s ==\n' "$1"
}

AGENT_GUARD="/opt/homebrew/bin/agent-guard --runtime claude"
# `rex skill setup` recognizes only its own command; see CONCEPTS.md#rex-integration.
REX_HOOK="/bin/sh -c 'rex __internal session-start --agent claude 2>/dev/null || true'"

section "required coverage"
# The guard covers Bash and the file tools; see CONCEPTS.md#agent-guard.
for tool in Bash Read Edit Write Grep; do expect_runs PreToolUse "$tool" "$AGENT_GUARD"; done
for tool in Edit Write; do expect_runs PreToolUse "$tool" "~/.claude/hooks/pre-edit-warn-chezmoi.sh"; done
# A failed command's output reaches the model too, so the scan runs on both events.
expect_runs PostToolUse Bash "~/.claude/hooks/post-bash-scan-secrets.sh"
expect_runs PostToolUseFailure Bash "~/.claude/hooks/post-bash-scan-secrets.sh"
expect_runs PreCompact "" "~/.claude/hooks/pre-compact-instructions.sh"
expect_runs SessionStart "" "$REX_HOOK"
expect_runs SessionStart compact "~/.claude/hooks/post-compact-reminder.sh"
check "event/matcher/command tuples are unique" "$(jq '
  [to_entries[] | .key as $event | .value[] | (.matcher // "") as $matcher
   | .hooks[] | [$event, $matcher, .command]]
  | length == (unique | length)' <<<"$HOOKS_JSON")"

check "each agent guard has a finite deadline and blocks when its hook fails" "$(jq --arg c "$AGENT_GUARD" '
  [.PreToolUse[].hooks[] | select(.command == $c)]
  | all(.timeout | type == "number" and . > 0) and all(.onFailure == "block")' <<<"$HOOKS_JSON")"

section "registered command -> source script"
# Homebrew owns the guard and Rex owns its hook; every other
# command deploys from this directory.
while IFS= read -r cmd; do
  [ "$cmd" = "$AGENT_GUARD" ] || [ "$cmd" = "$REX_HOOK" ] && continue
  base="${cmd#"~/.claude/hooks/"}"
  # Only an executable_ source deploys as an executable hook; a plain source
  # deploys 0644 and a *.test.* name is chezmoi-ignored, so both would register
  # a command that cannot run.
  src="$HERE/executable_$base"
  check "executable source exists for $cmd" "$([ "$base" != "$cmd" ] && { [ -r "$src" ] || [ -r "$src.tmpl" ]; } && echo true || echo false)"
done < <(jq -r '.[][]?.hooks[]?.command' <<<"$HOOKS_JSON")

section "source script -> registration"
for src in "$HERE"/executable_*; do
  [ -e "$src" ] || continue
  base="$(basename "$src")"
  base="${base#executable_}"
  base="${base%.tmpl}"
  ok=$(jq --arg c "~/.claude/hooks/$base" \
    '[.[][]?.hooks[]? | select(.command == $c)] | length >= 1' <<<"$HOOKS_JSON")
  check "$base is registered" "$ok"
done

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
