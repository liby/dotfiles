#!/usr/bin/env bash
set -euo pipefail

SOURCE="$(cd "$(dirname "$0")" && pwd)/executable_statusline.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# Exercise the real refresh function without loading the credential reader or
# statusline startup. Only the token provider and HTTP client are fixtures.
awk '/^refresh_usage_cache\(\) \{/ { active = 1 } active { print } active && /^}/ { exit }' \
  "$SOURCE" > "$fixture/refresh.sh"
source "$fixture/refresh.sh"

cache_dir="$fixture/cache"
mkdir "$cache_dir"
lock_dir="$cache_dir/lock"
usage_file="$cache_dir/usage.json"
retry_file="$cache_dir/retry"
error_file="$cache_dir/error.json"
claude_version=fixture

get_oauth_token() { printf 'SYNTHETIC_AUDIT_SENTINEL'; }
read_usage_state() { needs_refresh=true; }
curl() {
  local output=''
  printf '%s\n' "$@" > "$fixture/argv"
  while (( $# )); do
    case "$1" in
      -o) output=$2; shift ;;
    esac
    shift
  done
  cat > "$fixture/headers"
  printf '{"five_hour":{"utilization":12}}' > "$output"
  printf '200'
}

refresh_usage_cache
! grep -q 'SYNTHETIC_AUDIT_SENTINEL' "$fixture/argv"
grep -qx '@-' "$fixture/argv"
[ "$(cat "$fixture/headers")" = 'Authorization: Bearer SYNTHETIC_AUDIT_SENTINEL' ]
jq -e '.five_hour.utilization == 12' "$usage_file" >/dev/null
[ ! -e "$lock_dir" ]
printf 'statusline credential transport: passed\n'
