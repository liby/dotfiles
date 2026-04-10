#!/bin/zsh
set -euo pipefail

rm -f "$HOME/.zcompdump"*(N)
autoload -Uz compinit && compinit -i
