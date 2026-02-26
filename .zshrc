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
fpath+=$HOME/.zsh/functions
## Initialize the completion system
## This must be done after all fpath modifications
autoload -Uz compinit
# Only regenerate .zcompdump once a day
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

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
export HOMEBREW_BUNDLE_DUMP_NO_VSCODE=1
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
alias python='python3'

# Functions (autoloaded from ~/.zsh/functions/)
autoload -Uz dlm pasteinit pastefinish setup_gpg_ssh

# This speeds up pasting w/ autosuggest
# https://github.com/zsh-users/zsh-autosuggestions/issues/238
zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

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
