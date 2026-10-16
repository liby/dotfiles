#!/bin/zsh
set -euo pipefail

export PROTO_HOME="$HOME/.proto"
export PATH="$HOME/.local/bin:$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"

[[ -x "$HOME/.local/bin/pi" ]] || {
  print -u2 "Pi must be installed before its extension package."
  exit 1
}

"$HOME/.local/bin/pi" install git:github.com/Entwining/pi-extensions
