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

mkdir -p "$HOME/.npm-global"/{lib,bin}

# Global npm packages must land in the prefix the interactive shell uses
# (NPM_CONFIG_PREFIX in dot_zshrc), and proto's shims must be on PATH so `npm`
# resolves during a fresh init before the shell is reloaded.
export PATH="$HOME/.proto/shims:$HOME/.npm-global/bin:$PATH"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

# npm 11 warns on global install scripts not on this allow-list (and will block them
# in a future release). Keep it to what our global CLIs pull in; extend as needed.
npm config set --location=global "allow-scripts=@google/genai,protobufjs"

# typescript-language-server: LSP server spawned by Claude Code's typescript-lsp
# plugin, which does not bundle it. typescript provides tsserver as a fallback for
# projects without a local TypeScript install.
# @steipete/oracle: second-model review CLI (oracle / oracle-mcp) used by the oracle skill.
npm install -g typescript-language-server typescript @steipete/oracle
