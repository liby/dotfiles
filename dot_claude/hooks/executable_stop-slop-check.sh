#!/usr/bin/env bash
# Stop hook: scan the latest main-thread assistant turn for AI-slop patterns
# and force one corrective turn if any fire.
#
# Design notes:
# - Claude Code splits one assistant turn across multiple jsonl entries
#   (thinking, tool_use, text), each its own line but sharing message.id.
#   We group by message.id and concatenate text blocks for the latest turn.
# - Loop guard relies on the harness `stop_hook_active` flag: if Claude
#   is already retrying after a previous block, exit 0 to prevent loops.
# - Sidechain (subagent) entries are filtered so subagent output does not
#   leak into the scan.
# - Fenced and inline code spans are stripped before scanning, so backtick
#   references to forbidden words (e.g. `落地` for discussion) are exempt.
# - Rules are defined as parallel arrays (label / pattern / hint); adding
#   a new rule = append one row to each array.

source "$(dirname "$0")/_lib.sh"
require_jq

# Force UTF-8 locale so Chinese punctuation in regex character classes
# is interpreted byte-correctly. macOS default is usually UTF-8, this
# pins it explicitly.
export LC_ALL=en_US.UTF-8

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
[ "$STOP_ACTIVE" = "true" ] && exit 0

LATEST_MSG=$(jq -r '
  select(.type == "assistant" and (.isSidechain // false) == false)
  | select(.message.id != null)
  | select([.message.content[]?.type] | index("text"))
  | .message.id
' "$TRANSCRIPT" 2>/dev/null | tail -1)
[ -z "$LATEST_MSG" ] && exit 0

LAST_TEXT=$(jq -r --arg mid "$LATEST_MSG" '
  select(.type == "assistant" and (.isSidechain // false) == false and .message.id == $mid)
  | .message.content[]?
  | select(.type == "text")
  | .text
' "$TRANSCRIPT" 2>/dev/null | head -c 50000)
[ -z "$LAST_TEXT" ] && exit 0

SCAN=$(printf '%s' "$LAST_TEXT" | perl -0777 -pe 's/```[^\n]*\n.*?\n```//gs; s/`[^`\n]*`//g')

# Rule table. Index i across all three arrays defines one rule.
# Sentence-boundary anchor for Chinese/English permission-asking patterns:
# match line start, or after sentence-ending punctuation, bullet markers,
# or whitespace. Excludes recap forms like 你刚才不是要我X吗 (preceded by
# a non-anchor char) and idioms like 要不要紧 (next char outside expected set).
SB='(^|[ 	。！？；,，*•-])'
PATTERNS=(
  '—'
  '让我一步步分析|让我们来看|让我先|Let me break this down|Let me start by|综上所述|总的来说|一句话总结|In conclusion|To sum up'
  "${SB}要不要|(^|[^是])要我[^。！？\\n]{0,30}吗|是否需要|Want me to |Should I "
  "${SB}我建议先|${SB}建议你[^。！？\\n]{0,15}先"
  '这说明|也就是说|可以看出|换句话说|In other words'
  '抓手|赋能|闭环|颗粒度|底层逻辑|落地|落库|落盘'
)
LABELS=(
  "em-dash"
  "signposting opener"
  "permission-asking"
  "soft-deferral"
  "trailing restatement"
  "corp jargon"
)
HINTS=(
  'use commas/periods/colons instead of `—`'
  'jump straight to analysis, no `让我`/`Let me`/`综上` openers'
  'do the obvious next step, do not ask (`要我...吗？`/`要不要X`/`Should I`)'
  'do not defer the decision; replace `我建议先`/`建议你...先` with the action itself'
  'delete `这说明`/`也就是说` summary tails'
  'replace `落地`/`抓手`/`赋能` style words with plain language'
)

VIOLATIONS=()
DETAIL=()
for i in "${!LABELS[@]}"; do
  if printf '%s' "$SCAN" | grep -qE "${PATTERNS[$i]}"; then
    VIOLATIONS+=("${LABELS[$i]}")
    DETAIL+=("- ${LABELS[$i]}: ${HINTS[$i]}")
  fi
done

[ ${#VIOLATIONS[@]} -eq 0 ] && exit 0

LIST=$(IFS=,; echo "${VIOLATIONS[*]}")
{
  echo "Self-check fired on the previous response: $LIST."
  printf '%s\n' "${DETAIL[@]}"
  echo "To reference a forbidden word for discussion, wrap it in backticks; only backtick-stripped content is exempt from this scan, plain quotes 「」/\"\" are not."
  echo "This is your only correction attempt; if you cannot fix all listed issues, ship and we iterate."
} >&2
exit 2
