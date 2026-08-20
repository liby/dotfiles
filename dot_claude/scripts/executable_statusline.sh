#!/bin/bash
# Claude Code statusline — renders context usage, git info, rate limits.
# Reads JSON from stdin (statusLine hook), outputs ANSI-colored text.
#
# CAUTION: The rate-limit rendering block runs at the TOP LEVEL, not inside
# a function. Do NOT use `local` there — it silently fails outside functions.
# Also, API values may be floats (e.g. 0.0); bash $(()) only handles integers.
#
# Verify after editing (CC sets CLAUDE_CODE_EFFORT_LEVEL from settings.env; pass
# it explicitly here to exercise the same effort-resolution path the runtime uses):
#   echo '{"model":{"display_name":"Fable 5"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":50000,"output_tokens":10000}},"cwd":"/tmp"}' \
#   | CLAUDE_CODE_EFFORT_LEVEL=high bash ~/.claude/scripts/statusline.sh

set -f

input=$(</dev/stdin)

if [ -z "$input" ]; then
  printf "Claude"
  exit 0
fi

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

# ── Platform detection + epoch (single fork) ───────────
if [[ "$OSTYPE" == darwin* ]]; then
  _date_flavor=bsd
else
  _date_flavor=gnu
fi
read -r _now _month < <(date "+%s %m")

# ── Terminal width (CC >= 2.1.153 passes COLUMNS/LINES as env to statusline) ──
# Absent for older CC or non-tty -> fall back to 80. Scales the branch label and
# rate-bar width down on narrow terminals.
cols=${COLUMNS:-80}
[[ "$cols" =~ ^[0-9]+$ ]] || cols=80
if   (( cols < 60 ));  then branch_max=16; bar_width=6
elif (( cols < 100 )); then branch_max=28; bar_width=8
else                        branch_max=40; bar_width=10
fi

