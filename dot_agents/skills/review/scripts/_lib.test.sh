#!/usr/bin/env bash
# Behavior tests for validate_path_file_nul in _lib.sh. Helper scripts source it
# from bash and agents source it from their zsh Bash tool, and zsh fails at
# runtime where bash does not (read-only $status, tied $path, missing shopt), so
# every case runs in both shells.
# Run: bash _lib.test.sh

set -u
LIB="$(cd "$(dirname "$0")" && pwd)/_lib.sh"

# path, expected exit (0 allow, 4 raw secret, 5 ambiguous), ciphertext notice.
# Several cases pin branch order: case patterns let * cross "/", so a refusal
# must win over a later allow or ambiguous branch that also matches.
CASES=(
  "src/app.ts 0 -"
  "certificate.crt 0 -"
  ".env.age 0 notice"
  "encrypted_private_dot_env.asc 0 notice"
  ".secrets/seed.asc 0 notice"
  ".secrets/plain.toml 4 -"
  ".secrets/deploy.pub 4 -"
  ".secrets/.env.production 4 -"
  ".secrets/.env.local.example 4 -"
  "apps/web/.env 4 -"
  ".ENV.local 4 -"
  "deploy/.env.d/.env.local 4 -"
  "certs/server.key 4 -"
  ".env/certs/server.key 4 -"
  ".env/id_ed25519 4 -"
  ".zsh_history 4 -"
  ".local/share/fish/fish_history 4 -"
  ".env/.bash_history 4 -"
  ".ssh/.bash_history 4 -"
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
commit() { git -C "$repo" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -qm "$1"; }
git -C "$repo" init -q && echo a >"$repo/app.ts" && git -C "$repo" add app.ts && commit base &&
  echo b >"$repo/.env" && git -C "$repo" add .env && commit secret && echo c >"$repo/.envrc"
for shell in bash zsh; do
  expect_status "later entry in a mixed list" 4 "$shell" 'source "$1" && printf "%s\0" src/app.ts .envrc .env | validate_path_file_nul /dev/stdin'
  expect_status "untracked working-tree path" 5 "$shell" 'source "$1" && cd "$2" && validate_working_tree_paths'
  expect_status "ref range" 4 "$shell" 'source "$1" && cd "$2" && validate_git_diff_paths HEAD~1 HEAD'
done
rm -rf "$repo"

printf '%d cases x 2 shells, %d failed\n' "${#CASES[@]}" "$FAIL"
[[ $FAIL -eq 0 ]]
