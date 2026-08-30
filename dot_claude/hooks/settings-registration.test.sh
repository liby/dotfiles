#!/usr/bin/env bash
# Registration test for the Claude hooks subtree in
# .chezmoitemplates/claude-settings.json.
# The script tests in this directory prove hook behavior; this test proves the
# managed settings still register each hook with the intended matcher and
# deployed command. The modify template replaces the whole top-level
# "hooks" key with the template value, so the template subtree is the deployed
# end state. Template directives only appear outside the hooks subtree, so the
# test blanks {{...}} spans and parses the rest as JSON.
# Run: bash settings-registration.test.sh
# CLAUDE_SETTINGS_TEMPLATE overrides the template path for fixture tests.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="${CLAUDE_SETTINGS_TEMPLATE:-$HERE/../../.chezmoitemplates/claude-settings.json}"

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

HOOKS_JSON=$(perl -ne 'next if /^\s*\{\{.*\}\}\s*$/; s/\{\{.*?\}\}/BLANKED/g; print' "$TEMPLATE" | jq '.hooks' 2>/dev/null)
if [ -z "$HOOKS_JSON" ] || [ "$HOOKS_JSON" = "null" ]; then
  echo "FAIL: template did not parse to JSON with a hooks key" >&2
  exit 1
fi

expect_registration() {
  local event="$1" matcher="$2" command="$3" ok
  ok=$(jq --arg e "$event" --arg m "$matcher" --arg c "$command" '
    [.[$e][]? | select((.matcher // "") == $m) | .hooks[]?
     | select(.command == $c and .type == "command")]
    | length == 1' <<<"$HOOKS_JSON")
  check "$event matcher=${matcher:-<none>} registers $command as type=command" "$ok"
}

section() {
  printf '\n== %s ==\n' "$1"
}

section "registered end state"
expect_registration PreToolUse "Bash" "~/.claude/hooks/pre-bash-policy.sh"
expect_registration PreToolUse "Bash" "~/.claude/hooks/pre-bash-guard-secrets.sh"
expect_registration PreToolUse "Edit|Write" "~/.claude/hooks/pre-edit-warn-chezmoi.sh"
expect_registration PostToolUse "Bash" "~/.claude/hooks/post-bash-scan-secrets.sh"
expect_registration PreCompact "" "~/.claude/hooks/pre-compact-instructions.sh"

section "registered command -> source script"
while IFS= read -r cmd; do
  base="${cmd##*/}"
  # Only an executable_ source deploys as an executable hook; a plain source
  # deploys 0644 and a *.test.* name is chezmoi-ignored, so both would register
  # a command that cannot run.
  src="$HERE/executable_$base"
  check "executable source exists for $cmd" "$([ -r "$src" ] && echo true || echo false)"
  case "$cmd" in
    "~/.claude/hooks/"*) : ;;
    *) check "command path $cmd is under ~/.claude/hooks/" false ;;
  esac
done < <(jq -r '.[][]?.hooks[]?.command' <<<"$HOOKS_JSON")

section "source script -> registration"
for src in "$HERE"/executable_pre-*.sh "$HERE"/executable_post-*.sh; do
  [ -e "$src" ] || continue
  base="$(basename "$src")"
  base="${base#executable_}"
  ok=$(jq --arg c "~/.claude/hooks/$base" \
    '[.[][]?.hooks[]? | select(.command == $c)] | length == 1' <<<"$HOOKS_JSON")
  check "$base is registered" "$ok"
done

printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
