<h4 align="right">
  <strong>English</strong> | <a href="https://github.com/liby/dotfiles/blob/main/.github/README_CN.md">简体中文</a>
</h4>

<div>
  <h1 align="center">My Dotfiles</h1>
</div>

> **Note**
>
> This is my dotfiles repository for configuring and managing my development environment. With [chezmoi](https://www.chezmoi.io/), I can easily keep my setup in sync across multiple devices.

## Project Overview

This repository contains a series of configuration files and scripts used to set up and manage my development environment, including but not limited to:

  - Bootstrap scripts: [_.chezmoiscripts_](https://github.com/liby/dotfiles/tree/main/.chezmoiscripts)

  - Homebrew dependencies: [_Brewfile_](https://github.com/liby/dotfiles/blob/main/Brewfile)

  - Shell configuration: [_dot_zshrc_](https://github.com/liby/dotfiles/blob/main/dot_zshrc)

  - Terminal prompt: [_dot_config/starship_](https://github.com/liby/dotfiles/tree/main/dot_config/starship)

  - Git configuration: [_dot_config/git_](https://github.com/liby/dotfiles/tree/main/dot_config/git)

  - SSH configuration: [_dot_ssh/config_](https://github.com/liby/dotfiles/blob/main/dot_ssh/config)

  - Claude Code configuration: [_dot_claude_](https://github.com/liby/dotfiles/tree/main/dot_claude)

These files are managed using [chezmoi](https://www.chezmoi.io/), with support for templates, encryption, and per-device customization.

## Installation Instructions

### One-command setup on a new machine

On a new Mac, open Terminal.app and run:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply liby
```

This command will:
1. Install chezmoi
2. Clone this repository to `~/.local/share/chezmoi`
3. Run all bootstrap scripts (installing Xcode CLI Tools, Homebrew, brew packages, etc.)
4. Sync configuration files to `$HOME`

### On a machine with chezmoi already installed

```sh
chezmoi init liby
chezmoi apply
```

## Usage

```sh
chezmoi add <file>          # Add a file to chezmoi management
chezmoi edit <file>         # Edit the source file
chezmoi diff                # Show differences between source and target
chezmoi apply               # Apply all changes to $HOME
chezmoi cd                  # Enter the source directory
chezmoi git status          # Run git commands on the source directory from anywhere
```

### Encrypted files

Sensitive files are stored with GPG encryption:

```sh
chezmoi add --encrypt <file>   # Add with encryption
```

### Bootstrap scripts

Bootstrap scripts are located in `.chezmoiscripts/` and run in numbered order:

| Phase | Script | Description |
|-------|--------|-------------|
| before | [01-install-xcode-cli-tools](../.chezmoiscripts/run_once_before_01-install-xcode-cli-tools.sh) | Install Xcode Command Line Tools |
| before | [02-install-homebrew](../.chezmoiscripts/run_once_before_02-install-homebrew.sh) | Install Homebrew |
| before | [03-install-brew-packages](../.chezmoiscripts/run_onchange_before_03-install-brew-packages.sh.tmpl) | Install all packages from Brewfile |
| before | [04-setup-case-sensitive-volume](../.chezmoiscripts/run_once_before_04-setup-case-sensitive-volume.sh) | Create case-sensitive Code volume |
| before | [05-install-nodejs](../.chezmoiscripts/run_once_before_05-install-nodejs.sh) | Install proto, Node.js, pnpm |
| before | [06-install-rust](../.chezmoiscripts/run_once_before_06-install-rust.sh) | Install Rust |
| before | [07-install-claude-code](../.chezmoiscripts/run_once_before_07-install-claude-code.sh) | Install Claude Code |
| before | [08-setup-zsh-plugins](../.chezmoiscripts/run_once_before_08-setup-zsh-plugins.sh) | Install zsh plugins |
| after | [01-setup-gpg-agent](../.chezmoiscripts/run_once_after_01-setup-gpg-agent.sh) | Configure GPG agent and Yubikey |
| after | [02-setup-gitconfig](../.chezmoiscripts/run_once_after_02-setup-gitconfig.sh) | Generate git config from templates |
| after | [03-setup-macos-defaults](../.chezmoiscripts/run_once_after_03-setup-macos-defaults.sh) | Set macOS system preferences |
| after | [04-reload-zsh-completions](../.chezmoiscripts/run_once_after_04-reload-zsh-completions.sh) | Rebuild zsh completion cache |

`before` scripts run before file sync, `after` scripts run after file sync.

## Contribution Guidelines

If you have any suggestions or issues, feel free to open an Issue or Pull Request.
