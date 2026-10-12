#!/usr/bin/env bash
set -euo pipefail

SOURCE="$(cd "$(dirname "$0")" && pwd)/executable_statusline.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# Exercise the real refresh function without loading the credential reader or
# statusline startup. Only the token provider and HTTP client are fixtures.
awk '/^(acquire_lock|refresh_usage_cache)\(\) \{/ { active = 1 } active { print } active && /^}/ { active = 0 }' \
  "$SOURCE" > "$fixture/refresh.sh"
source "$fixture/refresh.sh"

cache_dir="$fixture/cache"
mkdir "$cache_dir"
lock_dir="$cache_dir/lock"
usage_file="$cache_dir/usage.json"
retry_file="$cache_dir/retry"
error_file="$cache_dir/error.json"
processes_dir="$cache_dir/processes"
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
if grep -q 'SYNTHETIC_AUDIT_SENTINEL' "$fixture/argv"; then exit 1; fi
grep -qx '@-' "$fixture/argv"
[ "$(cat "$fixture/headers")" = 'Authorization: Bearer SYNTHETIC_AUDIT_SENTINEL' ]
jq -e '.five_hour.utilization == 12' "$usage_file" >/dev/null
[ ! -e "$lock_dir" ]
printf 'statusline credential transport: passed\n'

# Rate-limit sharing runs the whole script. A fresh usage.json keeps the fetch
# off, and the stubs make any attempt fail and leave a mark instead of
# reaching the real Keychain or endpoint. /usr/bin comes next so the merge runs
# on macOS's own jq 1.7, the oldest one the script meets when Claude Code
# starts without Homebrew on PATH. The date stub moves a tick's clock to $at,
# and the ps stub starts its Claude Code process $age seconds (default 5) earlier.
home="$fixture/home"
cache="$home/.cache/claude-statusline"
stubs="$fixture/stubs"
mkdir -p "$cache" "$stubs"
printf '#!/bin/sh\ntouch "%s/fetched"\nexit 7\n' "$fixture" > "$stubs/curl"
printf '#!/bin/sh\nexit 44\n' > "$stubs/security"
cat > "$stubs/date" <<'EOF'
#!/bin/sh
[ -n "$TEST_NOW" ] && [ "$1" = '+%s %m' ] && exec /bin/date -r "$TEST_NOW" '+%s %m'
exec /bin/date "$@"
EOF
cat > "$stubs/ps" <<'EOF'
#!/bin/sh
exec /bin/date -j -r $(( ${TEST_NOW:-$(/bin/date +%s)} - ${TEST_PROCESS_AGE:-5} )) '+%a %b %e %T %Y'
EOF
chmod +x "$stubs/curl" "$stubs/security" "$stubs/date" "$stubs/ps"

now=$(date +%s)
reset=$(( now + 3 * 3600 ))
reset_iso=$(date -u -r "$reset" +%Y-%m-%dT%H:%M:%S)
ended=$(( now - 90 ))
ended_iso=$(date -u -r "$ended" +%Y-%m-%dT%H:%M:%S)
week=$(( now + 4 * 86400 ))

snapshot() { # five_utilization five_resets_at_iso [age in seconds, default 1h]
  printf '{"five_hour":{"utilization":%s,"resets_at":"%s+00:00"},"seven_day":null,"extra_usage":{"is_enabled":false}}' \
    "$1" "$2" > "$cache/usage.json"
  touch -t "$(date -r $(( now - ${3:-3600} )) +%Y%m%d%H%M.%S)" "$cache/usage.json"
}
# The script keys its record on its parent, the Claude Code process: ticks
# run straight from this shell share one process, and each ( tick ) is a new one
tick() { # rate_limits JSON or empty, [session id]; writes the 5h and 7d rows that rows prints
  local limits=${1:-null}
  printf '{"cwd":"%s","session_id":"%s","version":"test","rate_limits":%s}' "$fixture" "${2:-s}" "$limits" |
    env -u CLAUDE_CODE_OAUTH_TOKEN HOME="$home" XDG_CACHE_HOME="$home/.cache" TEST_NOW="${at:-}" TEST_PROCESS_AGE="${age:-}" \
      PATH="$stubs:/usr/bin:$PATH" COLUMNS=120 /bin/bash "$SOURCE" |
    sed $'s/\033\\[[0-9;]*m//g' | grep -E '^(5h|7d) ' > "$fixture/rows" || true
}
rows() { cat "$fixture/rows"; }
five() { printf '{"five_hour":{"used_percentage":%s,"resets_at":%s}}' "$1" "$2"; }
seven() { printf '{"seven_day":{"used_percentage":%s,"resets_at":%s}}' "$1" "$week"; }
shared_five() { jq -r '.five_hour.used_percentage' "$cache/rate-limits.json"; }
expect() { # description actual pattern
  if ! grep -Eq -- "$3" <<< "$2"; then
    printf 'FAIL %s\n  got: %s\n  want: /%s/\n' "$1" "$2" "$3" >&2
    exit 1
  fi
}
reset_state() { rm -rf "$cache" && mkdir -p "$cache"; }

