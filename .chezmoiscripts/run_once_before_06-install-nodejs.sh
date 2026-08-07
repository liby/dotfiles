#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

eval "$(/opt/homebrew/bin/brew shellenv)"

command -v proto &>/dev/null || {
  print -u2 "Required Brewfile dependency not found: proto"
  exit 1
}

# Changing a run_once script gives it a new identity. Avoid moving an existing
# channel-based install merely because this bootstrap script was maintained.
node_bins=("$HOME"/.proto/tools/node/*/bin/node(N))
pnpm_bins=("$HOME"/.proto/tools/pnpm/*/shims/pnpm(N))
(( ${#node_bins} )) || proto install node
(( ${#pnpm_bins} )) || proto install pnpm
