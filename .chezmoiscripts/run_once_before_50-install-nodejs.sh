#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

if [[ "$(uname -m)" == "arm64" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

# proto needs xz to unpack Node.js archives
command -v xz &>/dev/null || brew install xz

if ! command -v proto &>/dev/null; then
  echo "Installing proto..."
  curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --no-profile --yes
  export PATH="$HOME/.proto/bin:$PATH"
fi

proto install node
proto install pnpm
