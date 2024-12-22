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

restore_dotfiles() {
  echo "==========================================================="
  echo "         Restore Bryan’s dotfiles from GitHub.com          "
  echo "-----------------------------------------------------------"

  if [[ -d "$HOME/.dotfiles" ]]; then
    echo "Dotfiles already restored, skipping..."
  else
    git clone --bare https://github.com/liby/dotfiles.git $HOME/.dotfiles
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME config --local status.showUntrackedFiles no
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout --force
  fi

  git --git-dir=$HOME/.dotfiles --work-tree=$HOME remote set-url origin git@github.com:liby/dotfiles.git
}

setup_ohmyzsh() {
  echo "==========================================================="
  echo "                     Shells Environment                    "
  echo "-----------------------------------------------------------"
  echo "                  * Installing Oh My Zsh...                "
  echo "-----------------------------------------------------------"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "Oh My Zsh is already installed, skipping..."
  else
    echo "Oh My Zsh is not installed, proceeding with the installation..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  echo "-----------------------------------------------------------"
  echo "        * Installing ZSH Custom Plugins & Themes...        "
  echo "                                                           "
  echo "                - zsh-autosuggestions                      "
  echo "                - zsh-completions                          "
  echo "                - fast-syntax-highlighting                 "
  echo "                                                           "
  echo "-----------------------------------------------------------"

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

  if grep -q "pinentry-program" "$gpg_agent_conf"; then
    echo "pinentry-program is already configured in $gpg_agent_conf."
  else
    echo "Configuring pinentry-program in $gpg_agent_conf..."
    echo "pinentry-program $(command -v pinentry-mac)" >> "$gpg_agent_conf"
  fi

  echo "Launching gpg-agent if not already running..."
  gpgconf --launch gpg-agent

  echo "Reloading gpg-agent configuration..."
  echo RELOADAGENT | gpg-connect-agent

  echo "Fetching GPG keys from Yubikey..."
  # Fetch the keys from Yubikey
  echo "fetch" | gpg --command-fd 0 --status-fd 1 --card-edit > /dev/null 2>&1

  # Wait for a moment to ensure the keys are fetched
  sleep 3

  echo "GPG Agent setup completed."
}

setup_gitconfig() {
  echo "==========================================================="
  echo "                 Setting up git config...                  "
  echo "-----------------------------------------------------------"

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
  local gpg_key_id=$(gpg --card-status | grep 'sec' | awk '{print $2}' | cut -d'/' -f2)
  if [[ -n "$gpg_key_id" ]]; then
    local gpg_ssh_pub_key_file="$ssh_dir/$gpg_key_id.pub"

    echo "Exporting GPG key $gpg_key_id as SSH key..."
    gpg --export-ssh-key "$gpg_key_id" > "$gpg_ssh_pub_key_file"
    echo "GPG SSH Public key exported successfully."

    git config --file "$github_config" user.signingkey "$gpg_key_id"
    git config --file "$gitlab_config" user.signingkey "$gpg_ssh_pub_key_file"
  else
    echo "No GPG key found. Please ensure a GPG key is available."
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

  # Create mount point
  mkdir -p "$HOME/Code"

  # Check if already mounted
  if mount | grep -q "/Users/.*/Code"; then
    echo "Code volume is already mounted"
    return 0
  fi

  # Check if Code volume exists
  if diskutil apfs list | grep -q "Name:.*Code.*Case-sensitive"; then
    echo "Code volume exists, proceeding to mount"
  else
    echo "Creating case-sensitive Code volume..."
    sudo diskutil apfs addVolume "$container_id" APFS "Code" -case-sensitive || return 1
    echo "Volume created successfully"
    sleep 2
  fi

  # Get Code volume ID
  local volume_id=$(diskutil apfs list | grep -B 3 "Name:.*Code.*Case-sensitive" | grep "Volume disk" | awk '{print $3}')
  if [[ -z "$volume_id" ]]; then
    echo "Error: Code volume ID not found"
    return 1
  fi

  # Mount volume
  echo "Mounting Code volume..."
  sudo diskutil mount -mountPoint "$HOME/Code" "$volume_id" || return 1

  # Verify mount and case sensitivity
  echo "Verifying mount and case sensitivity..."
  if mount | grep -q "/Users/.*/Code"; then
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
  # Reference: https://github.com/mas-cli/mas/blob/main/Sources/mas/Controllers/ITunesSearchAppStoreSearcher.swift#L18-L22
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

install_nodejs() {
  echo "==========================================================="
  echo "              Setting up Node.js Environment               "
  echo "-----------------------------------------------------------"
  if command -v proto > /dev/null; then
    echo "proto is already installed, skipping..."
  else
    echo "Installing proto..."
    curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --no-profile --yes
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

  # Set NPM Global Path (if you still want to use npm for global packages)
  export NPM_CONFIG_PREFIX="$HOME/.npm-global"
  # Create .npm-global folder if not exists
  [[ ! -d "$NPM_CONFIG_PREFIX" ]] && mkdir -p $NPM_CONFIG_PREFIX

  __npm_global_pkgs=(
    @upimg/cli
    0x
    npm-why
  )

  echo "-----------------------------------------------------------"
  echo "              * npm install global packages:               "
  echo "                                                           "
  for __npm_pkg in "${__npm_global_pkgs[@]}"; do
    echo "  - ${__npm_pkg}"
    proto run npm -- install -g ${__npm_pkg}
  done
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

  echo "Starting a new zsh session..."
  exec zsh
}

setup_iterm2() {
  echo "==========================================================="
  echo "                   Setting up iTerm2...                    "
  echo "-----------------------------------------------------------"

  if [ ! -d "/Applications/iTerm.app" ]; then
    echo "iTerm2 is not installed, skipping configuration..."
    return 0
  fi

  local iterm2_config_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/iTerm2"

  if [ ! -d "$iterm2_config_dir" ]; then
    echo "iTerm2 config directory not found: $iterm2_config_dir"
    return 0
  fi

  echo "Setting iTerm2 to use custom config directory..."
  defaults write -app iTerm PrefsCustomFolder "$iterm2_config_dir"
  defaults write -app iTerm LoadPrefsFromCustomFolder -bool true

  echo "iTerm2 configuration completed."
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
restore_dotfiles
setup_ohmyzsh
setup_gpg_agent
setup_gitconfig
setup_case_sensitive_volume
format_gitconfig_files
install_font
install_homebrew
install_homebrew_packages
install_nodejs
install_rust
reload_zshrc
setup_iterm2
finish
