#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

if command -v brew &>/dev/null; then
  echo "Homebrew already installed, updating..."
  brew update
  exit 0
fi

echo "Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/opt/homebrew/bin/brew shellenv)"

# Homebrew installer doesn't always set up .zprofile
zprofile="$HOME/.zprofile"
if [[ ! -e "$zprofile" ]] || ! grep -q "brew shellenv" "$zprofile"; then
  echo 'eval "$('${HOMEBREW_PREFIX}'/bin/brew shellenv)"' >> "$zprofile"
  echo "typeset -U path" >> "$zprofile"
fi

brew analytics off
brew update
