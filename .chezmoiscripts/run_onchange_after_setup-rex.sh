#!/bin/zsh
set -euo pipefail

# The app reads these at launch. They are written without quitting it, because chezmoi apply
# usually runs in one of its panes.
domain=com.superlogical.rex
defaults write $domain Workspace.appIcon -string dark
defaults write $domain Workspace.appIconVisibility -string dockOnly
defaults write $domain Workspace.appearance -string dark
defaults write $domain Workspace.hiddenChromeButtons -array commandPalette newTab
defaults write $domain Workspace.inactivePaneFadeMode -string text
defaults write $domain Workspace.interfaceStyle -string useTheme
defaults write $domain Workspace.paneDensity -string compact
defaults write $domain Workspace.playsProgramActivitySounds -bool false
defaults write $domain Workspace.showsPaneHeaders -bool true
defaults write $domain Workspace.showsProgramActivityDockBadge -bool false
defaults write $domain Workspace.sidebarPosition -string left
defaults write $domain Workspace.tabIconColorMode -string activePanes
defaults write $domain Workspace.tabStyle -string vertical
# Keep the pre-3.201 35 px cell at 12 pt on 2x displays; re-tune for other fonts, sizes, or scales.
defaults write $domain Workspace.terminalCellHeightPercent -float 30
defaults write $domain Workspace.terminalCopyAnimation -bool false
defaults write $domain Workspace.terminalCursorBlinkIntervalMilliseconds -int 0
defaults write $domain Workspace.terminalCursorBlinkUsesCustomInterval -bool false
defaults write $domain Workspace.terminalFallbackFontNames -array "PingFang SC"
defaults write $domain Workspace.terminalFontName -string "Inconsolata LGC Nerd Font Mono"
defaults write $domain Workspace.terminalFontPointSize -float 12
# Preserve the distinction between intentionally muted RGB text colors.
defaults write $domain Workspace.terminalImproveTextContrast -bool false
defaults write $domain Workspace.terminalOptionKeyBehavior -string actsAsAlt
defaults write $domain Workspace.terminalPaddingColor -string background
defaults write $domain Workspace.terminalSelectionRoundedCorners -bool false
defaults write $domain Workspace.terminalUsesDisplayP3 -bool true
defaults write $domain Workspace.usesStandardInactiveWindowPaneStyles -bool false
defaults write $domain rex.client.remoteControl -bool true

if pgrep -qf '/Rex Beta.app/Contents/MacOS/Rex'; then
  print "Reopen the Rex app to apply its preferences; leave Rex Server running."
fi
