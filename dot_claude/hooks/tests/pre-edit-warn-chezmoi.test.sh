#!/usr/bin/env bash
# Isolated behavior tests for pre-edit-warn-chezmoi.sh.

set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-edit-warn-chezmoi.sh"
[[ -x "$HOOK" ]] || HOOK="$(cd "$(dirname "$0")/.." && pwd)/executable_pre-edit-warn-chezmoi.sh"

if [[ ! -r "$HOOK" ]]; then
  echo "cannot find hook script at $HOOK" >&2
  exit 1
fi

FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p \
  "$FIXTURE/bin" \
  "$FIXTURE/bin-no-chezmoi" \
  "$FIXTURE/bin-no-jq" \
  "$FIXTURE/home/project" \
  "$FIXTURE/source"

cat >"$FIXTURE/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == source-path ]] || exit 1
case "$2" in
  */home/managed.txt) printf '%s\n' "${FIXTURE_SOURCE}/dot_managed.txt" ;;
  */home/partial.json) printf '%s\n' "${FIXTURE_SOURCE}/modify_partial.json" ;;
  */home/project/relative.txt) printf '%s\n' "${FIXTURE_SOURCE}/dot_relative.txt" ;;
  */home/encrypted.txt) printf '%s\n' "${FIXTURE_SOURCE}/encrypted_dot_encrypted.txt.asc" ;;
  */home/encrypted-create.txt) printf '%s\n' "${FIXTURE_SOURCE}/create_encrypted_dot_encrypted-create.txt.asc" ;;
  */home/encrypted-partial.txt) printf '%s\n' "${FIXTURE_SOURCE}/modify_encrypted_dot_encrypted-partial.txt.asc" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FIXTURE/bin/chezmoi"
ln -s "$(command -v dirname)" "$FIXTURE/bin-no-jq/dirname"
ln -s "$(command -v dirname)" "$FIXTURE/bin-no-chezmoi/dirname"
ln -s "$(command -v jq)" "$FIXTURE/bin-no-chezmoi/jq"

PASS=0
FAIL=0

run_case() {
  local name=$1 expected=$2 path=$3 cwd=${4:-} output decision
  output=$(jq -nc --arg p "$path" --arg cwd "$cwd" \
    '{cwd: $cwd, tool_input: {file_path: $p}}' \
    | HOME="$FIXTURE/home" PATH="$FIXTURE/bin:$PATH" \
      FIXTURE_SOURCE="$FIXTURE/source" bash "$HOOK")
  if [[ -z "$output" ]]; then
    decision=allow
  else
    decision=$(jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"$output")
  fi
  if [[ "$decision" == "$expected" ]]; then
    printf 'ok   %-5s %s\n' "$decision" "$name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL want=%-5s got=%-5s %s\n' "$expected" "$decision" "$name"
    FAIL=$((FAIL + 1))
  fi
  REPLY=$output
}

run_case "managed absolute target" ask "$FIXTURE/home/managed.txt"
jq -e --arg source "$FIXTURE/source/dot_managed.txt" \
  '.hookSpecificOutput.permissionDecisionReason | contains($source)' <<<"$REPLY" >/dev/null || FAIL=$((FAIL + 1))

run_case "managed home-relative target" ask "~/managed.txt"
run_case "managed relative target" ask "relative.txt" "$FIXTURE/home/project"
run_case "partially managed target" ask "$FIXTURE/home/partial.json"
jq -e '.hookSpecificOutput.permissionDecisionReason | contains("partially managed")' \
  <<<"$REPLY" >/dev/null || FAIL=$((FAIL + 1))
run_case "source path" allow "$FIXTURE/source/dot_managed.txt"
run_case "unmanaged path" allow "$FIXTURE/home/unmanaged.txt"
run_case "encrypted target" ask "$FIXTURE/home/encrypted.txt"
jq -e '.hookSpecificOutput.permissionDecisionReason
  | contains("encrypted chezmoi source") and (contains("encrypted_dot_encrypted") | not)' \
  <<<"$REPLY" >/dev/null || FAIL=$((FAIL + 1))
run_case "encrypted create target" ask "$FIXTURE/home/encrypted-create.txt"
jq -e '.hookSpecificOutput.permissionDecisionReason
  | contains("encrypted chezmoi source") and (contains("create_encrypted_dot_encrypted-create") | not)' \
  <<<"$REPLY" >/dev/null || FAIL=$((FAIL + 1))
run_case "encrypted partial target" ask "$FIXTURE/home/encrypted-partial.txt"
jq -e '.hookSpecificOutput.permissionDecisionReason
  | contains("encrypted chezmoi source") and (contains("modify_encrypted_dot_encrypted-partial") | not)' \
  <<<"$REPLY" >/dev/null || FAIL=$((FAIL + 1))

output=$(jq -nc --arg p "$FIXTURE/home/managed.txt" \
  '{tool_input: {file_path: $p}}' \
  | PATH="$FIXTURE/bin-no-chezmoi" /bin/bash "$HOOK")
if [[ -z "$output" ]]; then
  printf 'ok   allow missing chezmoi\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL want=allow got=output missing chezmoi\n'
  FAIL=$((FAIL + 1))
fi

output=$(jq -nc --arg p "$FIXTURE/home/managed.txt" \
  '{tool_input: {file_path: $p}}' \
  | PATH="$FIXTURE/bin-no-jq" /bin/bash "$HOOK")
if [[ -z "$output" ]]; then
  printf 'ok   allow missing jq\n'
  PASS=$((PASS + 1))
else
  printf 'FAIL want=allow got=output missing jq\n'
  FAIL=$((FAIL + 1))
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