# Idle replay: a process repeating what it already showed must not win or
# rewrite, even under the new session id /clear gives it
reset_state; snapshot 0.0 "$reset_iso"
at=$(( now - 120 )) tick "$(five 2.1 "$reset")"
( at=$(( now - 60 )) tick "$(five 5 "$reset")" )
touch -t 202001010000 "$cache/rate-limits.json"
before=$(stat -f %m "$cache/rate-limits.json")
tick "$(five 2.1 "$reset")" cleared
expect 'idle replay keeps the later value' "$(rows)" '^5h .* 5% ⟳'
[ "$(stat -f %m "$cache/rate-limits.json")" = "$before" ]

# Claude Code drops an ended window from stdin; the windows left are still
# replays, and with no open window known the ended one reads empty
reset_state; snapshot 0.0 "$ended_iso"
at=$(( now - 120 )) tick "{\"five_hour\":{\"used_percentage\":2,\"resets_at\":$ended},\"seven_day\":{\"used_percentage\":40,\"resets_at\":$week}}"
( at=$(( now - 60 )) tick "$(seven 45)" )
tick "$(seven 40)"
expect 'a dropped window does not refresh the others' "$(rows)" '^7d .*45% ⟳'
expect 'an ended window reads 0% with no reset time' "$(rows)" '^5h .* 0% ⟳ +-- '

# The tick before a process's first message leaves a record, so its first
# values count from when they arrive, not from the process start
reset_state; snapshot 0.0 "$reset_iso" 60
at=$(( now - 300 )) tick
age=600 tick "$(five 20 "$reset")"
expect 'first values after an empty tick are new' "$(rows)" '^5h .* 20% ⟳'

# Two processes changed in the same second: neither one's replay undoes the other
reset_state; snapshot 0.0 "$reset_iso"
at=$(( now - 120 )) tick
at=$(( now - 60 )) tick "$(five 100 "$reset")"
( at=$(( now - 120 )) tick; at=$(( now - 60 )) tick "$(five 0 "$reset")" )
tick "$(five 100 "$reset")"
expect 'a same-second replay keeps the shared change' "$(rows)" '^5h .* 0% ⟳'
[ "$(shared_five)" = 0 ]

# A process first seen, such as one running before records existed, may replay
# values from any time since it started
reset_state; snapshot 0.0 "$reset_iso"
printf '{"seven_day":{"used_percentage":0,"resets_at":%s,"observed_at":%s}}\n' "$week" $(( now - 60 )) > "$cache/rate-limits.json"
age=86400 tick "$(seven 100)"
expect 'a long-running process cannot replay over a newer value' "$(rows)" '^7d .* 0% ⟳'

# Incident: a limit reset zeroed usage but kept the window's resets_at
reset_state; snapshot 100.0 "$reset_iso"
at=$(( now - 60 )) tick "$(five 100 "$reset")"
tick "$(five 1 "$reset")"
expect 'reset lowers usage within the window' "$(rows)" '^5h .* 1% ⟳'
[ "$(shared_five)" = 1 ]
( tick )
expect 'another session follows the reset' "$(rows)" '^5h .* 1% ⟳ .*≈'

# After a reset the endpoint can report no open window at all
reset_state
printf '{"five_hour":{"used_percentage":40,"resets_at":%s,"observed_at":%s}}\n' "$reset" $(( now - 120 )) > "$cache/rate-limits.json"
printf '{"five_hour":{"utilization":0.0,"resets_at":null},"seven_day":null,"extra_usage":{"is_enabled":false}}' > "$cache/usage.json"
touch -t "$(date -r $(( now - 60 )) +%Y%m%d%H%M.%S)" "$cache/usage.json"
( tick )
expect 'a later snapshot without a window clears the old one' "$(rows)" '^5h .* 0% ⟳ +-- ≈'

