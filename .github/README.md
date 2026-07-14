<h4 align="right">
  <strong>English</strong> | <a href="https://github.com/liby/dotfiles/blob/main/.github/README_CN.md">简体中文</a>
</h4>

<div>
  <h1 align="center">My Dotfiles</h1>
</div>

> **Note**
>
> This repository contains my dotfiles for managing my development environment. Powered by [chezmoi](https://www.chezmoi.io/), it allows me to effortlessly keep my configurations in sync across multiple Macs.

## Project Overview

This repository contains a series of configuration files and scripts used to set up and manage my development environment, including but not limited to:

  - Agentic coding configuration: [`dot_claude`](https://github.com/liby/dotfiles/tree/main/dot_claude) / [`dot_codex`](https://github.com/liby/dotfiles/tree/main/dot_codex)

  - Shared Agent Skills: [`dot_agents/skills`](https://github.com/liby/dotfiles/tree/main/dot_agents/skills)

  - Git configuration: [`dot_config/git`](https://github.com/liby/dotfiles/tree/main/dot_config/git)

  - Homebrew dependencies: [`Brewfile`](https://github.com/liby/dotfiles/blob/main/Brewfile)

  - Shell configuration: [`dot_zshrc`](https://github.com/liby/dotfiles/blob/main/dot_zshrc)

  - Terminal prompt: [`dot_config/starship`](https://github.com/liby/dotfiles/tree/main/dot_config/starship)

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
chezmoi status --exclude=encrypted  # Show a safe change overview
chezmoi diff <dest-path>    # Inspect one non-secret target
chezmoi apply               # Apply all changes to $HOME
chezmoi cd                  # Enter the source directory
chezmoi git status          # Run Git commands on the source directory from anywhere
```

### Encrypted files

Sensitive files are stored with GPG encryption:

```sh
chezmoi add --encrypt <file>   # Add with encryption
```

### Bootstrap scripts

Bootstrap scripts are located in `.chezmoiscripts/` and run in listed order:

| Phase | Script | Notes |
|-------|--------|-------|
| before | [Xcode CLI Tools](../.chezmoiscripts/run_once_before_100-install-xcode-cli-tools.sh) | Required for Git and compilation |
| before | [Homebrew](../.chezmoiscripts/run_once_before_200-install-homebrew.sh) | |
| before | [Brewfile packages](../.chezmoiscripts/run_onchange_before_300-install-brew-packages.sh.tmpl) | |
| before | [Case-sensitive volume](../.chezmoiscripts/run_once_before_400-setup-case-sensitive-volume.sh) | For the `~/Code` directory |
| before | [Node.js](../.chezmoiscripts/run_once_before_500-install-nodejs.sh) | Via proto; includes pnpm |
| before | [uv tools](../.chezmoiscripts/run_onchange_before_600-install-uv-tools.sh) | |
| before | [Rust](../.chezmoiscripts/run_once_before_700-install-rust.sh) | |
| before | [Claude Code](../.chezmoiscripts/run_once_before_800-install-claude-code.sh) | |
| after | [GPG agent](../.chezmoiscripts/run_once_after_100-setup-gpg-agent.sh) | Includes YubiKey setup |
| after | [Git config](../.chezmoiscripts/run_once_after_200-setup-gitconfig.sh) | Generated from templates |
| after | [macOS defaults](../.chezmoiscripts/run_onchange_after_300-setup-macos-defaults.sh) | |
| after | [zsh completions](../.chezmoiscripts/run_once_after_400-reload-zsh-completions.sh) | |
| after | [Developer tools](../.chezmoiscripts/run_onchange_after_600-update-dev-tools.sh.tmpl) | Periodic CLI updates |

`before` scripts run before file sync, `after` scripts run after file sync.

Zsh plugins are pinned to exact upstream commits in [`.chezmoiexternal.toml`](../.chezmoiexternal.toml). Chezmoi reconciles these archives declaratively instead of cloning whichever branch head exists during first setup.

## Contribution Guidelines

If you have any suggestions or issues, feel free to open an [Issue](https://github.com/liby/dotfiles/issues/new) or [Pull Request](https://github.com/liby/dotfiles/pulls).
