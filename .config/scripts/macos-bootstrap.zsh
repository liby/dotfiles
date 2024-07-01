#!/bin/zsh

# curl -o /tmp/macos-bootstrap.zsh https://raw.githubusercontent.com/liby/dotfiles/main/.config/scripts/macos-bootstrap.zsh && chmod +x /tmp/macos-bootstrap.zsh && /tmp/macos-bootstrap.zsh
# This script is heavily inspired by [SukkaW](https://github.com/SukkaW/dotfiles/blob/master/_install/macos.zsh)

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "No macOS detected!"
  exit 1
fi

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
  echo "        YOU ARE SETTING UP: Bryan Environment (macOS)      "
  echo "==========================================================="
  echo "                                                           "
  echo "          * The setup will begin in 3 seconds...           "

  sleep 3

  echo "                Times up! Here we start!                   "
  echo "-----------------------------------------------------------"

  cd $HOME
}

is_apple_silicon() {
  [[ "$(/usr/bin/uname -m)" == "arm64" ]]
}

setup_brew() {
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

  if [ ! -x "$(command -v brew)" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    setup_brew

    if ! ([[ -e "$HOME/.zprofile" ]] && grep -q "brew shellenv" "$HOME/.zprofile"); then
        echo "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\"" >> "${HOME}/.zprofile"
        echo "typeset -U path" >> "${HOME}/.zprofile"
    fi

    brew analytics off && brew update
    echo "Homebrew installed."
  else
    echo "Homebrew already installed. Skipping..."
  fi
}

install_brew_packages() {
  # Only install required packages for setting up enviroments
  # Later we will call brew bundle
  __pkg_to_be_installed=(
    curl
    git
    gnupg
    pinentry-mac
    zsh
  )

  echo "==========================================================="
  echo "                * Install following packages:              "
  echo "                                                           "

  for __pkg ($__pkg_to_be_installed); do
    echo "  - ${__pkg}"
  done

  echo "-----------------------------------------------------------"

  brew update

  for __pkg in $__pkg_to_be_installed; do
    if brew list --formula | grep -q "^${__pkg}\$"; then
      echo "${__pkg} is already installed, skipping..."
    else
      brew install ${__pkg} || true
    fi
  done
}

brew_bundle() {
  echo "==========================================================="
  echo "          * Restore bundles from Homebrew                  "
  echo "-----------------------------------------------------------"
  brew bundle
}

setup_ohmyzsh() {
  echo "==========================================================="
  echo "                      Shells Enviroment                    "
  echo "-----------------------------------------------------------"
  echo "                   * Installing Oh My Zsh...               "
  echo "-----------------------------------------------------------"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "Oh My Zsh is already installed, skipping..."
  else
    echo "Oh My Zsh is not installed, proceeding with the installation..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  echo "-----------------------------------------------------------"
  echo "          * Installing ZSH Custom Plugins & Themes:        "
  echo "                                                           "
  echo "  - zsh-autosuggestions                                    "
  echo "  - zsh-completions                                        "
  echo "  - fast-syntax-highlighting                               "
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
  echo "                * Setting up GPG Agent                     "
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
  echo "                     Setting up Gitconfig                  "
  echo "-----------------------------------------------------------"

  local git_config_dir="$HOME/.config/git"
  local github_example_config="$git_config_dir/github.example.config"
  local gitlab_example_config="$git_config_dir/gitlab.example.config"
  local github_config="$git_config_dir/github.config"
  local gitlab_config="$git_config_dir/gitlab.config"
  local ssh_dir="$HOME/.ssh"

  # Ensure the .ssh directory exists
  [ ! -d "$ssh_dir" ] && mkdir -p "$ssh_dir"

  # Copy example configs if the actual configs do not exist
  [ ! -f "$github_config" ] && cp "$github_example_config" "$github_config"
  [ ! -f "$gitlab_config" ] && cp "$gitlab_example_config" "$gitlab_config"

  # Decode email and name
  local encoded_email="Ym95dWFuLmxpQHJpZ2h0Y2FwaXRhbC5jb20="
  local decoded_email=$(echo -n "$encoded_email" | base64 --decode)
  local encoded_name="Qm95dWFuIExp"
  local decoded_name=$(echo -n "$encoded_name" | base64 --decode)

  # Set GitLab user email and name
  git config --file "$gitlab_config" user.email "$decoded_email"
  git config --file "$gitlab_config" user.name "$decoded_name"

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
  echo "                    Format Gitconfig Files                 "
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

restore_dotfiles() {
  echo "-----------------------------------------------------------"
  echo "         * Restore Bryan’s dotfiles from GitHub.com        "
  echo "-----------------------------------------------------------"

  if [[ -d "$HOME/.dotfiles" ]]; then
    echo "Dotfiles already restored, skipping..."
  else
    git clone --bare https://github.com/liby/dotfiles.git $HOME/.dotfiles
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME config --local status.showUntrackedFiles no
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout --force

    setup_gpg_agent
    setup_gitconfig
    format_gitconfig_files
    brew_bundle
  fi

  git --git-dir=$HOME/.dotfiles --work-tree=$HOME remote set-url origin git@github.com:liby/dotfiles.git
}

install_nodejs() {
  echo "==========================================================="
  echo "              Setting up NodeJS Environment                "
  echo "-----------------------------------------------------------"

  if command -v n > /dev/null; then
    echo "tj/n is already installed, skipping..."
    return
  fi

  export N_PREFIX="$HOME/.n"
  curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s lts

  # Set NPM Global Path
  export NPM_CONFIG_PREFIX="$HOME/.npm-global"
  # Create .npm-global folder if not exists
  [[ ! -d "$NPM_CONFIG_PREFIX" ]] && mkdir -p $NPM_CONFIG_PREFIX

  echo "-----------------------------------------------------------"
  echo "                * Installing Node.js LTS...                "
  echo "-----------------------------------------------------------"

  n lts

  echo "-----------------------------------------------------------"
  echo -n "                   * Node.js Version:                   "

  node -v

  echo "-----------------------------------------------------------"

  __npm_global_pkgs=(
    @upimg/cli
    0x
    # clinic
    npm-why
    # serve
    # vercel
  )

  echo "-----------------------------------------------------------"
  echo "                * npm install global packages:             "
  echo "                                                           "

  for __npm_pkg ($__npm_global_pkgs); do
    echo "  - ${__npm_pkg}"
  done

  echo "-----------------------------------------------------------"

  for __npm_pkg ($__npm_global_pkgs); do
    npm i -g ${__npm_pkg}
  done
}

install_rust() {
  echo "==========================================================="
  echo "                   Install Rust                            "
  echo "-----------------------------------------------------------"


  if command -v rustc > /dev/null; then
    echo "Rust is already installed, skipping..."
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
}

install_font() {
  echo "==========================================================="
  echo "                 Install Inconsolata LGC                   "
  echo "-----------------------------------------------------------"

  local font_file="/tmp/InconsolataLGC.zip"
  local font_dir="/tmp/InconsolataLGC"
  local target_dir="$HOME/Library/Fonts"

  if ls "${target_dir}"/*InconsolataLGCNerdFontMono* 1> /dev/null 2>&1; then
    echo "Fonts with 'InconsolataLGCNerdFontMono' already installed, skipping download and installation..."
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

reload_zshrc() {
  echo "==========================================================="
  echo "                  Reload Bryan env zshrc                   "
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

display_todo_list() {
  echo "==========================================================="
  echo "Done!                                                      "
  echo "                                                           "
  echo "> Bryan Environment Setup finished!                        "
  echo "> Do not forget to run these things:                       "
  echo "                                                           "
  echo "- NPM login                                                "
  echo "- Setup .npmrc                                             "
  echo "- Setup iTerm2                                             "
  echo "- Setup launchd for notes                                  "
  echo "- Install Bob,                                             "
  echo "          Slack,                                           "
  echo "          WeChat,                                          "
  echo "          Telegram,                                        "
  echo "          The Unarchiver,                                  "
  echo "          Hidden Bar                                       "
  echo "  from the Apple Store                                     "
  echo "- Create a case-sensitive volume on macOS                  "
  echo "- https://www.v2ex.com/t/813229?p=1#r_11048555             "
  echo "                                                           "
  echo "==========================================================="
}

finish() {
  cd $HOME
  display_todo_list
}

start
install_homebrew
install_brew_packages
setup_ohmyzsh
restore_dotfiles
install_nodejs
install_rust
install_font
reload_zshrc
finish
