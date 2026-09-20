#!/bin/zsh
set -euo pipefail

# Chezmoi scripts do not load the interactive shell configuration.
export PROTO_HOME="$HOME/.proto"
export NPM_CONFIG_PREFIX="$PROTO_HOME/tools/node/globals"
export PATH="$HOME/.local/bin:$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"

if [[ ! -x "$HOME/.local/bin/claude" ]]; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# pi installs through npm and needs Node.js. reconcile-dev-tools installs it
# too but sorts after this script, and without Node the pi installer downloads
# a standalone copy that proto does not own.
if [[ ! -x "$NPM_CONFIG_PREFIX/bin/pi" ]]; then
  echo "Installing pi..."
  /opt/homebrew/bin/proto install node --config-mode global
  curl -fsSL https://pi.dev/install.sh | sh
fi
