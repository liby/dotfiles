#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

xcode-select -p &>/dev/null && exit 0

echo "Installing Xcode CLI Tools..."
xcode-select --install

# xcode-select --install is async (opens a GUI dialog)
echo "Press Enter after Xcode Command Line Tools installation is complete."
read -r
