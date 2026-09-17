#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

autoupdate_label="com.liby.brew-autoupdate"
autoupdate_gui_domain="gui/$UID"
autoupdate_service="$autoupdate_gui_domain/$autoupdate_label"
autoupdate_plist="$HOME/Library/LaunchAgents/$autoupdate_label.plist"

echo "Setting up brew autoupdate (10:00 daily and at load, with upgrade + cleanup)..."
# A fresh macOS account has no LaunchAgents directory until something writes a job into it.
mkdir -p "$HOME/Library/LaunchAgents"
# launchd starts the job with a minimal environment, so it finds `brew` only through the
# explicit PATH below. The background keys keep a daily upgrade off the foreground's I/O.
cat > "$autoupdate_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$autoupdate_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>date; brew update &amp;&amp; brew upgrade --no-ask --formula &amp;&amp; brew upgrade --no-ask --cask &amp;&amp; brew cleanup</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
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
