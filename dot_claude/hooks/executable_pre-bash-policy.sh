#!/usr/bin/env bash
# PreToolUse hook for Bash.
# Blocks commands that have better alternatives (find → fd, dev/build/start).

source "$(dirname "$0")/_lib.sh"

require_jq
CMD=$(parse_command) || exit 0

# Block find → suggest fd
if echo "$CMD" | grep -qE '(^|\||;|&&|\|\||\$\()\s*(rtk\s+(proxy\s+)?)?find\s'; then
  block "Use fd instead of find. fd has simpler syntax and respects .gitignore by default."
fi

# Block dev/build/start commands (frontend projects)
if echo "$CMD" | grep -qE '(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|build|start|serve)\b'; then
  block "Do not run dev/build/start/serve commands. Verify through code review, type checking, and linting instead."
fi

exit 0
