# https://github.com/SukkaW/dotfiles/blob/09b6b2d0a6d20a31143f4201f64c7b7f44fb85f6/_zshrc/macos.zshrc

# Homebrew zsh completion path
__BRYAN_HOMEBREW_ZSH_COMPLETION="${HOMEBREW_PREFIX}/share/zsh/site-functions"
__BRYAN_ZSH_COMPLETION_SRC="${HOME}/.zsh/plugins/zsh-completions/src"

# ZSH completions
## Add Homebrew completion path if not already present,
## usually handled by `brew shellenv` in .zprofile
## https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
## https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/github/README.md#homebrew-installation-note
## Add a check avoiding duplicated fpath
if (( ! $FPATH[(I)${__BRYAN_HOMEBREW_ZSH_COMPLETION}] && $+commands[brew] )) &>/dev/null; then
  fpath+=${__BRYAN_HOMEBREW_ZSH_COMPLETION}
fi
## https://github.com/zsh-users/zsh-completions
[[ -d ${__BRYAN_ZSH_COMPLETION_SRC} ]] && fpath+=${__BRYAN_ZSH_COMPLETION_SRC}
## Initialize the completion system
## This must be done after all fpath modifications
autoload -Uz compinit
compinit

editor_config_path="$HOME/.config/editor"
npm_global_path="$HOME/.npm-global"

# Create necessary directories
local -a dirs_to_create=(
  "$editor_config_path"
  "$npm_global_path"
  "$npm_global_path/lib"
  "$npm_global_path/bin"
  "$HOME/.config/starship/cache"
)

for dir in $dirs_to_create; do
  [[ ! -d "$dir" ]] && mkdir -p "$dir"
done

# Environment variables
if [[ -z "$GPG_PATH" ]]; then
  export GPG_PATH="$HOMEBREW_PREFIX/opt/gnupg"
fi
export LC_ALL="en_US.UTF-8"
export NPM_CONFIG_PREFIX="$npm_global_path"
export PNPM_HOME="$HOME/Library/pnpm"
export PROTO_AUTO_INSTALL_HIDE_OUTPUT=true
export PROTO_HOME="$HOME/.proto"
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
export STARSHIP_CACHE="$HOME/.config/starship/cache"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
## This speed up zsh-autosuggestions by a lot
export ZSH_AUTOSUGGEST_USE_ASYNC='true'
[[ $(command -v chromium) ]] && export PUPPETEER_EXECUTABLE_PATH=$(command -v chromium)

# PATH configuration
local -a path_dirs=(
  "$PROTO_HOME/shims"
  "$PROTO_HOME/bin"
  "$NPM_CONFIG_PREFIX/bin"
  "$PNPM_HOME"
  "./node_modules/.bin"
  "$HOME/bin"
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  "$GPG_PATH/bin"
  "$GPG_PATH/libexec"
  "/usr/local/opt/icu4c/bin"
  "/usr/local/opt/icu4c/sbin"
)

# Add UV PATH if available
if HOMEBREW_UV_PATH=$(brew --prefix uv 2>/dev/null)/bin; then
  path_dirs=("$HOMEBREW_UV_PATH" $path_dirs)
fi

# Add Homebrew curl PATH if available
if HOMEBREW_CURL_PATH=$(brew --prefix curl 2>/dev/null)/bin; then
  path_dirs=("$HOMEBREW_CURL_PATH" $path_dirs)
fi

typeset -aU path
path=($path_dirs $path[@])

# Alias Set
alias c='open $1 -a "Visual Studio Code"'
alias cc='claude'
alias dot='$(command -v git) --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias gca='git commit -m "$(claude -p "Look at the staged git changes and create a summarizing git commit title. Only respond with the title and no affirmation.")"'
## ip & ipcn
alias ip="curl ip.sb"
alias ipcn="curl myip.ipip.net"
alias ka='caffeinate -is'
alias la='ls --all'
alias ll='la --long --git'
alias ls='eza --reverse --sort=modified --group-directories-first --hyperlink'
alias lt='ll --tree --git-ignore --ignore-glob=.git'

# Path Alias
# usage: cd ~xxx
# hash -d desktop="$HOME/Desktop"
# hash -d downloads="$HOME/Downloads"
# hash -d download="$HOME/Downloads"
# hash -d documents="$HOME/Documents"
# hash -d document="$HOME/Documents"
# hash -d code="$HOME/Code"
# hash -d applications="/Applications"
# hash -d application="/Applications"