# Incident: a new session showed a 7h-old snapshot, refetch backing off after a
# 401, with the same marker as a neighbour's fresh value
reset_state
printf '{"five_hour":{"utilization":0.0,"resets_at":null},"seven_day":null,"extra_usage":{"is_enabled":false}}' > "$cache/usage.json"
touch -t "$(date -r $(( now - 7 * 3600 )) +%Y%m%d%H%M.%S)" "$cache/usage.json"
printf '401' > "$cache/usage.retry"
printf '{"seven_day":{"used_percentage":30,"resets_at":%s,"observed_at":%s}}\n' "$week" $(( now - 9000 )) > "$cache/rate-limits.json"
( tick )
expect 'a value past the 3h refetch interval is marked stale' "$(rows)" '^5h .* 0% ⟳ +-- +≋$'
expect 'a younger one keeps the shared marker' "$(rows)" '^7d .*30% ⟳ .*≈$'

# A snapshot fetched after the process's last change wins
reset_state; snapshot 0.0 "$reset_iso"
at=$(( now - 120 )) tick "$(five 3 "$reset")"
snapshot 10.0 "$reset_iso" 60
tick "$(five 3 "$reset")"
expect 'later snapshot beats an older live value' "$(rows)" '^5h .* 10% ⟳ +[0-9-]+ [0-9:]+ *$'
[ "$(shared_five)" = 10 ]

# An ended window loses to an open one however recently it was observed
reset_state; snapshot 0.0 "$ended_iso"
printf '{"five_hour":{"used_percentage":97,"resets_at":%s,"observed_at":%s}}\n' "$ended" "$now" > "$cache/rate-limits.json"
at=$(( now - 30 )) tick "$(five 1 "$reset")"
expect 'rollover takes the new window' "$(rows)" '^5h .* 1% ⟳ +[0-9-]+ [0-9:]+ *$'
[ "$(shared_five)" = 1 ]

# Windows merge independently, and ≈ marks only the one stdin lacks
reset_state; snapshot 0.0 "$reset_iso"
printf '{"five_hour":{"used_percentage":4,"resets_at":%s,"observed_at":%s}}\n' "$reset" $(( now - 60 )) > "$cache/rate-limits.json"
tick "$(seven 30)"
expect 'shared 5h row is marked' "$(rows)" '^5h .* 4% ⟳ .*≈'
expect 'live 7d row is unmarked' "$(rows)" '^7d .*30% ⟳ +[0-9-]+ [0-9:]+ *$'
[ "$(jq -r '.seven_day.used_percentage' "$cache/rate-limits.json")" = 30 ]

# Rendering never waits on a busy lock and never overwrites without it
reset_state; snapshot 0.0 "$reset_iso"
printf '{"five_hour":{"used_percentage":3,"resets_at":%s,"observed_at":%s}}\n' "$reset" $(( now - 60 )) > "$cache/rate-limits.json"
mkdir "$cache/refresh.lock"
tick "$(five 4 "$reset")"
expect 'busy lock still renders the merge' "$(rows)" '^5h .* 4% ⟳'
[ "$(shared_five)" = 3 ]
rmdir "$cache/refresh.lock"
tick "$(five 4 "$reset")"
[ "$(shared_five)" = 4 ]

# Another session publishes between this tick's read and its lock: each window
# keeps its later observation
reset_state; snapshot 0.0 "$reset_iso"
printf '{"five_hour":{"used_percentage":3,"resets_at":%s,"observed_at":%s}}\n' "$reset" $(( now - 60 )) > "$cache/rate-limits.json"
cat > "$stubs/mkdir" <<EOF
#!/bin/sh
printf '{"five_hour":{"used_percentage":7,"resets_at":%s,"observed_at":%s},"seven_day":{"used_percentage":30,"resets_at":%s,"observed_at":%s}}\n' "$reset" "$now" "$week" $(( now - 60 )) > "$cache/rate-limits.json"
exec /bin/mkdir "\$@"
EOF
chmod +x "$stubs/mkdir"
at=$(( now - 30 )) tick "{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$reset},\"seven_day\":{\"used_percentage\":50,\"resets_at\":$week}}"
rm "$stubs/mkdir"
[ "$(jq -c '[.five_hour.used_percentage, .seven_day.used_percentage]' "$cache/rate-limits.json")" = '[7,50]' ]

[ ! -e "$fixture/fetched" ]
printf 'statusline rate-limit sharing: passed\n'

