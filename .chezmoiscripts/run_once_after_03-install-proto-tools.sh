#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

eval "$(/opt/homebrew/bin/brew shellenv)"

# Not `command -v proto`: with Brewfile's proto installed both resolve the same binary, but a
# lookup falls back to the self-managed proto in `$PROTO_HOME/bin` instead of failing.
proto_bin=/opt/homebrew/bin/proto

[[ -x "$proto_bin" ]] || {
  print -u2 "Required Brewfile dependency not found: proto"
  exit 1
}

# Chezmoi scripts do not load the interactive shell configuration, and the npm plugin resolves
# its bundled version by executing `node` from the shims.
export PATH="$HOME/.proto/shims:$PATH"

# Tool declarations live in `~/.proto/.prototools`. The default `upwards` config mode walks up
# from the working directory without merging that file, leaving a bare `proto install` nothing
# to install. proto skips each declared version it already has.
"$proto_bin" install --config-mode global
