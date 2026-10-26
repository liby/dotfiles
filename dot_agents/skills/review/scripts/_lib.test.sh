#!/usr/bin/env bash
# Behavior tests for validate_path_file_nul in _lib.sh. Helper scripts source it
# from bash and agents source it from their zsh Bash tool, and zsh fails at
# runtime where bash does not (read-only $status, tied $path, missing shopt), so
# every case runs in both shells.
# Run: bash _lib.test.sh

set -u
LIB="$(cd "$(dirname "$0")" && pwd)/_lib.sh"

# path, expected exit (0 proceed, 4 declared environment input, 5 ambiguous), ciphertext notice.
# Several cases pin branch order: case patterns let * cross "/", so a refusal
# must win over a later allow or ambiguous branch that also matches.
CASES=(
  "src/app.ts 0 -"
  "certificate.crt 0 -"
  ".env.age 0 notice"
  "encrypted_private_dot_env.asc 0 notice"
  ".secrets/seed.asc 0 notice"
  ".secrets/plain.toml 5 -"
  ".secrets/deploy.pub 5 -"
  ".secrets/.env.production 5 -"
  ".secrets/.env.local.example 5 -"
  ".secrets/.env 4 -"
  "apps/web/.env 4 -"
  ".ENV.local 4 -"
  "deploy/.env.d/.env.local 4 -"
  "certs/server.key 5 -"
  "slides/roadmap.key 5 -"
  ".env/certs/server.key 5 -"
  ".env/id_ed25519 5 -"
  ".zsh_history 5 -"
  ".local/share/fish/fish_history 5 -"
  ".env/.bash_history 5 -"
  ".ssh/.bash_history 5 -"
  ".env.d/cache/config.local 5 -"
  ".env/pyvenv.cfg 5 -"
  "apps/web/.env/production.example 5 -"
  "apps/web/.env.local.example 0 -"
  ".env.production.sample 0 -"
  ".env.template 0 -"
  ".env.local.bak 5 -"
  ".env.development.local 5 -"
  ".ENV.production 5 -"
  ".envrc 5 -"
  "identity.pem 5 -"
  ".ssh/config 0 -"
  ".ssh/id_ed25519.pub 0 -"
  ".ssh/agent.sock 5 -"
)

FAIL=0
for shell in bash zsh; do
  for case in "${CASES[@]}"; do
    read -r entry expected notice <<<"$case"
    err=$("$shell" -c 'source "$1" && printf "%s\0" "$2" | validate_path_file_nul /dev/stdin' "$shell" "$LIB" "$entry" 2>&1 >/dev/null)
    status=$?
    reported=-
    [[ $status == 0 && -n $err ]] && reported=notice
    if [[ $status != "$expected" || $reported != "$notice" ]]; then
      printf 'FAIL %s %s: exit %s notice %s, want exit %s notice %s\n' "$shell" "$entry" "$status" "$reported" "$expected" "$notice"
      FAIL=$((FAIL + 1))
    fi
  done
done

# The entry points the review skill calls must hand every changed path to the
# classifier: a later entry in the list, an untracked file, and a ref range.
expect_status() {
  local label="$1" want="$2" shell="$3" script="$4" got
  "$shell" -c "$script" "$shell" "$LIB" "$repo" 2>/dev/null
  got=$?
  if [[ $got != "$want" ]]; then
    printf 'FAIL %s %s: exit %s, want %s\n' "$shell" "$label" "$got" "$want"
    FAIL=$((FAIL + 1))
  fi
}
repo=$(mktemp -d)
ordinary=$(mktemp)
scope=$(mktemp)
trap 'rm -rf "$repo"; rm -f "$ordinary" "$scope"' EXIT
commit() { git -C "$repo" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -qm "$1"; }
git -C "$repo" init -q && echo a >"$repo/app.ts" && git -C "$repo" add app.ts && commit base &&
  echo b >"$repo/.env" && git -C "$repo" add .env && commit secret && echo c >"$repo/.envrc" || exit 1
