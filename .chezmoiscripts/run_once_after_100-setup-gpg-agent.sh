#!/bin/zsh
set -euo pipefail

if ! command -v gpg &>/dev/null || ! command -v gpgconf &>/dev/null; then
  exit 0
fi

mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
for f in "$HOME/.gnupg"/*(.N); do
  chmod 600 "$f"
done

gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
[[ ! -f "$gpg_agent_conf" ]] && touch "$gpg_agent_conf"

if command -v pinentry-mac &>/dev/null; then
  if ! grep -q "pinentry-program" "$gpg_agent_conf"; then
    echo "pinentry-program $(command -v pinentry-mac)" >> "$gpg_agent_conf"
  fi
fi

gpgconf --launch gpg-agent
gpgconf --reload gpg-agent

if gpg --card-status &>/dev/null; then
  echo "Fetching GPG keys from Yubikey..."
  echo "fetch" | gpg --command-fd 0 --status-fd 1 --card-edit &>/dev/null || true
fi
