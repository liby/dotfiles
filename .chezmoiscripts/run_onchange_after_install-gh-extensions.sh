#!/bin/zsh
set -euo pipefail

source "$CHEZMOI_SOURCE_DIR/.chezmoiscripts/.lib/step.zsh"

step /opt/homebrew/bin/gh extension install github/gh-stack
step /opt/homebrew/bin/gh extension install github/gh-actions-lock
