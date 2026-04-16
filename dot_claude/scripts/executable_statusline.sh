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
#   echo '{"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":50000,"output_tokens":10000}},"cwd":"/tmp"}' \
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
red='\033[38;2;255;85;85m'
coral='\033[38;2;255;127;100m'
magenta='\033[38;2;180;140;255m'
rose='\033[38;2;245;180;190m'
persimmon='\033[38;2;240;108;88m'
dim='\033[2m'
muted='\033[38;2;120;130;150m'
faint='\033[38;2;60;65;75m'
reset='\033[0m'

sep=" ${dim}│${reset} "

# ── Platform detection + epoch (single fork) ───────────
if [[ "$OSTYPE" == darwin* ]]; then
  _date_flavor=bsd
else
  _date_flavor=gnu
fi
read -r _now _month < <(date "+%s %m")

# ── Helpers ─────────────────────────────────────────────
file_mtime() {
  if [ "$_date_flavor" = "bsd" ]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

color_for_pct() {
  local pct=$1
  if (( pct >= 90 )); then printf "$red"
  elif (( pct >= 70 )); then printf "$coral"
  elif (( pct >= 50 )); then printf "$cyan"
  else printf "$muted"
  fi
}

build_bar() {
  local pct=$1 width=$2
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100

  local filled=$(( pct * width / 100 ))
  (( pct > 0 && filled == 0 )) && filled=1
  local empty=$(( width - filled ))
  local bar_color
  bar_color=$(color_for_pct "$pct")

  local fill_buf empty_buf
  printf -v fill_buf '%*s' "$filled" ''
  fill_buf="${fill_buf// /▰}"
  printf -v empty_buf '%*s' "$empty" ''
  empty_buf="${empty_buf// /▱}"

  printf "${bar_color}${fill_buf}${faint}${empty_buf}${reset}"
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

cents_to_dollars() {
  local raw; raw=$(printf "%.0f" "${1:-0}" 2>/dev/null) || raw=0
  local whole=$(( raw / 100 )) rem=$(( raw % 100 ))
  if [ "$rem" -eq 0 ]; then printf '%d' "$whole"
  else printf '%d.%02d' "$whole" "$rem"
  fi
}

render_rate_row() {
  local label="$1" pct_raw="$2" reset_time="$3" suffix="$4"
  local pct bar pct_color pct_fmt
  pct=$(printf "%.0f" "$pct_raw" 2>/dev/null)
  [ -z "$pct" ] && pct=0
  [[ "$pct" =~ ^-?[0-9]+$ ]] || pct=0
  bar=$(build_bar "$pct" "$bar_width")
  pct_color=$(color_for_pct "$pct")
  pct_fmt=$(printf "%3d" "$pct")
  printf '%s' "${muted}${label}${reset} ${bar}${pct_color}${pct_fmt}%${reset} ${dim}⟳${reset}  ${sky}${reset_time}${reset}${suffix}${stale_marker}"
}

render_extra_rate_row() {
  [ -n "$usage_data" ] || return
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
  local extra_used extra_limit month extra_reset extra_suffix
  extra_used=$(cents_to_dollars "$extra_used_raw")
  extra_limit=$(cents_to_dollars "$extra_limit_raw")
  month=$(( 10#$_month % 12 + 1 ))
  extra_reset=$(printf "%02d-01" "$month")
  extra_suffix=" ${dim}\$${extra_used}/\$${extra_limit}${reset}"
  render_rate_row "Ex" "$extra_pct_raw" "$extra_reset" "$extra_suffix"
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
  (.rate_limits.seven_day.resets_at // "")
' <<< "$input")

: "${size:=200000}"
(( size == 0 )) && size=200000

settings_path="$HOME/.claude/settings.json"
# Effort resolution mirrors CLI's UhH(): env CLAUDE_CODE_EFFORT_LEVEL takes
# precedence over settings.effortLevel. "auto"/"unset" in env is an explicit
# override meaning "model default" — it must NOT fall through to settings.
# Only an unset env falls through. "max" is runtime-only, not in settings schema.
effort="default"
_effort_env_set=0
[ -n "${CLAUDE_CODE_EFFORT_LEVEL+x}" ] && _effort_env_set=1
_effort_env=$(printf '%s' "${CLAUDE_CODE_EFFORT_LEVEL:-}" | tr '[:upper:]' '[:lower:]')
case "$_effort_env" in
  low|medium|high|xhigh|max) effort="$_effort_env" ;;
esac
auto_compact=0
auto_compact_enabled=1
if [ -f "$settings_path" ]; then
  _settings=$(<"$settings_path")
  if [ "$effort" = "default" ] && [ "$_effort_env_set" = 0 ]; then
    [[ "$_settings" =~ \"effortLevel\"[[:space:]]*:[[:space:]]*\"(low|medium|high|xhigh)\" ]] && effort="${BASH_REMATCH[1]}"
  fi
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

# Denominator = min(model capacity, autoCompactWindow); CC's context_window_size
# only reports model capacity. HIDDEN_TOKENS accounts for system prompt + MCP defs
# + CLAUDE.md not included in current_usage (~10pp on 200k, ~2pp on 1M).
#
# By design: when running a [1m] model variant, autoCompactWindow is set lower
# than 1M (e.g. 400k) as the intended *working budget* — the bar should read
# 100% at that threshold and compact there, using 1M only as spike headroom.
# Recommended pattern per Claude Code maintainer (see .claude/CLAUDE.md).
# Do NOT "fix" this to uncap the denominator.
HIDDEN_TOKENS=20000
effective_size=$size
(( auto_compact_enabled && auto_compact > 0 && auto_compact < effective_size )) && effective_size=$auto_compact

current=$(( input_tokens + output_tokens + cache_create + cache_read ))
pct_used=$(( (current + HIDDEN_TOKENS) * 100 / effective_size ))
(( pct_used > 100 )) && pct_used=100

# ── LINE 1: Context % │ Dir:branch │ Effort ──
pct_color=$(color_for_pct "$pct_used")
{ [ -z "$cwd" ] || [ "$cwd" = "null" ]; } && cwd=$(pwd)
dir_name="${cwd##*/}"

git_branch=""
git_dirty=""
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null) && {
  git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null || git_dirty="*"
}

line1="${sky}Context${reset} ${pct_color}${pct_used}%${reset}"
line1+="${sep}"
line1+="${amber}${dir_name}${reset}"
if [ -n "$git_branch" ]; then
  display_branch=$(truncate_middle "$git_branch" 40)
  line1+="${muted}:${rose}${display_branch}${persimmon}${git_dirty}${reset}"
fi
line1+="${sep}"
case "$effort" in
  max)    line1+="${red}✦ ${effort}${reset}" ;;
  xhigh)  line1+="${coral}● ${effort}${reset}" ;;
  high)   line1+="${magenta}◉ ${effort}${reset}" ;;
  medium) line1+="${cyan}◐ ${effort}${reset}" ;;
  low)    line1+="${dim}◔ ${effort}${reset}" ;;
  *)      line1+="${dim}◑ ${effort}${reset}" ;;
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

