#!/bin/zsh
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || exit 0

brew_prefix="/opt/homebrew"

gpg_bin="$brew_prefix/bin/gpg"
gpgconf_bin="$brew_prefix/bin/gpgconf"
pinentry_bin="$brew_prefix/bin/pinentry-mac"
for executable in "$gpg_bin" "$gpgconf_bin" "$pinentry_bin"; do
  [[ -x "$executable" ]] || {
    print -u2 "Error: required GPG executable not found: $executable"
    exit 1
  }
done

mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
for f in "$HOME/.gnupg"/*(.N); do
  chmod 600 "$f"
done

gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
[[ ! -f "$gpg_agent_conf" ]] && touch "$gpg_agent_conf"

if ! grep -q "pinentry-program" "$gpg_agent_conf"; then
  echo "pinentry-program $pinentry_bin" >> "$gpg_agent_conf"
fi

"$gpgconf_bin" --launch gpg-agent
"$gpgconf_bin" --reload gpg-agent

card_status=$("$gpg_bin" --card-status 2>/dev/null) || {
  print -u2 "Error: YubiKey not available; insert it and retry"
  exit 1
}

if ! /usr/bin/grep -q '^sec' <<< "$card_status"; then
  echo "Fetching GPG keys from YubiKey..."
  print -r -- fetch |
    "$gpg_bin" --command-fd 0 --status-fd 1 --card-edit &>/dev/null || {
      print -u2 "Error: unable to fetch the public key from the YubiKey"
      exit 1
    }
  card_status=$("$gpg_bin" --card-status 2>/dev/null) || {
    print -u2 "Error: unable to refresh the YubiKey after fetching its public key"
    exit 1
  }
  /usr/bin/grep -q '^sec' <<< "$card_status" || {
    print -u2 "Error: the YubiKey public key is still unavailable after fetching"
    exit 1
  }
fi
