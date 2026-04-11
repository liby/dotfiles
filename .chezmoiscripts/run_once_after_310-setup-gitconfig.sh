#!/bin/zsh
set -euo pipefail

git_config_dir="$HOME/.config/git"
github_config_tpl="$git_config_dir/github.config.tpl"
gitlab_config_tpl="$git_config_dir/gitlab.config.tpl"
credentials_file="$git_config_dir/gitlab.user"
ssh_dir="$HOME/.ssh"

mkdir -p "$ssh_dir"

if [[ ! -f "$credentials_file" ]]; then
  echo "Credentials file not found: $credentials_file"
  exit 1
fi

GITLAB_EMAIL=$(git config --file "$credentials_file" user.email)
GITLAB_NAME=$(git config --file "$credentials_file" user.name)

if [[ -z "${GITLAB_EMAIL:-}" || -z "${GITLAB_NAME:-}" ]]; then
  echo "Invalid credentials file. Need user.email and user.name."
  exit 1
fi

gpg_key_id=""
gpg_ssh_pub_key_file=""

if command -v gpg &>/dev/null; then
  gpg_key_id=$(gpg --card-status 2>/dev/null | grep '^sec' | head -1 | awk '{print $2}' | cut -d'/' -f2)

  if [[ -n "$gpg_key_id" ]]; then
    gpg_ssh_pub_key_file="$ssh_dir/$gpg_key_id.pub"
    echo "Exporting GPG key $gpg_key_id as SSH key..."
    gpg --export-ssh-key "$gpg_key_id" > "$gpg_ssh_pub_key_file"
  fi
fi

if [[ ! -f "$github_config_tpl" || ! -f "$gitlab_config_tpl" ]]; then
  echo "Template files not found: $github_config_tpl, $gitlab_config_tpl"
  exit 1
fi

sed "s|@SIGNINGKEY@|$gpg_key_id|" "$github_config_tpl" > "$git_config_dir/github.config"

sed -e "s|@GITLAB_EMAIL@|$GITLAB_EMAIL|" \
    -e "s|@GITLAB_NAME@|$GITLAB_NAME|" \
    -e "s|@SIGNINGKEY@|$gpg_ssh_pub_key_file|" \
    "$gitlab_config_tpl" > "$git_config_dir/gitlab.config"

if [[ -n "$gpg_key_id" && -n "$gpg_ssh_pub_key_file" ]]; then
  allowed_signers_file="$ssh_dir/allowed_signers"
  if ! grep -q "$GITLAB_EMAIL" "$allowed_signers_file" 2>/dev/null; then
    echo "$GITLAB_EMAIL namespaces=\"git\" $(< "$gpg_ssh_pub_key_file")" >> "$allowed_signers_file"
  fi
fi
