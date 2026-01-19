# Load full shell config for OpenCode non-interactive shell
# OpenCode sets OPENCODE=1 in its environment
if [[ -n "$OPENCODE" ]]; then
  [[ -r "$HOME/.zprofile" ]] && source "$HOME/.zprofile"
  [[ -r "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
fi