# ── Helpers ─────────────────────────────────────────────
file_mtime() {
  if [ "$_date_flavor" = "bsd" ]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
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

truncate_middle() {
  local str="$1" max_len="${2:-40}"
  local len=${#str}
  if [ "$len" -le "$max_len" ]; then
    printf '%s' "$str"
    return
  fi
  local keep=$(( (max_len - 1) / 2 ))
  printf '%s…%s' "${str:0:$keep}" "${str:$((len - keep))}"
}

format_epoch() {
  local epoch="$1" fmt="$2"
  [[ "$epoch" =~ ^[0-9]+$ ]] && (( epoch > 0 )) || return
  # Round to nearest 5 minutes to avoid display jitter (e.g. 19:59 vs 20:00)
  local remainder=$(( epoch % 300 ))
  (( remainder >= 150 )) && epoch=$(( epoch + 300 - remainder )) || epoch=$(( epoch - remainder ))
  if [ "$_date_flavor" = "bsd" ]; then
    date -j -r "$epoch" +"$fmt"
  else
    date -d "@$epoch" +"$fmt"
  fi
}

cents_to_dollars() { # sets _dollars
  local raw
  printf -v raw "%.0f" "${1:-0}" 2>/dev/null
  [[ "$raw" =~ ^-?[0-9]+$ ]] || raw=0
  local whole=$(( raw / 100 )) rem=$(( raw % 100 ))
  if [ "$rem" -eq 0 ]; then _dollars=$whole
  else printf -v _dollars '%d.%02d' "$whole" "$rem"
  fi
}

render_rate_row() { # sets _row
  local label="$1" pct_raw="$2" reset_time="$3" suffix="$4"
  local pct pct_fmt
  printf -v pct "%.0f" "$pct_raw" 2>/dev/null
  [[ "$pct" =~ ^-?[0-9]+$ ]] || pct=0
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

# ── Extract JSON data (single jq call) ──────────────────
# 5h/7d rate limits come from stdin (CC >= 2.1.80), no API needed
{
  read -r size
  read -r input_tokens
  read -r output_tokens
  read -r cache_create
  read -r cache_read
  read -r cwd
  read -r five_hour_pct_raw
  read -r five_hour_reset_epoch
  read -r seven_day_pct_raw
  read -r seven_day_reset_epoch
  read -r stdin_effort
  read -r model_name
} < <(jq -r '
  (.context_window.context_window_size // 200000),
  (.context_window.current_usage.input_tokens // 0),
  (.context_window.current_usage.output_tokens // 0),
  (.context_window.current_usage.cache_creation_input_tokens // 0),
  (.context_window.current_usage.cache_read_input_tokens // 0),
  (.cwd // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.seven_day.resets_at // ""),
  (.effort.level // ""),
  (.model.display_name // "")
' <<< "$input")

: "${size:=200000}"
(( size == 0 )) && size=200000

settings_path="$HOME/.claude/settings.json"
# Prefer stdin effort.level (CC >= 2.1.121, reflects runtime state including env
# priority). Fall back to env / settings for older CC versions.
effort="default"
case "$stdin_effort" in
  low|medium|high|xhigh|max) effort="$stdin_effort" ;;
  *)
    _effort_env=$(printf '%s' "${CLAUDE_CODE_EFFORT_LEVEL:-}" | tr '[:upper:]' '[:lower:]')
    case "$_effort_env" in
      low|medium|high|xhigh|max) effort="$_effort_env" ;;
    esac
    ;;
esac
auto_compact=0
auto_compact_enabled=1
if [ -f "$settings_path" ]; then
  _settings=$(<"$settings_path")
  if [ "$effort" = "default" ]; then
    [[ "$_settings" =~ \"effortLevel\"[[:space:]]*:[[:space:]]*\"(low|medium|high|xhigh)\" ]] && effort="${BASH_REMATCH[1]}"
  fi
  # This display reads settings.json only and intentionally ignores CC's existing
  # auto-compact env overrides; add their precedence and denominator math together.
  [[ "$_settings" =~ \"autoCompactWindow\"[[:space:]]*:[[:space:]]*([0-9]+) ]] && auto_compact="${BASH_REMATCH[1]}"
  [[ "$_settings" =~ \"autoCompactEnabled\"[[:space:]]*:[[:space:]]*false ]] && auto_compact_enabled=0
fi
# autocompact disabled if any of DISABLE_COMPACT/DISABLE_AUTO_COMPACT/autoCompactEnabled=false.
# Edge-trim (not interior) + lowercase to mirror CC's SH() .toLowerCase().trim().
_is_truthy() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  v=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
  [[ "$v" =~ ^(1|true|yes|on)$ ]]
}
[ -n "$DISABLE_COMPACT" ] && _is_truthy "$DISABLE_COMPACT" && auto_compact_enabled=0
[ -n "$DISABLE_AUTO_COMPACT" ] && _is_truthy "$DISABLE_AUTO_COMPACT" && auto_compact_enabled=0

# CC triggers auto-compact at min(model_capacity, autoCompactWindow) - COMPACT_RESERVE.
# 33000 = nAK(20000, max-output reserve) + BAK(13000, compact buffer).
# Reverse-engineered from CLI 2.1.150 e6H()/LG_(). May change across versions.
# Keep the denominator capped at autoCompactWindow; it mirrors CC's trigger threshold.
COMPACT_RESERVE=33000
effective_size=$size
(( auto_compact_enabled && auto_compact > 0 && auto_compact < effective_size )) && effective_size=$auto_compact

current=$(( input_tokens + output_tokens + cache_create + cache_read ))
compact_at=$(( effective_size - COMPACT_RESERVE ))
(( compact_at < 1 )) && compact_at=1
pct_used=$(( current * 100 / compact_at ))
(( pct_used > 100 )) && pct_used=100

# ── LINE 1: Context % │ Dir:branch │ Model │ Effort ──
{ [ -z "$cwd" ] || [ "$cwd" = "null" ]; } && cwd=$(pwd)
dir_name="${cwd##*/}"

git_branch=""
git_dirty=""
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null) && {
  git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null || git_dirty="*"
}

color_for_pct "$pct_used"
line1="${sky}Context${reset} ${_pct_color}${pct_used}%${reset}"
line1+="${sep}"
line1+="${amber}${dir_name}${reset}"
if [ -n "$git_branch" ]; then
  display_branch=$(truncate_middle "$git_branch" "$branch_max")
  line1+="${muted}:${rose}${display_branch}${ruby}${git_dirty}${reset}"
fi
line1+="${sep}"
if [ -n "$model_name" ]; then
  line1+="${claude}${model_name}${reset}"
  line1+="${sep}"
fi
# Symbols mirror the CLI's own effort ladder (○ ◐ ● ◉ ◈); colors run cold-to-hot
# like color_for_pct. No ultracode display: stdin only carries effort.level, which
# reads "xhigh" while ultracode is active; session state never reaches this script.
case "$effort" in
  max)    line1+="${red}◈ ${effort}${reset}" ;;
  xhigh)  line1+="${coral}◉ ${effort}${reset}" ;;
  high)   line1+="${amber}● ${effort}${reset}" ;;
  medium) line1+="${cyan}◐ ${effort}${reset}" ;;
  low)    line1+="${muted}○ ${effort}${reset}" ;;
  *)      line1+="${dim}◌ ${effort}${reset}" ;;
esac

# ── OAuth token resolution ──────────────────────────────
try_extract_token() {
  local blob="$1"
  local t
  t=$(jq -r '.claudeAiOauth.accessToken // empty' <<< "$blob" 2>/dev/null)
  [ -n "$t" ] && [ "$t" != "null" ] && echo "$t" && return 0
  return 1
}

get_oauth_token() {
  if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    echo "$CLAUDE_CODE_OAUTH_TOKEN"
    return 0
  fi

  if command -v security >/dev/null 2>&1; then
    local blob
    blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    [ -n "$blob" ] && try_extract_token "$blob" && return 0
  fi

  local creds_file="${HOME}/.claude/.credentials.json"
  if [ -f "$creds_file" ]; then
    try_extract_token "$(<"$creds_file")" && return 0
  fi

  if command -v secret-tool >/dev/null 2>&1; then
    local blob
    blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
    [ -n "$blob" ] && try_extract_token "$blob" && return 0
  fi

  echo ""
}

# ── Fetch usage data (API, cached) ──────────────────────
# The usage endpoint 429s aggressively (per-token window of ~5 requests,
# retry-after often 0: https://github.com/anthropics/claude-code/issues/30930),
# and CC's own background polling shares the same account budget. usage.json is
# written only on verified success; failures back off via usage.retry; sessions
# serialize fetches through refresh.lock. The cache lives outside /tmp so the
# last snapshot survives reboots (startup renders before stdin has rate_limits).
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
usage_file="${cache_dir}/usage.json"
retry_file="${cache_dir}/usage.retry"
error_file="${cache_dir}/usage-last-error.json"
lock_dir="${cache_dir}/refresh.lock"
retry_backoff_cold=300      # cold start or credential problem: retry soon
cache_max_age_enabled=300   # 5 min when extra is active
cache_max_age_disabled=10800 # 3h when extra is off (re-check if user enabled it)
[ -d "$cache_dir" ] || mkdir -p -m 700 "$cache_dir"

# Resolve version (cached to file — avoids fork on every tick)
version_file="${cache_dir}/claude-version"
version_max_age=3600
claude_version=""
if [ -f "$version_file" ] && (( _now - $(file_mtime "$version_file") < version_max_age )); then
  claude_version=$(<"$version_file")
fi
if [ -z "$claude_version" ]; then
  _link=$(readlink "$HOME/.local/bin/claude" 2>/dev/null)
  claude_version=${_link##*/}
  [ -z "$claude_version" ] && claude_version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  [ -n "$claude_version" ] && echo "$claude_version" > "$version_file"
fi

# Decide refresh from on-disk state; refresh_usage_cache re-runs this under the
# lock, since another session may have fetched or failed while this one queued
read_usage_state() {
  needs_refresh=true
  usage_data=""
  extra_active=0
  cache_max_age=$cache_max_age_disabled
  if [ -f "$usage_file" ]; then
    usage_data=$(<"$usage_file")
    # Detect extra via pattern match (no fork); it also picks the TTL
    if [[ "$usage_data" =~ \"is_enabled\"[[:space:]]*:[[:space:]]*true ]]; then
      cache_max_age=$cache_max_age_enabled
      extra_active=1
    fi
    (( _now - $(file_mtime "$usage_file") < cache_max_age )) && needs_refresh=false
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

refresh_usage_cache() {
  # Single-flight: on contention clear an expired lease (30s covers curl's 5s
  # cap) and yield; the next tick re-decides from the fresh on-disk state
  if ! mkdir "$lock_dir" 2>/dev/null; then
    local lock_mtime
    lock_mtime=$(file_mtime "$lock_dir")
    (( lock_mtime > 0 && _now - lock_mtime > 30 )) && rmdir "$lock_dir" 2>/dev/null
    return
  fi
  read_usage_state
  if $needs_refresh; then
    # Orphans from ticks killed mid-fetch; safe to sweep while holding the
    # lock. set +f: the script runs under set -f, which would keep the glob
    # literal and make this rm a silent no-op.
    set +f; rm -f "${cache_dir}"/usage-response.*; set -f
    local token
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
      local body_file http_code
      body_file=$(mktemp "${cache_dir}/usage-response.XXXXXX")
      http_code=$(curl -s -o "$body_file" -w '%{http_code}' --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/${claude_version}" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
      if jq -e '.five_hour' < "$body_file" >/dev/null 2>&1 && mv "$body_file" "$usage_file"; then
        rm -f "$retry_file"
        # Re-derive the whole tuple (usage_data, extra_active, cache_max_age):
        # updating only usage_data left extra_active stale, dropping the Ex
        # row on the tick that performed a cold fetch.
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
# stdin carries live rate_limits (CC >= 2.1.80) only after the session's first
# message; the last API snapshot fills the startup gap, per window.
fb_five_pct=""; fb_five_reset=""; fb_seven_pct=""; fb_seven_reset=""
if { [ -z "$five_hour_pct_raw" ] || [ -z "$seven_day_pct_raw" ]; } && [ -n "$usage_data" ]; then
  {
    read -r fb_five_pct
    read -r fb_five_reset
    read -r fb_seven_pct
    read -r fb_seven_reset
  } < <(jq -r '
    def epoch: if . and . != "" then sub("(\\.[0-9]+)?(Z|[+-][0-9:]+)?$"; "") | strptime("%Y-%m-%dT%H:%M:%S") | mktime else "" end;
    (.five_hour.utilization // ""),
    (.five_hour.resets_at // "" | epoch),
    (.seven_day.utilization // ""),
    (.seven_day.resets_at // "" | epoch)
  ' <<< "$usage_data" 2>/dev/null)
fi

# Queue every row first, then pad the time column to the widest rendered time
# string: mixed rows stay aligned, an all-expired display keeps ≈ next to "--"
# instead of floating at timestamp width, and the Ex row shares the column.
row_labels=(); row_pcts=(); row_times=(); row_suffixes=(); _time_w=0
queue_row() { # label pct time suffix: single writer keeps the arrays aligned
  local t="${3:---}"
  row_labels+=("$1"); row_pcts+=("$2"); row_times+=("$t"); row_suffixes+=("$4")
  (( ${#t} > _time_w )) && _time_w=${#t}
}
queue_rate_row() { # label stdin_pct stdin_reset_epoch snapshot_pct snapshot_reset_epoch
  local label="$1" pct="$2" reset_epoch="$3" suffix=""
  if [ -z "$pct" ]; then
    pct="$4"
    reset_epoch="$5"
    [ -n "$pct" ] || return
    suffix=" ${cache}≈${reset}"
    # Zero only a confirmed-ended window: a reset in the past means the next
    # window starts empty, so current usage is 0%; an unparseable resets_at
    # keeps the cached pct because that window may still be live.
    if [[ "$reset_epoch" =~ ^[0-9]+$ ]] && (( reset_epoch <= _now )); then
      pct=0
      reset_epoch=""
    fi
  fi
  # Keep "%m-%d %H:%M" for every real timestamp so the column reads uniformly
  local reset_time=''
  [[ "$reset_epoch" =~ ^[0-9]+$ ]] && reset_time=$(format_epoch "$reset_epoch" "%m-%d %H:%M" 2>/dev/null)
  queue_row "$label" "$pct" "$reset_time" "$suffix"
}
queue_rate_row "5h" "$five_hour_pct_raw" "$five_hour_reset_epoch" "$fb_five_pct" "$fb_five_reset"
queue_rate_row "7d" "$seven_day_pct_raw" "$seven_day_reset_epoch" "$fb_seven_pct" "$fb_seven_reset"
(( extra_active )) && queue_extra_rate_row

rate_lines=""
for _i in "${!row_labels[@]}"; do
  printf -v _time_pad '%-*s' "$_time_w" "${row_times[$_i]}"
  render_rate_row "${row_labels[$_i]}" "${row_pcts[$_i]}" "$_time_pad" "${row_suffixes[$_i]}"
  rate_lines+="${rate_lines:+\n}${_row}"
done

# ── Output ──────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$rate_lines" ] && printf "\n\n%b" "$rate_lines"

exit 0
