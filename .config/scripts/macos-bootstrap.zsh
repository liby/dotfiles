#!/bin/zsh

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "No macOS detected!"
  exit 1
fi

is_apple_silicon() {
  [[ "$(/usr/bin/uname -m)" == "arm64" ]]
}

start() {
  clear

  echo "==========================================================="
  echo "                                                           "
  echo "▀█████████▄     ▄████████ ▄██   ▄      ▄████████ ███▄▄▄▄   "
  echo "  ███    ███   ███    ███ ███   ██▄   ███    ███ ███▀▀▀██▄ "
  echo "  ███    ███   ███    ███ ███▄▄▄███   ███    ███ ███   ███ "
  echo " ▄███▄▄▄██▀   ▄███▄▄▄▄██▀ ▀▀▀▀▀▀███   ███    ███ ███   ███ "
  echo "▀▀███▀▀▀██▄  ▀▀███▀▀▀▀▀   ▄██   ███ ▀███████████ ███   ███ "
  echo "  ███    ██▄ ▀███████████ ███   ███   ███    ███ ███   ███ "
  echo "  ███    ███   ███    ███ ███   ███   ███    ███ ███   ███ "
  echo "▄█████████▀    ███    ███  ▀█████▀    ███    █▀   ▀█   █▀  "
  echo "               ███    ███                                  "
  echo "                                                           "
  echo "==========================================================="
  echo "                      !! ATTENTION !!                      "
  echo "       YOU ARE SETTING UP: Bryan Environment (macOS)       "
  echo "==========================================================="
  echo "                                                           "
  echo "          * The setup will begin in 3 seconds...           "

  sleep 3

  echo "                 Times up! Here we start!                  "
  echo "-----------------------------------------------------------"

  cd $HOME
}

check_install_xcode_tools() {
  echo "==========================================================="
  echo "          Checking/Installing Xcode Command Tools          "
  echo "-----------------------------------------------------------"
  if ! xcode-select -p > /dev/null 2>&1; then
    echo "Xcode Command Line Tools not found. Attempting to install..."
    echo "Please follow the on-screen instructions to install the tools."
    # This command opens a GUI prompt if tools are not installed
    xcode-select --install
    # Wait for user to install - this might need manual intervention or a loop check
    echo "Please press Enter after Xcode Command Line Tools installation is complete."
    read -r
    # Re-check
    if ! xcode-select -p > /dev/null 2>&1; then
      echo "Xcode Command Line Tools installation failed or was cancelled. Exiting."
      exit 1
    fi
    echo "Xcode Command Line Tools installed successfully."
  else
    echo "Xcode Command Line Tools already installed."
  fi

  # Ensure the license is accepted regardless of the installation path
  echo "Attempting to accept Xcode license automatically..."
  sudo xcodebuild -license accept || echo "Failed to accept Xcode license, or it was already accepted."
}

setup_brew_env() {
  # It will export env variable: HOMEBREW_PREFIX, HOMEBREW_CELLAR, HOMEBREW_REPOSITORY, HOMEBREW_SHELLENV_PREFIX
  # It will add path: $PATH, $MANPATH, $INFOPATH
  if is_apple_silicon; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_homebrew() {
  echo "==========================================================="
  echo "                     Install Homebrew                      "
  echo "-----------------------------------------------------------"

  if [ -x "$(command -v brew)" ]; then
    echo "Homebrew already installed, updating..."
    brew update || {
      echo "Failed to update Homebrew"
      return 1
    }
    return 0
  fi

  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    echo "Failed to install Homebrew"
    return 1
  }

  setup_brew_env || return 1

  local zprofile="$HOME/.zprofile"
  if ! ([[ -e "$zprofile" ]] && grep -q "brew shellenv" "$zprofile"); then
    echo "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\"" >> "$zprofile"
    echo "typeset -U path" >> "$zprofile"
  fi

  brew analytics off && brew update || {
    echo "Failed to configure Homebrew"
    return 1
  }

  echo "Homebrew installed successfully."
}

