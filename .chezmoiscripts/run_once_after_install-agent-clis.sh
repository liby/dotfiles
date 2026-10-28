#!/bin/zsh
set -euo pipefail

source "$CHEZMOI_SOURCE_DIR/.chezmoiscripts/.lib/step.zsh"

if [[ ! -x "$HOME/.local/bin/claude" ]]; then
  step /bin/bash -o pipefail -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

# Pi installs through the pi.dev installer into a managed install and needs
# Node.js. reconcile-dev-tools installs it too but sorts after this script, and
# without Node the Pi installer downloads a standalone copy that proto does not own.
# The installer exits 0 when its prompt is declined; failing then keeps run_once from
# recording Pi as installed.
if [[ ! -x "$HOME/.local/bin/pi" ]]; then
  step /opt/homebrew/bin/proto install node --config-mode global
  curl -fsSL https://pi.dev/install.sh | sh
  [[ -x "$HOME/.local/bin/pi" ]] || {
    print -u2 -r -- "$step_red✗$step_reset The Pi installer exited without installing Pi; rerun chezmoi apply to install it"
    exit 1
  }
fi
