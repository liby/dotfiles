<h4 align="right"><strong>English</strong> | <a href="README_CN.md">简体中文</a></h4>

# My Dotfiles

These dotfiles configure my macOS development environment and stay in sync across my Macs with [chezmoi](https://www.chezmoi.io/). The repository also includes bootstrap scripts for setting up a new Mac.

This setup supports Apple Silicon Macs only; Intel Macs are not supported.

Some settings depend on my accounts, GPG keys, and filesystem layout. Adjust them for a different environment.

## Project overview

| Area | Start with |
| --- | --- |
| Agent tooling | [`dot_agents`](../dot_agents/), [`dot_claude`](../dot_claude/), [`dot_codex`](../dot_codex/) |
| Git | [`dot_config/git`](../dot_config/git/), [`.chezmoitemplates/git`](../.chezmoitemplates/git/) |
| Repository design | [`CONCEPTS.md`](CONCEPTS.md) |
| Packages and bootstrap | [`Brewfile`](../Brewfile), [`.chezmoiscripts`](../.chezmoiscripts/) |
| Shell and applications | [`dot_zshrc`](../dot_zshrc), [`dot_zsh`](../dot_zsh/), [`dot_config`](../dot_config/) |
| chezmoi configuration and templates | [`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl), [`.chezmoitemplates`](../.chezmoitemplates/) |

## Set up a new Mac

Open Terminal.app on the new Mac and run:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply liby
```

This starts an interactive setup, not an unattended installation. Keep Terminal.app open to enter private template values, respond to Xcode or `sudo` prompts, and use your YubiKey when needed.

The command installs chezmoi, clones this repository into `~/.local/share/chezmoi`, runs the bootstrap scripts, and applies the managed files to `$HOME`.

If chezmoi is already installed, run:

```sh
chezmoi init --apply liby
```

## Common operations

```sh
chezmoi status                     # Show configuration status
chezmoi diff <target>              # Inspect changes to one configuration file
chezmoi apply                      # Apply configuration to $HOME
chezmoi edit <target>              # Edit a managed encrypted file
chezmoi edit-encrypted <filename>  # Edit an encrypted file not managed by chezmoi
```

Editing encrypted files requires a YubiKey and should not be delegated to an agent.

See chezmoi's [daily operations guide](https://www.chezmoi.io/user-guide/daily-operations/) for other commands.

## Reuse

Fork this repository and adapt it to your environment, or copy only the parts you need. Before applying the full setup, review and adjust `.chezmoi.toml.tmpl`, `Brewfile`, and `.chezmoiscripts/`.

## Contributing

Before changing this repository, read [`AGENTS.md`](../AGENTS.md) for repository-specific workflows, safety boundaries, and validation rules. Open an [issue](https://github.com/liby/dotfiles/issues/new) to report a problem or a [pull request](https://github.com/liby/dotfiles/pulls) to propose a change.
