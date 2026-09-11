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

# Changing a run_once script gives it a new identity. Avoid moving an existing
# channel-based install merely because this bootstrap script was maintained.
# Match executables, not version directories: `shared-globals-dir` puts npm's global prefix at
# `tools/node/globals`. pnpm 12 moved its executable from `shims/pnpm` to the tool root.
node_bins=("$HOME"/.proto/tools/node/*/bin/node(N))
pnpm_bins=("$HOME"/.proto/tools/pnpm/*/pnpm(N) "$HOME"/.proto/tools/pnpm/*/shims/pnpm(N))
(( ${#node_bins} )) || "$proto_bin" install node
(( ${#pnpm_bins} )) || "$proto_bin" install pnpm
