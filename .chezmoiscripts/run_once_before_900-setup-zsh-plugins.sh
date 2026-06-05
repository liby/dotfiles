#!/bin/zsh
set -euo pipefail

ZSH_PLUGINS_PREFIX="$HOME/.zsh/plugins"
mkdir -p "$ZSH_PLUGINS_PREFIX"

plugins=(
  "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
  "zsh-completions     https://github.com/zsh-users/zsh-completions"
  "fsh                 https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
)

for entry in "${plugins[@]}"; do
  name=${entry%% *}
  url=${entry##* }
  [[ -d "$ZSH_PLUGINS_PREFIX/$name" ]] || git clone "$url" "$ZSH_PLUGINS_PREFIX/$name"
done
