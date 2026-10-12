#!/bin/bash
# Claude Code statusline — renders context usage, git info, rate limits.
# Reads JSON from stdin (statusLine hook), outputs ANSI-colored text.

set -f

input=$(</dev/stdin)

# ── Colors ──────────────────────────────────────────────
cyan='\033[38;2;86;182;194m'
sky='\033[38;2;200;210;235m'
amber='\033[38;2;224;168;112m'
red='\033[38;2;255;82;82m'
coral='\033[38;2;255;127;100m'
rose='\033[38;2;245;180;190m'
ruby='\033[38;2;230;100;160m'
claude='\033[38;2;215;119;87m' # CLI theme "claude" brand orange
dim='\033[2m'
muted='\033[38;2;120;130;150m'
faint='\033[38;2;60;65;75m'
# Cache-marker slate violet: the only hue unused by data colors, so it stays
# recognizable as "from snapshot" next to the shifting pct ramp and sky time
cache='\033[38;2;130;125;160m'
reset='\033[0m'

sep=" ${dim}∙${reset} " # U+2219 bullet operator: lower profile than │, distinct from the effort circle glyphs

# ── Epoch (single fork) ─────────────────────────────────
read -r _now _month < <(date "+%s %m")

# ── Terminal width (CC passes COLUMNS/LINES as env to statusline) ──
# Absent for non-tty -> fall back to 80. Scales the branch label and
# rate-bar width down on narrow terminals.
cols=${COLUMNS:-80}
if   (( cols < 60 ));  then branch_max=16; bar_width=6
elif (( cols < 100 )); then branch_max=28; bar_width=8
else                        branch_max=40; bar_width=10
fi

# ── Helpers ─────────────────────────────────────────────
file_mtime() {
  stat -f %m "$1" 2>/dev/null || echo 0
}

# Render helpers return via globals (_pct_color, _bar, _row, _dollars) instead
# of $( ) command substitution: each $( ) forks a subshell (~0.4 ms measured on
# this machine) and these run per row on every statusline tick.
color_for_pct() { # sets _pct_color
  if (( $1 >= 90 )); then _pct_color=$red
  elif (( $1 >= 70 )); then _pct_color=$coral
  elif (( $1 >= 50 )); then _pct_color=$cyan
  else _pct_color=$muted
  fi
}

build_bar() { # sets _bar, _pct_color
  local pct=$1 width=$2
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100

  local filled=$(( pct * width / 100 ))
  (( pct > 0 && filled == 0 )) && filled=1
  local empty=$(( width - filled ))
  color_for_pct "$pct"

  local fill_buf empty_buf
  printf -v fill_buf '%*s' "$filled" ''
  fill_buf="${fill_buf// /▰}"
  printf -v empty_buf '%*s' "$empty" ''
  empty_buf="${empty_buf// /▱}"

  _bar="${_pct_color}${fill_buf}${faint}${empty_buf}${reset}"
}

cents_to_dollars() { # sets _dollars
  local raw
  printf -v raw "%.0f" "$1"
  local whole=$(( raw / 100 )) rem=$(( raw % 100 ))
  if [ "$rem" -eq 0 ]; then _dollars=$whole
  else printf -v _dollars '%d.%02d' "$whole" "$rem"
  fi
}

render_rate_row() { # sets _row
  local label="$1" pct_raw="$2" reset_time="$3" suffix="$4"
  local pct pct_fmt
  printf -v pct "%.0f" "$pct_raw"
  build_bar "$pct" "$bar_width"
  printf -v pct_fmt "%3d" "$pct"
  _row="${muted}${label}${reset} ${_bar}${_pct_color}${pct_fmt}%${reset} ${dim}⟳${reset}  ${sky}${reset_time}${reset}${suffix}"
}

