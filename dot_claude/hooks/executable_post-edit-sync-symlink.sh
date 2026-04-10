#!/usr/bin/env bash
# PostToolUse hook for Edit|Write.
# Ensures .agents/skills -> .claude/skills symlink exists for Codex compatibility.

file_path=$(jq -r '.tool_input.file_path // empty')
[[ "$file_path" == */.claude/skills/* || "$file_path" == */.agents/skills/* ]] || exit 0

root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null) || exit 0
agents="$root/.agents/skills"
claude="$root/.claude/skills"

# Codex scenario: .agents/skills is a real dir, migrate to .claude/skills
if [[ -d "$agents" ]] && [[ ! -L "$agents" ]]; then
  mkdir -p "$claude"
  cp -rn "$agents"/* "$claude/" 2>/dev/null
  rm -rf "$agents"
fi

[[ -d "$claude" ]] || exit 0

mkdir -p "$root/.agents"
ln -sfn ../.claude/skills "$agents"
