#!/bin/zsh
set -euo pipefail

source "$CHEZMOI_SOURCE_DIR/.chezmoiscripts/.lib/step.zsh"

[[ -x "$HOME/.local/bin/pi" ]] || {
  print -u2 "Pi must be installed before its extension package."
  exit 1
}

step "$HOME/.local/bin/pi" install git:github.com/Entwining/pi-extensions
