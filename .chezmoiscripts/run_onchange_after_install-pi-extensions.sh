#!/bin/zsh
set -euo pipefail

source "$CHEZMOI_SOURCE_DIR/.chezmoiscripts/.lib/step.zsh"

[[ -x "$HOME/.local/bin/pi" ]] || {
  print -u2 -r -- "$step_red✗$step_reset Pi is not installed, so its extension package was not installed; rerun chezmoi apply"
  exit 1
}

step "$HOME/.local/bin/pi" install git:github.com/Entwining/pi-extensions
