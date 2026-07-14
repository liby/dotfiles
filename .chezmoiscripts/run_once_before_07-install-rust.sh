#!/bin/zsh
set -euo pipefail

if ! command -v rustc &>/dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi

# rust-analyzer: LSP server spawned by Claude Code's rust-analyzer-lsp plugin.
# It ships as a rustup component, not bundled by the plugin. This runs
# unconditionally (rustup component add is idempotent) so it also backfills
# machines where Rust predates this line; the previous `exit 0` skipped them.
rustup component add rust-analyzer
