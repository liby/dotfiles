#!/bin/zsh
set -euo pipefail

command -v rustc &>/dev/null && exit 0

echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
