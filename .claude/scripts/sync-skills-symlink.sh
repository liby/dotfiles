#!/usr/bin/env zsh
# PostToolUse hook for Edit|MultiEdit|Write
# When a file under .claude/skills/ or .agents/skills/ is edited,
# ensure .agents/skills -> ../.claude/skills symlink exists (Codex compat).

local file_path=$(jq -r '.tool_input.file_path // empty')
[[ "$file_path" == */.claude/skills/* || "$file_path" == */.agents/skills/* ]] || exit 0

local root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null) || exit 0
local agents="$root/.agents/skills"
local claude="$root/.claude/skills"

# Codex scenario: .agents/skills is a real dir, migrate to .claude/skills
if [[ -d "$agents" ]] && [[ ! -L "$agents" ]]; then
  mkdir -p "$claude"
  cp -rn "$agents"/* "$claude/" 2>/dev/null
  rm -rf "$agents"
fi

[[ -d "$claude" ]] || exit 0

mkdir -p "$root/.agents"
ln -sfn ../.claude/skills "$agents"
