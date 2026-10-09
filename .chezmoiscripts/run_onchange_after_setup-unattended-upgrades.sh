#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

upgrades_label="com.liby.unattended-upgrades"
upgrades_gui_domain="gui/$UID"
upgrades_service="$upgrades_gui_domain/$upgrades_label"
upgrades_plist="$HOME/Library/LaunchAgents/$upgrades_label.plist"
upgrades_helper_dir="$HOME/Library/Application Support/$upgrades_label"
upgrades_helper="$upgrades_helper_dir/unattended-upgrades"

echo "Setting up unattended upgrades (every 6 hours and at load)..."
# A fresh macOS account may lack any of these; launchd creates a missing log file but not its
# directory.
mkdir -p "$HOME/Library/LaunchAgents" "$upgrades_helper_dir" "$HOME/Library/Logs"

# Login Items names a legacy job by the basename of the file launchd runs, so the commands live in
# their own file, and the helper sets its own PATH because launchd gives it a minimal environment.
# The steps are deliberately not chained, so a failure neither skips the rest nor goes unreported.
# Pi has no Homebrew channel and never updates itself, so the helper also runs `pi update`;
# the managed install lives in ~/.pi/agent/install and its launcher needs Node on PATH.
# rustup likewise never updates the toolchains it installed, so the helper runs `rustup update`.
cat > "$upgrades_helper" <<'HELPER'
#!/bin/sh
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PROTO_HOME="$HOME/.proto"
export PATH="$HOME/.local/bin:$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"

status=0
date
brew update || status=$?
brew upgrade --no-ask || status=$?
# Approval of the CLI does not cover its helper executables or carry over on upgrade.
if [ -d /opt/homebrew/Caskroom/codex ]; then
  xattr -dr com.apple.quarantine /opt/homebrew/Caskroom/codex
fi || status=$?
# gpg-agent and keyboxd keep the pre-upgrade binary and libraries mapped, and
# no-autostart stops clients from starting replacements, so restart them here;
# the chezmoi GPG script only reruns on a later apply. Check both daemons, or a
# keyboxd left down by a partial restart is skipped on the next run; skip only
# when both already match, so an unrelated upgrade does not clear the PIN cache.
installed=$(/opt/homebrew/bin/gpg --version 2>/dev/null | /usr/bin/awk 'NR == 1 { print $NF }')
agent_version=$(/opt/homebrew/bin/gpg-connect-agent --no-autostart 'getinfo version' /bye 2>/dev/null | /usr/bin/awk '$1 == "D" { print $2; exit }')
keyboxd_version=$(/opt/homebrew/bin/gpg-connect-agent --keyboxd --no-autostart 'getinfo version' /bye 2>/dev/null | /usr/bin/awk '$1 == "D" { print $2; exit }')
if [ "$installed" != "$agent_version" ] || [ "$installed" != "$keyboxd_version" ]; then
  /opt/homebrew/bin/gpgconf --kill gpg-agent || status=$?
  /opt/homebrew/bin/gpgconf --kill keyboxd || status=$?
  /bin/launchctl kickstart "gui/$UID/org.gnupg.gpg-agent" || status=$?
  /bin/launchctl kickstart "gui/$UID/org.gnupg.keyboxd" || status=$?
fi
pi update || status=$?
"$HOME/.cargo/bin/rustup" update || status=$?
brew cleanup || status=$?
exit "$status"
HELPER
chmod +x "$upgrades_helper"

# The background keys keep the periodic upgrade off the foreground's I/O.
cat > "$upgrades_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$upgrades_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$upgrades_helper</string>
    </array>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>LowPriorityBackgroundIO</key>
    <true/>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>2</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>8</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>14</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>20</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/$upgrades_label.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/$upgrades_label.log</string>
</dict>
</plist>
EOF

# The job keeps running with the options it was loaded with, so replace it whenever this
# script's content changes.
if launchctl print "$upgrades_service" >/dev/null 2>&1; then
  launchctl bootout "$upgrades_service"
fi
launchctl bootstrap "$upgrades_gui_domain" "$upgrades_plist"

# A gui domain in on-demand-only mode accepts the bootstrap without loading the job.
launchctl print "$upgrades_service" >/dev/null 2>&1 || {
  print -u2 "Unattended upgrades were written to $upgrades_plist but launchd did not load it"
  exit 1
}