# Functions
dlm() {
  local red=$'\e[1;31m'
  local green=$'\e[1;32m'
  local yellow=$'\e[1;33m'
  local blue=$'\e[1;34m'
  local reset=$'\e[0m'

  echo "${blue}Fetching latest changes and identifying branches...${reset}"

  local max_retries=3
  local retry_count=0
  local fetch_success=false

  while (( retry_count < max_retries )) && ! $fetch_success; do
    if git fetch --quiet --all && git remote prune origin; then
      fetch_success=true
    else
      ((retry_count++))
      echo "${yellow}Fetch failed. Retrying... (Attempt $retry_count of $max_retries)${reset}"
      sleep 2
    fi
  done

  if ! $fetch_success; then
    echo "${red}Failed to fetch after $max_retries attempts. Please check your network connection and try again.${reset}"
    return 1
  fi

  local remote_branches=$(git ls-remote --heads origin | awk '{print $2}' | sed 's|refs/heads/||')

  local branches=($(git for-each-ref --format '%(refname:short)' refs/heads |
    grep -vE '^(master|main|develop)$' |
    while read -r branch; do
      if ! echo "$remote_branches" | grep -q "^$branch$"; then
        echo "$branch"
      fi
    done))

  if (( ${#branches[@]} == 0 )); then
    echo "${green}No local branches to delete.${reset}"
    return
  fi

  echo "\n${yellow}The following local branches are not present in remote:${reset}"
  printf "%s\n" "${branches[@]}"

  echo "\n${blue}Do you want to delete these branches? [Y/n]${reset}"
  read -q response || return

  echo

  local deleted=0
  local failed=0

  for branch in "${branches[@]}"; do
    if git branch -D "$branch" &>/dev/null; then
      echo "${green}Deleted: $branch${reset}"
      ((deleted++))
    else
      echo "${red}Failed to delete: $branch${reset}"
      ((failed++))
    fi
  done
  echo "\n${green}Operation complete.${reset}"
  echo "Branches deleted: ${deleted}"
  [[ $failed -gt 0 ]] && echo "${red}Branches failed to delete: ${failed}${reset}"
}

# This speeds up pasting w/ autosuggest
# https://github.com/zsh-users/zsh-autosuggestions/issues/238
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}

pastefinish() {
  zle -N self-insert $OLD_SELF_INSERT
}

zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

setup_gpg_ssh() {
  ## https://github.com/jessfraz/dotfiles/blob/master/.bashrc#L113C1-L130C1
  ## Start the gpg-agent if not already running
  if ! pgrep -x -u "${USER}" gpg-agent >/dev/null 2>&1; then
    if ! gpg-connect-agent /bye >/dev/null 2>&1; then
      echo "Failed to start gpg-agent" >&2
      return 1
    fi
  fi

  ## Update the TTY for gpg-agent
  if ! gpg-connect-agent updatestartuptty /bye >/dev/null; then
    echo "Failed to update GPG TTY" >&2
    return 1
  fi

  ## Use the current terminal for GPG to avoid "Inappropriate ioctl for device" error
  export GPG_TTY=$(tty)

  ## Set SSH to use gpg-agent
  unset SSH_AGENT_PID

  ## Check if the SSH_AUTH_SOCK needs to be set to gpg-agent's socket
  if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
    if [[ -z "$SSH_AUTH_SOCK" || "$SSH_AUTH_SOCK" == *"apple.launchd"* ]]; then
      local socket_path="$(gpgconf --list-dirs agent-ssh-socket)"
      if [[ -S "$socket_path" ]]; then
        export SSH_AUTH_SOCK="$socket_path"
      else
        echo "GPG SSH socket not found" >&2
        return 1
      fi
    fi
  fi

  return 0
}

# Autosuggestions configuration# https://github.com/zsh-users/zsh-autosuggestions/issues/351
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste accept-line)
ZSH_AUTOSUGGEST_MANUAL_REBIND=""

# Source plugins and configurations
source $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/plugins/fsh/fast-syntax-highlighting.plugin.zsh
source $HOME/.cargo/env

# Initialize tools and configurations
(( $+commands[gpg-connect-agent] )) && setup_gpg_ssh &>/dev/null
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
(( $+commands[proto] )) && eval "$(proto activate zsh)"
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