restore_dotfiles() {
  echo "==========================================================="
  echo "         Restore Bryan’s dotfiles from GitHub.com          "
  echo "-----------------------------------------------------------"

  if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is not installed. Cannot proceed with dotfiles restoration."
    return 1
  fi

  if [[ -d "$HOME/.dotfiles" ]]; then
    echo "Dotfiles directory already exists, attempting to update..."
    if git --git-dir=$HOME/.dotfiles --work-tree=$HOME pull --ff-only; then
      echo "Dotfiles updated successfully."
      # Re-checkout might be needed if there were local changes conflicting
      git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout --force
    else
      echo "Failed to update dotfiles. Continuing with existing ones..."
      # Decide if you want to force checkout anyway or handle conflicts
      git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout --force
    fi
  else
    echo "Cloning dotfiles..."
    if git clone --bare https://github.com/liby/dotfiles.git $HOME/.dotfiles; then
      git --git-dir=$HOME/.dotfiles --work-tree=$HOME config --local status.showUntrackedFiles no
      if ! git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout --force; then
        echo "Error: Failed to checkout dotfiles. Exiting."
        return 1 # Use return 1 instead of exit 1 if called from main script
      fi
      echo "Dotfiles cloned and checked out successfully."
    else
      echo "Error: Failed to clone dotfiles repository. Exiting."
      return 1
    fi
  fi
  # Set remote URL (consider if this should be conditional)
  git --git-dir=$HOME/.dotfiles --work-tree=$HOME remote set-url origin git@github.com:liby/dotfiles.git
  echo "Dotfiles setup complete."
}

install_homebrew_packages() {
  echo "==========================================================="
  echo "           Installing packages from Brewfile...            "
  echo "-----------------------------------------------------------"

  local brewfile="$HOME/Brewfile"

  if [[ ! -f "$brewfile" ]]; then
    echo "No Brewfile found at $brewfile"
    echo "Skipping package installation"
    return 0
  fi

  # Save current locale setting
  local current_locale=$(defaults read NSGlobalDomain AppleLocale 2>/dev/null || echo en_CN)

  # Store brew bundle exit status
  local brew_bundle_status

  # Temporarily set locale to en_US for mas-cli compatibility
  # Reference:https://github.com/mas-cli/mas/blob/ed676787f0a0a26e23a10548eb841bc15411fa52/Sources/mas/Controllers/ITunesSearchAppStoreSearcher.swift#L18-L23
  defaults write NSGlobalDomain AppleLocale -string en_US

  # Run brew bundle
  if brew bundle --file="$brewfile"; then
    echo "Successfully installed all packages from Brewfile"
    brew_bundle_status=0
  else
    echo "Warning: Some packages failed to install from Brewfile"
    echo "You may want to run 'brew bundle' manually later"
    brew_bundle_status=1
  fi

  # Restore original locale setting
  defaults write NSGlobalDomain AppleLocale -string "$current_locale"

  return $brew_bundle_status
}

setup_zsh_plugins() {
  echo "==========================================================="
  echo "                     Shells Environment                    "
  echo "-----------------------------------------------------------"

  echo "-----------------------------------------------------------"
  echo "             * Installing ZSH Custom Plugins...            "
  echo "                                                           "
  echo "                - zsh-autosuggestions                      "
  echo "                - zsh-completions                          "
  echo "                - fast-syntax-highlighting                 "
  echo "                                                           "
  echo "-----------------------------------------------------------"

  # 确保git命令可用
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is not installed. Cannot proceed with ZSH plugins installation."
    return 1
  fi

  export ZSH_PLUGINS_PREFIX="$HOME/.zsh/plugins"
  [[ ! -d "$ZSH_PLUGINS_PREFIX" ]] && mkdir -p $ZSH_PLUGINS_PREFIX

  if [[ ! -d "${ZSH_PLUGINS_PREFIX}/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_PLUGINS_PREFIX}/zsh-autosuggestions
  fi

  if [[ ! -d "${ZSH_PLUGINS_PREFIX}/zsh-completions" ]]; then
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_PLUGINS_PREFIX}/zsh-completions
  fi

  if [[ ! -d "${ZSH_PLUGINS_PREFIX}/fsh" ]]; then
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_PLUGINS_PREFIX}/fsh
  fi
}