# ── Fetch extra usage data (API, cached — only field not in stdin) ──
cache_dir="/tmp/claude"
cache_file="${cache_dir}/statusline-usage-cache.json"
cache_max_age_enabled=300   # 5 min when extra is active
cache_max_age_disabled=10800 # 3h when extra is off (re-check if user enabled it)
[ -d "$cache_dir" ] || mkdir -p "$cache_dir"

# Resolve version (cached to file — avoids fork on every tick)
version_file="${cache_dir}/statusline-claude-version"
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

needs_refresh=true
usage_data=""
cache_age=0

if [ -f "$cache_file" ]; then
  cache_age=$(( _now - $(file_mtime "$cache_file") ))
  usage_data=$(<"$cache_file")
  # Pick TTL based on whether extra is enabled in cached data (pattern match, no fork)
  cache_max_age=$cache_max_age_disabled
  [[ "$usage_data" =~ \"is_enabled\"[[:space:]]*:[[:space:]]*true ]] && cache_max_age=$cache_max_age_enabled
  (( cache_age < cache_max_age )) && needs_refresh=false
fi

refresh_usage_cache() {
  local token
  token=$(get_oauth_token)
  [ -n "$token" ] && [ "$token" != "null" ] || return

  local body_file
  body_file=$(mktemp "${cache_dir}/statusline-response.XXXXXX")
  curl -s -o "$body_file" --max-time 5 \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code/${claude_version}" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null

  if [ -f "$body_file" ] && jq -e '.five_hour' < "$body_file" >/dev/null 2>&1; then
    usage_data=$(<"$body_file")
    cache_age=0
    mv "$body_file" "$cache_file"
    return
  fi
  # Failed (429, timeout, etc.) — touch/create cache to delay retry by one full TTL
  rm -f "$body_file"
  touch "$cache_file"
  cache_age=0
}

$needs_refresh && refresh_usage_cache

# ── Rate limit lines ────────────────────────────────────
# 5h/7d from stdin (real-time), fallback to API cache when stdin has no rate_limits
rate_lines=""
stale_marker=""
bar_width=10

# Fallback: before first conversation, stdin may lack rate_limits — use cached API data
if [ -z "$five_hour_pct_raw" ] && [ -n "$usage_data" ]; then
  {
    read -r five_hour_pct_raw
    read -r five_hour_reset_epoch
    read -r seven_day_pct_raw
    read -r seven_day_reset_epoch
  } < <(jq -r '
    def epoch: if . and . != "" then sub("(\\.[0-9]+)?(Z|[+-][0-9:]+)?$"; "") | strptime("%Y-%m-%dT%H:%M:%S") | mktime else "" end;
    (.five_hour.utilization // ""),
    (.five_hour.resets_at // "" | epoch),
    (.seven_day.utilization // ""),
    (.seven_day.resets_at // "" | epoch)
  ' <<< "$usage_data" 2>/dev/null)
fi

if [ -n "$five_hour_pct_raw" ]; then
  # Keep "%m-%d %H:%M" for all rows — do NOT shorten 5h to "%H:%M", breaks alignment
  five_hour_reset=$(format_epoch "$five_hour_reset_epoch" "%m-%d %H:%M" 2>/dev/null)
  seven_day_reset=$(format_epoch "$seven_day_reset_epoch" "%m-%d %H:%M" 2>/dev/null)

  rate_lines+="$(render_rate_row "5h" "$five_hour_pct_raw" "$five_hour_reset")"
  rate_lines+="\n$(render_rate_row "7d" "$seven_day_pct_raw" "$seven_day_reset")"

  extra_row=$(render_extra_rate_row)
  [ -n "$extra_row" ] && rate_lines+="\n${extra_row}"
fi

# ── Output ──────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$rate_lines" ] && printf "\n\n%b" "$rate_lines"

exit 0
