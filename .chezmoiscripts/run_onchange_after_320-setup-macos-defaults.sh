#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0

defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

defaults write com.apple.menuextra.clock DateFormat -string "EEE HH:mm"

killall Dock Finder SystemUIServer 2>/dev/null || true
