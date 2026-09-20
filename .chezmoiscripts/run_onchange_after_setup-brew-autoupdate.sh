#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

autoupdate_label="com.liby.brew-autoupdate"
autoupdate_gui_domain="gui/$UID"
autoupdate_service="$autoupdate_gui_domain/$autoupdate_label"
autoupdate_plist="$HOME/Library/LaunchAgents/$autoupdate_label.plist"
autoupdate_helper_dir="$HOME/Library/Application Support/$autoupdate_label"
autoupdate_helper="$autoupdate_helper_dir/brew-autoupdate"

echo "Setting up brew autoupdate (10:00 daily and at load)..."
# A fresh macOS account may lack any of these; launchd creates a missing log file but not its
# directory.
mkdir -p "$HOME/Library/LaunchAgents" "$autoupdate_helper_dir" "$HOME/Library/Logs"

# Login Items names a legacy job by the basename of the file launchd runs, so the commands live in
# their own file, and the helper sets its own PATH because launchd gives it a minimal environment.
# The steps are deliberately not chained, so a failure neither skips the rest nor goes unreported.
# pi has no Homebrew channel and never updates itself, so the helper also runs `pi update --self`;
# that step needs the proto environment on PATH to find Node and install into the proto prefix.
# Codex is a binary-only cask, so unlike an app bundle it gets no upgrade-time approval and each
# executable it ships prompts Gatekeeper after Homebrew's reinstall; no other cask this job upgrades needs it.
cat > "$autoupdate_helper" <<'HELPER'
#!/bin/sh
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PROTO_HOME="$HOME/.proto"
export NPM_CONFIG_PREFIX="$PROTO_HOME/tools/node/globals"
export PATH="$PROTO_HOME/shims:$PROTO_HOME/bin:$NPM_CONFIG_PREFIX/bin:$PATH"

status=0
date
brew update || status=$?
brew upgrade --no-ask || status=$?
xattr -dr com.apple.quarantine /opt/homebrew/Caskroom/codex || status=$?
"$NPM_CONFIG_PREFIX/bin/pi" update --self || status=$?
brew cleanup || status=$?
exit "$status"
HELPER
chmod +x "$autoupdate_helper"

# The background keys keep a daily upgrade off the foreground's I/O.
cat > "$autoupdate_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$autoupdate_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$autoupdate_helper</string>
    </array>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>LowPriorityBackgroundIO</key>
    <true/>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/$autoupdate_label.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/$autoupdate_label.log</string>
</dict>
</plist>
EOF

# The job keeps running with the options it was loaded with, so replace it whenever this
# script's content changes.
if launchctl print "$autoupdate_service" >/dev/null 2>&1; then
  launchctl bootout "$autoupdate_service"
fi
launchctl bootstrap "$autoupdate_gui_domain" "$autoupdate_plist"

# A gui domain in on-demand-only mode accepts the bootstrap without loading the job.
launchctl print "$autoupdate_service" >/dev/null 2>&1 || {
  print -u2 "Homebrew autoupdate was written to $autoupdate_plist but launchd did not load it"
  exit 1
}
