#!/bin/zsh
set -euo pipefail

{ whence -p claude || [[ -x "$HOME/.local/bin/claude" ]]; } &>/dev/null && exit 0

echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