setup_gpg_agent() {
  echo "==========================================================="
  echo "                  Setting up GPG Agent...                  "
  echo "-----------------------------------------------------------"

  if ! command -v gpg >/dev/null 2>&1 || ! command -v gpgconf >/dev/null 2>&1; then
    echo "Error: GPG tools are not installed. Skipping GPG Agent setup."
    return 1
  fi

  if [[ ! -d "$HOME/.gnupg" ]]; then
    echo "Creating $HOME/.gnupg directory..."
    mkdir -p "$HOME/.gnupg"
  fi

  echo "Setting correct permissions for $HOME/.gnupg and its contents..."
  chown -R $(whoami) "$HOME/.gnupg"
  find "$HOME/.gnupg" -type f -exec chmod 600 {} \;
  find "$HOME/.gnupg" -type d -exec chmod 700 {} \;

  local gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
  if [[ -f "$gpg_agent_conf" ]]; then
    echo "$gpg_agent_conf already exists. Checking configuration..."
  else
    echo "$gpg_agent_conf does not exist. Creating and configuring..."
    touch "$gpg_agent_conf"
  fi

  if command -v pinentry-mac >/dev/null 2>&1; then
    if grep -q "pinentry-program" "$gpg_agent_conf"; then
      echo "pinentry-program is already configured in $gpg_agent_conf."
    else
      echo "Configuring pinentry-program in $gpg_agent_conf..."
      echo "pinentry-program $(command -v pinentry-mac)" >> "$gpg_agent_conf"
    fi
  else
    echo "Warning: pinentry-mac not found. Skipping pinentry configuration."
  fi

  echo "Launching gpg-agent if not already running..."
  gpgconf --launch gpg-agent || echo "Failed to launch gpg-agent"

  echo "Reloading gpg-agent configuration..."
  if command -v gpg-connect-agent >/dev/null 2>&1; then
    echo RELOADAGENT | gpg-connect-agent || echo "Failed to reload gpg-agent"
  else
    echo "Warning: gpg-connect-agent not found. Skipping gpg-agent reload."
  fi

  echo "Fetching GPG keys from Yubikey..."
  # Fetch the keys from Yubikey
  if gpg --card-status >/dev/null 2>&1; then
    echo "fetch" | gpg --command-fd 0 --status-fd 1 --card-edit > /dev/null 2>&1 || echo "Failed to fetch keys from Yubikey"
    # Wait for a moment to ensure the keys are fetched
    sleep 3
  else
    echo "Warning: No Yubikey detected or GPG card functionality not working."
  fi

  echo "GPG Agent setup completed."
}

