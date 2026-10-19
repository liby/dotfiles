#!/bin/zsh
set -euo pipefail

[[ -x "$HOME/.local/bin/pi" ]] || {
  print -u2 "Pi must be installed before its extension package."
  exit 1
}

"$HOME/.local/bin/pi" install git:github.com/Entwining/pi-extensions
