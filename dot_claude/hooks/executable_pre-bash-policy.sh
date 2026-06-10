#!/usr/bin/env bash
# PreToolUse hook for Bash.
# Blocks commands that have better alternatives (find → fd, dev/start/serve).

source "$(dirname "$0")/_lib.sh"

require_jq
CMD=$(parse_command) || exit 0

# Block find → suggest fd
if echo "$CMD" | grep -qE '(^|\||;|&&|\|\||\$\()\s*(rtk\s+(proxy\s+)?)?find\s'; then
  block "Use fd instead of find. fd has simpler syntax and respects .gitignore by default."
fi

# Block dev/start/serve commands (long-running servers; agent-run copies orphan and collide with the user's own)
if echo "$CMD" | grep -qE '(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|start|serve)\b'; then
  block "Do not run dev/start/serve commands, even when explicitly asked; do not retry. If a running app is needed, ask the user to run it in their own terminal (e.g. ! npm run dev). Otherwise verify through code review, type checking, and linting."
fi

exit 0