setup_gitconfig() {
  echo "==========================================================="
  echo "                 Setting up git config...                  "
  echo "-----------------------------------------------------------"

  if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is not installed. Cannot proceed with git config setup."
    return 1
  fi

  local git_config_dir="$HOME/.config/git"
  local github_config="$git_config_dir/github.config"
  local gitlab_config="$git_config_dir/gitlab.config"
  local ssh_dir="$HOME/.ssh"

  # Ensure the .ssh directory exists
  [ ! -d "$ssh_dir" ] && mkdir -p "$ssh_dir"

  if [ ! -f "$github_config" ] || [ ! -f "$gitlab_config" ]; then
    echo "Error: github.config or gitlab.config file does not exist."
    return 1
  fi

  # Set GitLab user email and name
  local credentials_file="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/.user-credentials"

  if [[ ! -f "$credentials_file" ]]; then
    echo "User credentials file not found. Please create $credentials_file with the following format:"
    echo "GITLAB_EMAIL='your.email@company.com'"
    echo "GITLAB_NAME='Your Name'"
    return 1
  fi

  source "$credentials_file"

  if [[ -z "$GITLAB_EMAIL" || -z "$GITLAB_NAME" ]]; then
    echo "Invalid credentials file format. Please check $credentials_file"
    return 1
  fi

  git config --file "$gitlab_config" user.email "$GITLAB_EMAIL"
  git config --file "$gitlab_config" user.name "$GITLAB_NAME"

  # Check if GPG key exists and export it
  if command -v gpg >/dev/null 2>&1; then
    local gpg_key_id=$(gpg --card-status 2>/dev/null | grep 'sec' | awk '{print $2}' | cut -d'/' -f2)
    if [[ -n "$gpg_key_id" ]]; then
      local gpg_ssh_pub_key_file="$ssh_dir/$gpg_key_id.pub"

      echo "Exporting GPG key $gpg_key_id as SSH key..."
      gpg --export-ssh-key "$gpg_key_id" > "$gpg_ssh_pub_key_file" || {
        echo "Failed to export GPG SSH key"
        return 0
      }
      echo "GPG SSH Public key exported successfully."

      git config --file "$github_config" user.signingkey "$gpg_key_id"
      git config --file "$gitlab_config" user.signingkey "$gpg_ssh_pub_key_file"

      # Setup SSH signature verification
      local allowed_signers_file="$ssh_dir/allowed_signers"
      if [[ ! -f "$allowed_signers_file" ]]; then
        echo "Creating allowed signers file for SSH signature verification..."
        touch "$allowed_signers_file"
      fi

      echo "Adding user's SSH key to allowed signers file..."
      local ssh_key=$(cat "$gpg_ssh_pub_key_file")

      # Check if entry already exists
      if ! grep -q "$GITLAB_EMAIL" "$allowed_signers_file"; then
        echo "$GITLAB_EMAIL namespaces=\"git\" $ssh_key" > "$allowed_signers_file"
        echo "SSH key added to allowed signers file."
      else
        echo "SSH key already exists in allowed signers file."
      fi
    else
      echo "No GPG key found. Please ensure a GPG key is available."
    fi
  else
    echo "GPG not installed. Skipping GPG key export."
  fi

  echo "Git config setup completed."
}

format_gitconfig_files() {
  echo "==========================================================="
  echo "                  Format git config files                  "
  echo "-----------------------------------------------------------"

  local git_config_dir="$HOME/.config/git"

  if [[ -d "$git_config_dir" ]]; then
    echo "Formatting all files in $git_config_dir..."

    find "$git_config_dir" -type f -name '*config*' | while read -r file; do
      perl -pi -e 's/^\s*\[(.*?)\]/\[$1\]/g; s/^\s*(\w)/  $1/g' "$file"
      echo "Formatted $file"
    done

    echo "All files in $git_config_dir with 'config' in their name have been formatted."
  else
    echo "Directory $git_config_dir does not exist."
  fi
}