queue_extra_rate_row() {
  local extra_enabled extra_pct_raw extra_used_raw extra_limit_raw
  {
    read -r extra_enabled
    read -r extra_pct_raw
    read -r extra_used_raw
    read -r extra_limit_raw
  } < <(jq -r '
    (.extra_usage.is_enabled // false),
    (.extra_usage.utilization // 0),
    (.extra_usage.used_credits // 0),
    (.extra_usage.monthly_limit // 0)
  ' <<< "$usage_data" 2>/dev/null)

  [ "$extra_enabled" = "true" ] || return
  local extra_used extra_limit month extra_reset
  cents_to_dollars "$extra_used_raw";  extra_used=$_dollars
  cents_to_dollars "$extra_limit_raw"; extra_limit=$_dollars
  month=$(( 10#$_month % 12 + 1 ))
  printf -v extra_reset "%02d-01" "$month"
  queue_row "Ex" "$extra_pct_raw" "$extra_reset" " ${dim}\$${extra_used}/\$${extra_limit}${reset}"
}

# Read by file, not --arg: settings.json can hold credentials in its env block,
# and other processes can read a command's arguments
settings_path="$HOME/.claude/settings.json"
[ -r "$settings_path" ] || settings_path=/dev/null

# ── Extract JSON data (single jq call) ──────────────────
{
  read -r compact_at
  read -r input_tokens
  read -r output_tokens
  read -r cache_create
  read -r cache_read
  read -r cwd
  read -r live_limits
  read -r session_id
  read -r effort
  read -r model_name
  read -r claude_version
} < <(jq -r --rawfile settings "$settings_path" '
  # Context % is measured against the token count where CC auto-compacts, which
  # stdin does not carry. This mirrors CC 2.1.296 (E5/w5/aE) for the env and
  # user settings.json inputs below; with auto-compact off, CC measures against
  # the model window less the output reserve and ignores the settings window.
  # Not modeled: project and local settings, an autoCompactEnabled left in
  # ~/.claude.json by older CC versions, CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, model
  # ids CC resolves through its model catalog rather than by spelling (an
  # undated claude-opus-4, an inference-profile ARN), and the server and
  # model-catalog defaults for the window and output budget, so a model with no
  # autoCompactWindow configured may compact earlier than this shows.
  def env_on($name): $ENV[$name] // "" | ascii_downcase | sub("^\\s+|\\s+$"; ""; "g") | IN("1", "true", "yes", "on");
  # CC reads digit separators, as in 200_000, 200,000 or 200 000
  def env_tokens($name): $ENV[$name] // "" | gsub("[_, \u00a0\u202f]"; "") | tonumber? // null | if . and . > 0 then floor else null end;
  # CC drops a value outside its settings schema as if it were unset
  def window_setting: if . == "auto" or (type == "number" and . == floor and . >= 100000 and . <= 1000000) then . else null end;
  # CC matches modelSettings keys and the model id by canonical name, ignoring
  # their [1m], dated, Bedrock and Vertex spellings
  def model_key: ascii_downcase | sub("^([a-z]+\\.)?anthropic\\."; "")
    | sub("(-[0-9]{8})?(-v[0-9]+:[0-9]+)?(@[0-9]{8})?(\\[1m\\])?$"; "");
  ($settings | fromjson? // {}) as $s
  | (.context_window.context_window_size // 200000) as $window
  | ((env_on("DISABLE_COMPACT") or env_on("DISABLE_AUTO_COMPACT") or $s.autoCompactEnabled == false) | not) as $auto
  | (.model.id // "" | model_key) as $model_key
  # A per-model entry wins even when it is "auto", which leaves CC on its
  # default; a canonical key beats an alias spelling of the same model
  | ([$s.modelSettings // {} | to_entries[]
      | select((.key | model_key) == $model_key and (.value.autoCompactWindow | window_setting))]
     | sort_by(.key != $model_key) | first.value.autoCompactWindow
       // ($s.autoCompactWindow | window_setting)) as $configured
  | (env_tokens("CLAUDE_CODE_AUTO_COMPACT_WINDOW") | if . then [., 100000] | max else null end) as $env_window
  | (if $env_window then $env_window
     elif $auto and ($configured | type) == "number" then $configured
     else $window end) as $compact_window
  | ([$window, $compact_window] | min)
      - ([env_tokens("CLAUDE_CODE_MAX_OUTPUT_TOKENS") // 20000, 20000] | min)
      - (if $auto then 13000 else 0 end),
  (.context_window.current_usage.input_tokens // 0),
  (.context_window.current_usage.output_tokens // 0),
  (.context_window.current_usage.cache_creation_input_tokens // 0),
  (.context_window.current_usage.cache_read_input_tokens // 0),
  (.cwd // ""),
  (.rate_limits // {} | tojson),
  (.session_id // ""),
  (.effort.level // ""),
  (.model.display_name // ""),
  .version
' <<< "$input")

current=$(( input_tokens + output_tokens + cache_create + cache_read ))
(( compact_at < 1 )) && compact_at=1
pct_used=$(( current * 100 / compact_at ))
(( pct_used > 100 )) && pct_used=100

# ── LINE 1: Context % │ Dir:branch │ Model │ Effort ──
dir_name="${cwd##*/}"

git_dirty=""
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null) && {
  # diff-index flags mtime-only changes, and diff rewrites the index even with
  # --no-optional-locks; status compares content without taking index.lock, so
  # a tick never blocks the user's own git commands
  [ -z "$(git --no-optional-locks -C "$cwd" status --porcelain --untracked-files=no 2>/dev/null)" ] ||
    git_dirty="*"
}

color_for_pct "$pct_used"
line1="${sky}Context${reset} ${_pct_color}${pct_used}%${reset}"
line1+="${sep}"
line1+="${amber}${dir_name}${reset}"
if [ -n "$git_branch" ]; then
  if (( ${#git_branch} > branch_max )); then
    keep=$(( (branch_max - 1) / 2 ))
    git_branch="${git_branch:0:keep}…${git_branch:${#git_branch}-keep}"
  fi
  line1+="${muted}:${rose}${git_branch}${ruby}${git_dirty}${reset}"
fi
line1+="${sep}${claude}${model_name}${reset}"
# effort.level is absent when the model has no effort parameter. Symbols mirror
# the CLI's own effort ladder (○ ◐ ● ◉ ◈); colors run cold-to-hot like
# color_for_pct. No ultracode display: it runs at any effort level and stdin
# does not carry it.
if [ -n "$effort" ]; then
  line1+="${sep}"
  case "$effort" in
    max)    line1+="${red}◈ ${effort}${reset}" ;;
    xhigh)  line1+="${coral}◉ ${effort}${reset}" ;;
    high)   line1+="${amber}● ${effort}${reset}" ;;
    medium) line1+="${cyan}◐ ${effort}${reset}" ;;
    low)    line1+="${muted}○ ${effort}${reset}" ;;
    *)      line1+="${dim}◌ ${effort}${reset}" ;;
  esac
fi

# ── OAuth token resolution ──────────────────────────────
# Claude Code's default macOS sources: the env token, else the Keychain item,
# or the plaintext file CC writes when the Keychain is unavailable
get_oauth_token() {
  if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    printf '%s' "$CLAUDE_CODE_OAUTH_TOKEN"
    return
  fi
  { security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null ||
      cat "$HOME/.claude/.credentials.json" 2>/dev/null; } |
    jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
}

# ── Fetch usage data (API, cached) ──────────────────────
# The usage endpoint 429s aggressively (per-token window of ~5 requests,
# retry-after often 0: https://github.com/anthropics/claude-code/issues/30930),
# and CC's own background polling shares the same account budget. usage.json is
# written only on verified success; failures back off via usage.retry; sessions
# serialize fetches through refresh.lock. The cache lives outside /tmp so the
# last snapshot survives reboots (startup renders before stdin has rate_limits).
# rate-limits.json holds the latest 5h/7d observation merged from every
# session's stdin and the API snapshot, so a new session starts from its
# neighbours' live values instead of a snapshot up to a TTL old; a tick that
# advances it publishes under refresh.lock. processes/<pid> records when each
# Claude Code process's stdin last changed per window.
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
usage_file="${cache_dir}/usage.json"
rate_file="${cache_dir}/rate-limits.json"
retry_file="${cache_dir}/usage.retry"
error_file="${cache_dir}/usage-last-error.json"
lock_dir="${cache_dir}/refresh.lock"
processes_dir="${cache_dir}/processes"
retry_backoff_cold=300      # cold start or credential problem: retry soon
cache_max_age_enabled=300   # 5 min when extra is active
cache_max_age_disabled=10800 # 3h when extra is off (re-check if user enabled it)
[ -d "$cache_dir" ] || mkdir -p -m 700 "$cache_dir"

# Decide refresh from on-disk state; refresh_usage_cache re-runs this under the
# lock, since another session may have fetched or failed while this one queued
read_usage_state() {
  needs_refresh=true
  usage_data=""
  extra_active=0
  cache_max_age=$cache_max_age_disabled
  usage_mtime=0
  if [ -f "$usage_file" ]; then
    # Stat before reading: a fetch replacing the file in between then dates the
    # newer body too early instead of an older body too late
    usage_mtime=$(file_mtime "$usage_file")
    usage_data=$(<"$usage_file")
    # Detect extra via pattern match (no fork); it also picks the TTL
    if [[ "$usage_data" =~ \"is_enabled\"[[:space:]]*:[[:space:]]*true ]]; then
      cache_max_age=$cache_max_age_enabled
      extra_active=1
    fi
    (( _now - usage_mtime < cache_max_age )) && needs_refresh=false
  fi
  # Failure backoff. Marker: "token" = no credential, else HTTP status of the
  # last failure (000 = curl failed). Credential problems retry soon since CC
  # may refresh the OAuth token at any moment; other failures afford a full
  # TTL while a snapshot exists to render.
  if $needs_refresh && [ -f "$retry_file" ]; then
    local marker=''
    IFS= read -r marker < "$retry_file" # no fork; marker has no trailing newline
    retry_backoff=$retry_backoff_cold
    case "$marker" in
      token|401|403) ;;
      *) [ -n "$usage_data" ] && retry_backoff=$cache_max_age ;;
    esac
    (( _now - $(file_mtime "$retry_file") < retry_backoff )) && needs_refresh=false
  fi
}
read_usage_state

# Single-flight: on contention clear an expired lease (30s covers curl's 5s
# cap) and yield; the next tick re-decides from the fresh on-disk state
acquire_lock() {
  mkdir "$lock_dir" 2>/dev/null && return
  local lock_mtime
  lock_mtime=$(file_mtime "$lock_dir")
  (( lock_mtime > 0 && _now - lock_mtime > 30 )) && rmdir "$lock_dir" 2>/dev/null
  return 1
}

refresh_usage_cache() {
  acquire_lock || return
  read_usage_state
  if $needs_refresh; then
    # Orphans from ticks killed between mktemp and mv; only lock holders
    # create them, so sweeping while holding the lock is safe. set +f: the
    # script runs under set -f, which would keep the glob literal and make this
    # rm a silent no-op.
    set +f; rm -f "${cache_dir}"/tmp.*; set -f
    # A record unchanged for longer than the 7-day window holds only ended
    # windows, which Claude Code has already dropped from stdin
    [ -d "$processes_dir" ] && find "$processes_dir" -type f -mtime +8 -delete
    local token
    token=$(get_oauth_token)
    if [ -n "$token" ]; then
      local body_file http_code
      body_file=$(mktemp "${cache_dir}/tmp.XXXXXX")
      # Keep the bearer header out of curl's argument vector.
      http_code=$(printf 'Authorization: Bearer %s\n' "$token" |
        curl -s -o "$body_file" -w '%{http_code}' --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H @- \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/${claude_version}" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
      if jq -e '.five_hour' < "$body_file" >/dev/null 2>&1 && mv "$body_file" "$usage_file"; then
        rm -f "$retry_file"
        # Re-derive the coupled usage_data, extra_active, and cache_max_age
        # tuple so the Ex row and cache policy match the fresh response.
        read_usage_state
      else
        # Keep the last failed body for post-hoc diagnosis; kept across later
        # successes, so its mtime dates the last failure. Marker vocabulary is
        # classified by read_usage_state.
        mv "$body_file" "$error_file" 2>/dev/null || rm -f "$body_file"
        printf '%s' "${http_code:-000}" > "$retry_file"
      fi
    else
      printf 'token' > "$retry_file"
    fi
  fi
  rmdir "$lock_dir" 2>/dev/null
}

$needs_refresh && refresh_usage_cache

# ── Rate limit lines ────────────────────────────────────
# stdin rate_limits are process state in Claude Code (2.1.296): filled by the
# first API response, replayed unchanged while idle and across /clear, and a
# window is dropped once its reset passes. A window in stdin therefore counts
# as observed when its value changed from what this process last carried, and
# every tick merges it with the shared file and the API snapshot per window and
# renders the result. Claude Code runs the statusline as its direct child, so
# $PPID names the process.
process_file="${processes_dir}/${PPID}"
process_seen=''
changed_at=$_now
if [ -f "$process_file" ]; then
  IFS= read -r process_seen < "$process_file"
elif [ "$live_limits" != "{}" ]; then
  # A process records its first tick, which precedes its first API response, so
  # values without a record come from a process that outlived or predates its
  # record and may be replays from any time since it started
  changed_at=$(LC_ALL=C date -j -f '%a %b %e %T %Y' "$(LC_ALL=C ps -o lstart= -p "$PPID")" +%s 2>/dev/null) ||
    changed_at=0
fi

merge_rate_limits() { # shared_json; sets the row fields, process_record, and merged_limits
  {
    read -r five_pct
    read -r five_reset_epoch
    read -r five_source
    read -r seven_pct
    read -r seven_reset_epoch
    read -r seven_source
    read -r process_record
    read -r merged_limits
  } < <(jq -rn --arg live "$live_limits" --arg seen "$process_seen" --argjson changed_at "$changed_at" \
      --arg shared "$1" --arg api "$usage_data" --argjson api_at "$usage_mtime" --argjson now "$_now" \
      --argjson stale_after "$cache_max_age_disabled" '
    def epoch: if . then sub("(\\.[0-9]+)?(Z|[+-][0-9:]+)?$"; "") | strptime("%Y-%m-%dT%H:%M:%S") | mktime else null end;
    def win($at): if .used_percentage then {used_percentage: (.used_percentage | round), resets_at, observed_at: $at, fresh: (.fresh // false)} else null end;
    def api_win($at): if .utilization then {used_percentage: (.utilization | round), resets_at: (.resets_at | epoch), observed_at: $at, fresh: false} else null end;
    # The latest observation wins, because a limit reset can zero usage
    # without moving resets_at. An ended window ranks below an open one however
    # recent, so a long-idle replay cannot hide the current window; a null
    # reset (no window open) is current. Within one second a value that changed
    # on this tick beats the shared one, which beats a replay, so processes that
    # changed in the same second do not take turns overwriting each other.
    def rank: [(.resets_at == null or .resets_at > $now), .observed_at, .fresh];
    ($seen | fromjson? // {}) as $p
    | ($live | fromjson? // {}
        | with_entries(.key as $w | .value |= . + (
            if $p[$w] and ($p[$w] | del(.observed_at)) == . then {observed_at: $p[$w].observed_at, fresh: false}
            else {observed_at: $changed_at, fresh: true} end))) as $l
    | ($l | map_values(del(.fresh))) as $record
    | ($shared | fromjson? // {}) as $s
    | ($api | fromjson? // {}) as $a
    # Parenthesized: jq 1.7 (macOS /usr/bin/jq) rejects `reduce ... as $x`
    | (reduce ("five_hour", "seven_day") as $w ({};
        # max_by keeps the last of equal ranks
        ([($a[$w] | api_win($api_at)), ($l[$w] | win(.observed_at)), ($s[$w] | win(.observed_at // 0))]
          | map(select(.)) | max_by(rank) | del(.fresh)) as $pick
        | if $pick then .[$w] = $pick else . end)) as $merged
    # observed_at dates the last change or fetch of a value. A tick refetches
    # the snapshot by the time it is $stale_after old (its longest TTL), so an
    # older value means the refetch failed or no session ticked, and a new
    # window may have opened unseen, such as after a snapshot that showed none.
    | (("five_hour", "seven_day") as $w
        | ($merged[$w].used_percentage // ""), ($merged[$w].resets_at // ""),
          (if $l[$w] then "live"
           elif $now - ($merged[$w].observed_at // 0) < $stale_after then "shared"
           else "stale" end)),
      (if $seen != "" and $record == $p then "" else $record | tojson end),
      (if $merged == $s then "" else $merged | tojson end)
  ' 2>/dev/null)
}

shared_data=''
[ -f "$rate_file" ] && IFS= read -r shared_data < "$rate_file"
merge_rate_limits "$shared_data"
# Replace the record whole: a torn one would make the next tick's replay look
# new. tmp.* left by a killed tick ages out with the records.
if [ -n "$process_record" ]; then
  [ -d "$processes_dir" ] || mkdir -p -m 700 "$processes_dir"
  tmp=$(mktemp "${processes_dir}/tmp.XXXXXX") &&
    printf '%s\n' "$process_record" > "$tmp" && mv "$tmp" "$process_file"
fi
# Publish under the lock; when another session published after the read above,
# merge again on top of its file so neither advance is lost
if [ -n "$merged_limits" ] && acquire_lock; then
  latest_shared=''
  [ -f "$rate_file" ] && IFS= read -r latest_shared < "$rate_file"
  [ "$latest_shared" = "$shared_data" ] || merge_rate_limits "$latest_shared"
  [ -n "$merged_limits" ] && tmp=$(mktemp "${cache_dir}/tmp.XXXXXX") &&
    printf '%s\n' "$merged_limits" > "$tmp" && mv "$tmp" "$rate_file"
  rmdir "$lock_dir" 2>/dev/null
fi

# Queue every row first, then pad the time column to the widest rendered time
# string: mixed rows stay aligned, an all-expired display keeps its marker next
# to "--" instead of floating at timestamp width, and the Ex row shares the column.
row_labels=(); row_pcts=(); row_times=(); row_suffixes=(); _time_w=0
queue_row() { # label pct time suffix: single writer keeps the arrays aligned
  local t="${3:---}"
  row_labels+=("$1"); row_pcts+=("$2"); row_times+=("$t"); row_suffixes+=("$4")
  (( ${#t} > _time_w )) && _time_w=${#t}
}
queue_rate_row() { # label pct reset_epoch source
  local label="$1" pct="$2" reset_epoch="$3" suffix=""
  [ -n "$pct" ] || return
  # ≈: this session's own stdin has not carried the window yet; ≋: and the
  # value is past the snapshot's longest refetch interval
  case "$4" in
    shared) suffix=" ${cache}≈${reset}" ;;
    stale)  suffix=" ${cache}≋${reset}" ;;
  esac
  # Zero only a confirmed-ended window: a reset in the past means the next
  # window starts empty, so current usage is 0%; an unknown resets_at keeps the
  # pct because that window may still be live.
  if [ -n "$reset_epoch" ] && (( reset_epoch <= _now )); then
    pct=0
    reset_epoch=""
  fi
  # Keep "%m-%d %H:%M" for every real timestamp so the column reads uniformly,
  # rounded to the nearest 5 minutes so it does not jitter (19:59 vs 20:00)
  local reset_time=''
  [ -n "$reset_epoch" ] && reset_time=$(date -j -r $(( (reset_epoch + 150) / 300 * 300 )) +"%m-%d %H:%M")
  queue_row "$label" "$pct" "$reset_time" "$suffix"
}
queue_rate_row "5h" "$five_pct" "$five_reset_epoch" "$five_source"
queue_rate_row "7d" "$seven_pct" "$seven_reset_epoch" "$seven_source"
(( extra_active )) && queue_extra_rate_row

rate_lines=""
for _i in "${!row_labels[@]}"; do
  printf -v _time_pad '%-*s' "$_time_w" "${row_times[$_i]}"
  render_rate_row "${row_labels[$_i]}" "${row_pcts[$_i]}" "$_time_pad" "${row_suffixes[$_i]}"
  rate_lines+="${rate_lines:+\n}${_row}"
done

# ── Output ──────────────────────────────────────────────
# Print the full id because `claude --resume` and transcript lookups accept
# only that (the 8-character short id resolves background sessions alone);
# fading the tail keeps the prefix scannable
printf "%b\n%b" "$line1" "${muted}${session_id:0:8}${faint}${session_id:8}${reset}"
[ -n "$rate_lines" ] && printf "\n%b" "$rate_lines"

exit 0
