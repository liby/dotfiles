# https://github.com/SukkaW/dotfiles/blob/09b6b2d0a6d20a31143f4201f64c7b7f44fb85f6/_zshrc/macos.zshrc

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

ENABLE_CORRECTION="true"

# Homebrew zsh completion path
__BRYAN_HOMEBREW_ZSH_COMPLETION="${HOMEBREW_PREFIX}/share/zsh/site-functions"
## zsh-completion fpath
__BRYAN_ZSH_COMPLETION_SRC="${HOME}/.zsh/plugins/zsh-completions/src"
source $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/plugins/fsh/fast-syntax-highlighting.plugin.zsh

source $HOME/.cargo/env

# ZSH completions
## For homebrew, is must be added before oh-my-zsh is called.
## https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
## https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/github/README.md#homebrew-installation-note
## Add a check avoiding duplicated fpath
if (( ! $FPATH[(I)${__BRYAN_HOMEBREW_ZSH_COMPLETION}] && $+commands[brew] )) &>/dev/null; then
  fpath+=${__BRYAN_HOMEBREW_ZSH_COMPLETION}
fi
## https://github.com/zsh-users/zsh-completions
[[ -d ${__BRYAN_ZSH_COMPLETION_SRC} ]] && fpath+=${__BRYAN_ZSH_COMPLETION_SRC}
autoload -Uz compinit
compinit

# Export Set
export GPG_PATH=$(find $HOMEBREW_PREFIX -maxdepth 1 -type d -name "gnupg*" 2>/dev/null | head -n 1)
export HOMEBREW_NO_AUTO_UPDATE=1
# You may need to manually set your language environment
export LC_ALL="en_US.UTF-8"
export N_PREFIX="$HOME/.n"
# Create .npm-global folder if not exists
[[ ! -d "$HOME/.npm-global" ]] && mkdir -p $HOME/.npm-global
# Set NPM Global Path
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PNPM_HOME="$HOME/Library/pnpm"
[[ $(command -v chromium) ]] && export PUPPETEER_EXECUTABLE_PATH=$(command -v chromium)
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
export STARSHIP_CACHE="$HOME/.config/starship/cache"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
export UPDATE_ZSH_DAYS=7
# This speed up zsh-autosuggetions by a lot
export ZSH_AUTOSUGGEST_USE_ASYNC='true'

typeset -aU path
path=(
  "$N_PREFIX/bin"
  "$NPM_CONFIG_PREFIX/bin"
  "$PNPM_HOME"
  "./node_modules/.bin"
  "$HOME/bin"
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  "$GPG_PATH/bin"
  "/usr/local/opt/icu4c/bin"
  "/usr/local/opt/icu4c/sbin"
  $path[@]
)

# https://github.com/jessfraz/dotfiles/blob/master/.bashrc#L113C1-L130C1
# Start the gpg-agent if not already running
if ! pgrep -x -u "${USER}" gpg-agent >/dev/null 2>&1; then
  gpg-connect-agent /bye >/dev/null 2>&1
fi
# Update the TTY for gpg-agent to use the current terminal
gpg-connect-agent updatestartuptty /bye >/dev/null
# Use the current terminal for GPG to avoid "Inappropriate ioctl for device" error
export GPG_TTY=$(tty)
# Set SSH to use gpg-agent
unset SSH_AGENT_PID
# Check if the SSH_AUTH_SOCK needs to be set to gpg-agent's socket
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  if [[ -z "$SSH_AUTH_SOCK" || "$SSH_AUTH_SOCK" == *"apple.launchd"* ]]; then
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  fi
fi

# Alias Set
# ip & ipcn
alias ipcn="curl myip.ipip.net"
alias ip="curl ip.sb"
alias dot='$(command -v git) --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias ls='eza --reverse --sort=modified --group-directories-first' 
alias la='ls --all'
alias ll='la --long --git'
alias lt='ll --tree --git-ignore --ignore-glob=.git'
alias python='python3'
alias pip='python -m pip'
# alias pinentry='pinentry-mac'

# path alias
# usage: cd ~xxx
hash -d desktop="$HOME/Desktop"
hash -d downloads="$HOME/Downloads"
hash -d download="$HOME/Downloads"
hash -d documents="$HOME/Documents"
hash -d document="$HOME/Documents"
hash -d code="$HOME/Code"
hash -d applications="/Applications"
hash -d application="/Applications"

# Git Delete Local Merged
dlm() {
  red=$(tput setaf 1)
  blue=$(tput setaf 4)
  green=$(tput setaf 2)
  reset=$(tput sgr0)

  branches=($(git branch --merged | grep -vE '^\*|master|main|develop'))

  if (( ${#branches[@]} == 0 )); then
    printf "${green}\nNo merged branches to delete!${reset}\n"
    return
  fi

  echo ""
  printf "%s\n" "${branches[@]}"
  echo ""

  printf "\n${blue}Delete merged branches locally? Press [Enter] to continue...${reset}"
  read _

  echo ""
  echo "Safely deleting merged local branches..."

  for branch in "${branches[@]}"; do
    git branch -d "$branch"
  done

  echo "${green}Done!${reset}"
}

# GitHub Copilot CLI
if (( $+commands[github-copilot-cli] )) &>/dev/null; then
  eval "$(github-copilot-cli alias -- "$0")"
fi

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

# https://github.com/zsh-users/zsh-autosuggestions/issues/351
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste accept-line)
ZSH_AUTOSUGGEST_MANUAL_REBIND=""

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
if (( $+commands[rbenv] )); then
  eval "$(rbenv init - zsh)"
fi
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi
