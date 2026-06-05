#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

# uv is installed via Homebrew (see Brewfile / run_onchange_before_30); load brew
# so `uv` resolves in this non-interactive script.
if [[ "$(uname -m)" == "arm64" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

# pyright: Python LSP server spawned by Claude Code's pyright-lsp plugin, which does
# not bundle it. `uv tool install` is idempotent and places entry points in
# ~/.local/bin (already on PATH via dot_zshrc), so reruns are safe.
uv tool install pyright