setup_case_sensitive_volume() {
  echo "==========================================================="
  echo "          Setting up case-sensitive APFS volume            "
  echo "-----------------------------------------------------------"

  # Find APFS container
  local container_id=$(diskutil list | grep "APFS Container Scheme" | awk '{print $NF}')
  if [[ -z "$container_id" ]]; then
    echo "Error: No APFS container found"
    return 1
  fi

  echo "Found APFS container: $container_id"

  # Create mount point
  mkdir -p "$HOME/Code"

  # Check if Code volume exists
  local volume_exists=false
  if diskutil apfs list | grep -q "Name:.*Code.*Case-sensitive"; then
    echo "Code volume already exists"
    volume_exists=true
  else
    echo "Creating case-sensitive Code volume..."
    # Use APFSX type for case-sensitive volume
    sudo diskutil apfs addVolume "$container_id" APFSX "Code" || return 1
    echo "Volume created successfully"
    sleep 2
  fi

  # Get Code volume ID
  local volume_id=$(diskutil apfs list | grep -B 3 "Name:.*Code.*Case-sensitive" | grep "Volume disk" | awk '{print $3}')
  if [[ -z "$volume_id" ]]; then
    echo "Error: Code volume ID not found"
    return 1
  fi

  echo "Found volume ID: $volume_id"

  # Check current mount location
  local current_mount=$(mount | grep "$volume_id" | awk '{print $3}')

  # If mounted but not at desired location, unmount first
  if [[ -n "$current_mount" && "$current_mount" != "$HOME/Code" ]]; then
    echo "Volume currently mounted at $current_mount, preparing to remount..."
    sudo diskutil unmount "$volume_id" || {
      echo "Warning: Could not unmount volume $volume_id, trying force unmount"
      sudo diskutil unmount force "$volume_id" || {
        echo "Error: Could not unmount volume $volume_id"
        return 1
      }
    }
  fi

  # Mount volume to desired location
  if ! mount | grep -q "$HOME/Code"; then
    echo "Mounting Code volume to $HOME/Code..."
    sudo diskutil mount -mountPoint "$HOME/Code" "$volume_id" || return 1
  else
    echo "Code volume already mounted at desired location"
  fi

  # Verify mount and case sensitivity
  echo "Verifying mount and case sensitivity..."
  if mount | grep -q "$HOME/Code"; then
    (
      cd "$HOME/Code" || return 1
      local test_file="test_case_sensitive_$(date +%s)"
      local test_file_upper="TEST_CASE_SENSITIVE_$(date +%s)"
      touch "$test_file" "$test_file_upper"
      if [[ -f "$test_file" && -f "$test_file_upper" ]]; then
        echo "Verification successful: Volume mounted and case-sensitive"
        rm "$test_file" "$test_file_upper"
      else
        echo "Warning: Case sensitivity test failed"
        return 1
      fi
    )
  else
    echo "Error: Volume mount verification failed"
    return 1
  fi

  echo "Case-sensitive volume setup completed successfully"
}

