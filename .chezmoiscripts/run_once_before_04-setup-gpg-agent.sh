#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

brew_prefix="/opt/homebrew"

gpg_bin="$brew_prefix/bin/gpg"
gpgconf_bin="$brew_prefix/bin/gpgconf"
pinentry_bin="$brew_prefix/bin/pinentry-mac"

mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
for f in "$HOME/.gnupg"/*(.N); do
  chmod 600 "$f"
done

append_config_line() {
  local file=$1 line=$2
  # A hand-edited file may end without a newline; appending would glue the
  # option onto the last line, where the `grep "^option"` guards never see it.
  if [[ -s "$file" ]] && ! tail -c1 "$file" | read -r _; then
    echo >> "$file"
  fi
  print -r -- "$line" >> "$file"
}

gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
[[ ! -f "$gpg_agent_conf" ]] && touch "$gpg_agent_conf"

if ! grep -q "^pinentry-program" "$gpg_agent_conf"; then
  append_config_line "$gpg_agent_conf" "pinentry-program $pinentry_bin"
fi
# git-ssh-gpg-agent uses S.gpg-agent.ssh, which exists only with ssh support.
if ! grep -q "^enable-ssh-support" "$gpg_agent_conf"; then
  append_config_line "$gpg_agent_conf" "enable-ssh-support"
fi

# no-autostart: daemons come only from the launchd jobs below (CONCEPTS.md, Bootstrap).
common_conf="$HOME/.gnupg/common.conf"
[[ ! -f "$common_conf" ]] && touch "$common_conf"
# use-keyboxd ignores an existing pubring.kbx, so never switch a populated
# legacy homedir.
if [[ ! -f "$HOME/.gnupg/pubring.kbx" ]] && ! grep -q "^use-keyboxd" "$common_conf"; then
  append_config_line "$common_conf" "use-keyboxd"
fi
if ! grep -q "^no-autostart" "$common_conf"; then
  append_config_line "$common_conf" "no-autostart"
fi

# Both daemons fork and the launched process exits: AbandonProcessGroup keeps
# the child, KeepAlive would loop on the held socket.
typeset -A daemons=(
  gpg-agent "$brew_prefix/bin/gpg-agent"
  keyboxd "$brew_prefix/opt/gnupg/libexec/keyboxd"
)
launch_agents_dir="$HOME/Library/LaunchAgents"
mkdir -p "$launch_agents_dir"
for component program in "${(kv)daemons[@]}"; do
  label="org.gnupg.$component"
  service="gui/$UID/$label"
  plist="$launch_agents_dir/$label.plist"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$program</string>
        <string>--daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>AbandonProcessGroup</key>
    <true/>
</dict>
</plist>
EOF
  if launchctl print "$service" >/dev/null 2>&1; then
    launchctl bootout "$service"
  fi
  # bootout reaps only the exited parent; the daemon holding the socket must
  # stop before the new instance starts.
  "$gpgconf_bin" --kill "$component"
  launchctl bootstrap "gui/$UID" "$plist"
done

# bootstrap returns before RunAtLoad spawns anything; the card commands below
# need both sockets.
for _ in {1..50}; do
  ready=1
  for daemon_flag in "" --keyboxd; do
    "$brew_prefix/bin/gpg-connect-agent" $daemon_flag --no-autostart 'getinfo pid' /bye 2>/dev/null | grep -q '^D ' || ready=0
  done
  (( ready )) && break
  sleep 0.2
done
(( ready )) || {
  print -u2 "Error: gpg-agent or keyboxd did not start; check launchctl print gui/$UID/org.gnupg.gpg-agent and gui/$UID/org.gnupg.keyboxd"
  exit 1
}

card_status=$("$gpg_bin" --card-status) || {
  print -u2 "Error: YubiKey not available; insert it and retry"
  exit 1
}

if ! /usr/bin/grep -q '^sec' <<< "$card_status"; then
  # The card's own fetch command needs dirmngr, which no-autostart blocks.
  key_url=$(/usr/bin/awk -F': ' '/^URL of public key/ { print $2 }' <<< "$card_status")
  echo "Importing the public key from $key_url..."
  /usr/bin/curl -fsSL "$key_url" | "$gpg_bin" --batch --import || {
    print -u2 "Error: unable to import the public key from $key_url"
    exit 1
  }
  card_status=$("$gpg_bin" --card-status) || {
    print -u2 "Error: unable to refresh the YubiKey after importing its public key"
    exit 1
  }
  /usr/bin/grep -q '^sec' <<< "$card_status" || {
    print -u2 "Error: the imported key does not match the YubiKey"
    exit 1
  }
fi
