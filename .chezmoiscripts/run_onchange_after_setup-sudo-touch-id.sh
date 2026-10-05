#!/bin/zsh
set -euo pipefail

# macOS updates replace /etc/pam.d/sudo but keep sudo_local, which it includes.
target=/etc/pam.d/sudo_local
if ! grep -Eqs '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so([[:space:]]|$)' "$target"; then
  printf '\nauth       sufficient     pam_tid.so\n' | sudo tee -a "$target" >/dev/null
fi
