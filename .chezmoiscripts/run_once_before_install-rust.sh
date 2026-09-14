#!/bin/zsh
set -euo pipefail

if ! command -v rustc &>/dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi

# Claude Code's rust-analyzer-lsp plugin requires the separate rustup component.
# Install it independently of rustc; rustup component add is idempotent.
rustup component add rust-analyzer