# These are declared synthetic ordinary fixtures, not private keys or environment inputs.
mkdir "$repo/fixtures"
printf 'fixture-v1\n' >"$repo/fixtures/sample.key"
git -C "$repo" add fixtures/sample.key && commit fixture || exit 1
printf 'fixture-v2\n' >"$repo/fixtures/sample.key"
printf 'untracked-fixture\n' >"$repo/fixtures/untracked.key"
printf '%s\0' fixtures/sample.key fixtures/untracked.key .envrc >"$ordinary"
printf '%s\0' fixtures/sample.key >"$scope"
for shell in bash zsh; do
  expect_status "later entry in a mixed list" 4 "$shell" 'source "$1" && printf "%s\0" src/app.ts .envrc .env | validate_path_file_nul /dev/stdin'
  expect_status "untracked working-tree path" 5 "$shell" 'source "$1" && cd "$2" && validate_working_tree_paths'
  expect_status "declared-env ref range" 4 "$shell" 'source "$1" && cd "$2" && validate_git_diff_paths HEAD~2 HEAD~1'
  expect_status "unclassified fixture ref range" 5 "$shell" 'source "$1" && cd "$2" && validate_git_diff_paths HEAD~1 HEAD'
  expect_status "unterminated final protected path" 4 "$shell" 'source "$1" && printf "%s\0%s" src/app.ts .env | validate_path_file_nul /dev/stdin'

  "$shell" -c 'source "$1" && cd "$2" && validate_git_diff_paths HEAD~1 HEAD "$3" && validate_working_tree_paths "$3"' "$shell" "$LIB" "$repo" "$ordinary" 2>/dev/null
  if [[ $? != 0 ]]; then
    printf 'FAIL %s: classified ordinary paths did not reach both entry points\n' "$shell"
    FAIL=$((FAIL + 1))
  fi

  "$shell" -c 'source "$1" && cd "$2/fixtures" && validate_working_tree_paths "$3"' "$shell" "$LIB" "$repo" "$ordinary" 2>/dev/null
  if [[ $? != 0 ]]; then
    printf 'FAIL %s: subdirectory changed repo-relative classification\n' "$shell"
    FAIL=$((FAIL + 1))
  fi

  "$shell" -c 'source "$1" && printf "%s\0" fixtures/sample.key | validate_path_file_nul /dev/stdin <(printf "%s" fixtures/sample.key)' "$shell" "$LIB" 2>/dev/null
  if [[ $? != 0 ]]; then
    printf 'FAIL %s: final ordinary classification was skipped without trailing NUL\n' "$shell"
    FAIL=$((FAIL + 1))
  fi

  "$shell" -c 'source "$1" && printf "%s\0" "Fixtures/Sample.key" | validate_path_file_nul /dev/stdin "$2"' "$shell" "$LIB" "$ordinary" 2>/dev/null
  if [[ $? != 5 ]]; then
    printf 'FAIL %s: ordinary classification was not case-sensitive\n' "$shell"
    FAIL=$((FAIL + 1))
  fi

  err=$("$shell" -c 'source "$1" && printf "%s\0" "Certs/Server.KEY" | validate_path_file_nul /dev/stdin' "$shell" "$LIB" 2>&1 >/dev/null)
  if [[ "$err" != *Certs/Server.KEY* ]]; then
    printf 'FAIL %s: flagged path lost its original case\n' "$shell"
    FAIL=$((FAIL + 1))
  fi

  expect_status "missing path list" 2 "$shell" 'source "$1" && validate_path_file_nul "$2/missing-path-list"'
  expect_status "missing ordinary list" 2 "$shell" 'source "$1" && printf "%s\0" app.ts | validate_path_file_nul /dev/stdin "$2/missing-ordinary-list"'
done

printf '%s\0' .env encrypted_fixture.asc >"$ordinary"
for shell in bash zsh; do
  "$shell" -c 'source "$1" && printf "%s\0" .env | validate_path_file_nul /dev/stdin "$2"' "$shell" "$LIB" "$ordinary" 2>/dev/null
  if [[ $? != 4 ]]; then
    printf 'FAIL %s: ordinary list overrode a declared environment input\n' "$shell"
    FAIL=$((FAIL + 1))
  fi
  err=$("$shell" -c 'source "$1" && printf "%s\0" encrypted_fixture.asc | validate_path_file_nul /dev/stdin "$2"' "$shell" "$LIB" "$ordinary" 2>&1 >/dev/null)
  if [[ $? != 0 || -z "$err" ]]; then
    printf 'FAIL %s: ordinary list hid a ciphertext candidate\n' "$shell"
    FAIL=$((FAIL + 1))
  fi
done

printf '%s\0' fixtures/sample.key >"$ordinary"
baseline=$(cd "$repo" && bash "${LIB%/_lib.sh}/review-fix-baseline.sh" "$scope" "$ordinary" 2>/dev/null)
if [[ $? != 0 || -z "$baseline" ]] || [[ $(git -C "$repo" show "$baseline:fixtures/sample.key" 2>/dev/null) != fixture-v2 ]] || [[ $(cat "$repo/fixtures/sample.key") != fixture-v2 ]]; then
  printf 'FAIL: fix baseline did not preserve the classified fixture working tree\n'
  FAIL=$((FAIL + 1))
fi

printf '%s\0%s' fixtures/sample.key .env >"$scope"
(cd "$repo" && bash "${LIB%/_lib.sh}/review-fix-baseline.sh" "$scope" "$ordinary") >/dev/null 2>&1
if [[ $? != 4 ]]; then
  printf 'FAIL: fix baseline skipped a final protected path without trailing NUL\n'
  FAIL=$((FAIL + 1))
fi

printf '%d path cases x 2 shells plus entry-point, classification, and baseline checks; %d failed\n' "${#CASES[@]}" "$FAIL"
[[ $FAIL -eq 0 ]]
