#!/bin/zsh
set -euo pipefail

command -v claude &>/dev/null && exit 0

echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