install_font() {
  echo "==========================================================="
  echo "                 Install Inconsolata LGC                   "
  echo "-----------------------------------------------------------"

  local font_file="/tmp/InconsolataLGC.zip"
  local font_dir="/tmp/InconsolataLGC"
  local target_dir="$HOME/Library/Fonts"

  if ls "${target_dir}"/*InconsolataLGCNerdFontMono* 1> /dev/null 2>&1; then
    echo "Fonts with 'Inconsolata LGC Nerd Font Mono' already installed, skipping download and installation..."
    return
  fi

  if [[ -e "${font_file}" ]]; then
    echo "Font already downloaded, skipping download..."
  else
    echo "Downloading Inconsolata LGC..."
    curl -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/InconsolataLGC.zip -o "${font_file}"
    echo "Font downloaded successfully to ${font_file}."
  fi

  if [[ -d "${font_dir}" ]]; then
    echo "Font already unzipped, skipping unzip..."
  else
    echo "Unzipping font..."
    mkdir -p "${font_dir}"
    unzip "${font_file}" -d "${font_dir}"
    echo "Font unzipped successfully to ${font_dir}."
  fi

  echo "Copying Mono font files to ${target_dir}..."
  cp "${font_dir}"/*InconsolataLGCNerdFontMono*.ttf "${target_dir}/"
  echo "Font files copied successfully to ${target_dir}."

  echo "Cleaning up..."
  rm -rf "${font_file}" "${font_dir}"
  echo "Installation complete and cleanup done."
}

install_nodejs() {
  echo "==========================================================="
  echo "              Setting up Node.js Environment               "
  echo "-----------------------------------------------------------"

  if ! command -v xz >/dev/null 2>&1; then
    echo "xz is required for unpacking archives. Installing with Homebrew..."
    brew install xz || {
      echo "Failed to install xz. Cannot proceed with Node.js installation."
      return 1
    }
  fi

  if command -v proto > /dev/null; then
    echo "proto is already installed, skipping..."
  else
    echo "Installing proto..."
    curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --no-profile --yes

    echo "Adding proto to PATH..."
    export PATH="$HOME/.proto/bin:$PATH"
  fi

  if ! command -v proto >/dev/null 2>&1; then
    echo "Error: proto command not available. Node.js installation will be skipped."
    return 1
  fi

  echo "-----------------------------------------------------------"
  echo "                * Installing Node.js LTS...                "
  echo "-----------------------------------------------------------"
  proto install node
  echo "-----------------------------------------------------------"
  echo -n "                   * Node.js Version:                   "
  proto run node -- --version
  echo "-----------------------------------------------------------"

  echo "                    * Installing pnpm...                   "
  echo "-----------------------------------------------------------"
  proto install pnpm
  echo -n "                    * pnpm Version:                     "
  proto run pnpm -- --version
  echo "-----------------------------------------------------------"
}

install_rust() {
  echo "==========================================================="
  echo "                      Install Rust                         "
  echo "-----------------------------------------------------------"

  if command -v rustc > /dev/null; then
    echo "Rust is already installed, skipping..."
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
}

reload_zshrc() {
  echo "==========================================================="
  echo "                   Reload Bryan env zshrc                  "
  echo "-----------------------------------------------------------"

  if [[ ! -f "$HOME/.zshrc" ]]; then
    echo "No .zshrc file found. Exiting."
    return 1
  fi

  echo "Removing .zcompdump files in $HOME..."
  rm -f "$HOME/.zcompdump"*

  echo "Reloading zsh completion system..."
  autoload -Uz compinit && compinit -i
}

setup_macos_defaults() {
  echo "==========================================================="
  echo "               Setting up macOS Defaults...                "
  echo "-----------------------------------------------------------"

  echo "Setting Dock to auto-hide..."
  defaults write com.apple.dock "autohide" -bool "true"

  echo "Setting faster key repeat rate for Vim users..."
  # Disable press-and-hold for keys in favor of key repeat
  defaults write NSGlobalDomain "ApplePressAndHoldEnabled" -bool "false"
  # Set a faster key repeat rate (2 ~ 120, lower value = faster)
  defaults write NSGlobalDomain KeyRepeat -int 2
  # Set a shorter delay until repeat starts (15 ~ 120, lower value = shorter delay)
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Show hidden files in Finder
  defaults write com.apple.finder "AppleShowAllFiles" -bool "true"

  # Disable the warning when changing a file extension
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  # Show time in menu bar
  defaults write com.apple.menuextra.clock "DateFormat" -string "\"EEE HH:mm:ss\""
  defaults write com.apple.menuextra.clock ShowSeconds -bool false

  echo "Restarting affected applications..."
  killall Dock
  killall Finder

  echo "macOS defaults have been updated!"
}

display_todo_list() {
  echo "==========================================================="
  echo "                           Done!                           "
  echo "             Bryan Environment Setup finished!             "
  echo "==========================================================="
  echo "                                                           "
  echo "  Do not forget to run these things:                       "
  echo "                                                           "
  echo "    - Setup .npmrc                                         "
  echo "    - Setup launchd for notes                              "
  echo "    - https://www.v2ex.com/t/813229?p=1#r_11048555         "
  echo "                                                           "
  echo "==========================================================="
}

finish() {
  cd $HOME
  display_todo_list
}

start
check_install_xcode_tools
install_homebrew
restore_dotfiles
install_homebrew_packages
setup_zsh_plugins
setup_gpg_agent
setup_gitconfig
format_gitconfig_files
setup_case_sensitive_volume
install_font
install_nodejs
install_rust
reload_zshrc
setup_macos_defaults
finish
