#!/bin/zsh
set -euo pipefail

# Chezmoi scripts do not load the interactive shell configuration.
export PROTO_HOME="$HOME/.proto"
export PATH="$HOME/.local/bin:$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"

if [[ ! -x "$HOME/.local/bin/claude" ]]; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Pi installs through the pi.dev installer into a managed install and needs
# Node.js. reconcile-dev-tools installs it too but sorts after this script, and
# without Node the Pi installer downloads a standalone copy that proto does not own.
# The installer exits 0 when its prompt is declined; failing then keeps run_once from
# recording Pi as installed.
if [[ ! -x "$HOME/.local/bin/pi" ]]; then
  echo "Installing Pi..."
  /opt/homebrew/bin/proto install node --config-mode global
  curl -fsSL https://pi.dev/install.sh | sh
  [[ -x "$HOME/.local/bin/pi" ]] || {
    print -u2 "Pi is not installed, so chezmoi apply stopped here; run it again to install Pi."
    exit 1
  }
fi