# Line 1 for a Bedrock model id holding 153000 context tokens; Context % is
# their share of CC's auto-compact threshold
line1() { # window settings_json [env...]; prints line 1
  local window=$1 settings=$2; shift 2
  printf '%s' "$settings" > "$home/.claude/settings.json"
  printf '{"cwd":"%s","model":{"id":"us.anthropic.claude-opus-5-5-20260101-v1:0","display_name":"M"},"context_window":{"context_window_size":%s,"current_usage":{"input_tokens":1000,"output_tokens":2000,"cache_creation_input_tokens":30000,"cache_read_input_tokens":120000}}}' \
    "$fixture" "$window" |
    env -u CLAUDE_CODE_OAUTH_TOKEN -u DISABLE_COMPACT -u DISABLE_AUTO_COMPACT \
      -u CLAUDE_CODE_AUTO_COMPACT_WINDOW -u CLAUDE_CODE_MAX_OUTPUT_TOKENS \
      HOME="$home" XDG_CACHE_HOME="$home/.cache" PATH="$stubs:/usr/bin:$PATH" "$@" /bin/bash "$SOURCE" |
    sed $'s/\033\\[[0-9;]*m//g' | head -1
}
mkdir -p "$home/.claude"
top_400k='{"autoCompactWindow":400000}'
opus_200k='{"autoCompactWindow":400000,"modelSettings":{"claude-opus-5-5":{"autoCompactWindow":200000}}}'
alias_200k='{"autoCompactWindow":400000,"modelSettings":{"claude-opus-5-5@20260101":{"autoCompactWindow":200000}}}'
alias_then_canonical='{"modelSettings":{"claude-opus-5-5-20260101":{"autoCompactWindow":400000},"claude-opus-5-5":{"autoCompactWindow":200000}}}'
opus_auto='{"autoCompactWindow":400000,"modelSettings":{"claude-opus-5-5":{"autoCompactWindow":"auto"}}}'
no_usable_entry='{"modelSettings":{"claude-sonnet-5-5":{"autoCompactWindow":200000},"claude-opus-5-5":{"autoCompactWindow":50000}},"autoCompactWindow":400000}'
top_150k='{"autoCompactWindow":150000}'
off_150k='{"autoCompactEnabled":false,"autoCompactWindow":150000}'
expect 'per-model window wins, a canonical key over its alias' "$(line1 1000000 "$alias_then_canonical")" '^Context 91% '
expect "an alias spelling of the model's id matches" "$(line1 1000000 "$alias_200k")" '^Context 91% '
expect 'per-model auto falls back to the model window' "$(line1 1000000 "$opus_auto")" '^Context 15% '
expect "another model's or an out-of-range entry falls back to the top level" "$(line1 1000000 "$no_usable_entry")" '^Context 41% '
expect 'env window, digit separators included, beats settings' "$(line1 1000000 "$top_400k" CLAUDE_CODE_AUTO_COMPACT_WINDOW=200_000)" '^Context 91% '
expect 'auto-compact off in settings uses the bare window' "$(line1 200000 "$off_150k")" '^Context 85% '
expect 'auto-compact off in env uses the bare window' "$(line1 200000 "$top_150k" 'DISABLE_AUTO_COMPACT= TRUE ')" '^Context 85% '
expect 'small output budget shrinks the reserve' "$(line1 1000000 "$opus_200k" CLAUDE_CODE_MAX_OUTPUT_TOKENS=1000)" '^Context 82% '
expect 'no effort segment without effort.level' "$(line1 1000000 '{}')" '∙ M$'

# settings.json can carry credentials in its env block; they stay out of argv
cat > "$stubs/jq" <<EOF
#!/bin/sh
printf '%s\n' "\$@" >> "$fixture/jq-argv"
exec /usr/bin/jq "\$@"
EOF
chmod +x "$stubs/jq"
line1 1000000 '{"env":{"ANTHROPIC_API_KEY":"SYNTHETIC_AUDIT_SENTINEL"}}' > /dev/null
rm "$stubs/jq"
[ -s "$fixture/jq-argv" ]
if grep -q 'SYNTHETIC_AUDIT_SENTINEL' "$fixture/jq-argv"; then exit 1; fi

# The dirty marker follows content, and computing it never writes the index
git init -q "$fixture"
printf 'a\n' > "$fixture/tracked"
git -C "$fixture" add tracked
git -C "$fixture" -c user.name=t -c user.email=t@t -c commit.gpgSign=false commit -qm init
touch -t 202001010000 "$fixture/tracked"
cp "$fixture/.git/index" "$fixture/index.before"
expect 'mtime-only change is clean' "$(line1 1000000 '{}')" ':[^ ]*[^*] ∙ M$'
cmp -s "$fixture/index.before" "$fixture/.git/index"
printf 'b\n' > "$fixture/tracked"
expect 'content change is dirty' "$(line1 1000000 '{}')" '\* ∙ M$'
printf 'statusline line 1: passed\n'
