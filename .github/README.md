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

  - Git configuration: [`dot_config/git`](https://github.com/liby/dotfiles/tree/main/dot_config/git) and [`.chezmoitemplates/git`](https://github.com/liby/dotfiles/tree/main/.chezmoitemplates/git)

  - Homebrew dependencies: [`Brewfile`](https://github.com/liby/dotfiles/blob/main/Brewfile)

  - Shell configuration: [`dot_zshrc`](https://github.com/liby/dotfiles/blob/main/dot_zshrc)

  - Terminal prompt: [`dot_config/starship`](https://github.com/liby/dotfiles/tree/main/dot_config/starship)

These files are managed using [chezmoi](https://www.chezmoi.io/), with support for templates, encryption, and per-device customization.

## Installation Instructions

### One-command setup on a new machine

On a new Apple Silicon Mac, open Terminal.app and run:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply liby
```

This is a single entry point, not an unattended install. Keep Terminal.app open
for private template prompts, Xcode or `sudo` interaction, and YubiKey access.

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
| before | [Xcode CLI Tools](../.chezmoiscripts/run_once_before_01-install-xcode-cli-tools.sh) | Required for Git and compilation |
| before | [Homebrew](../.chezmoiscripts/run_once_before_02-install-homebrew.sh) | |
| before | [Brewfile packages](../.chezmoiscripts/run_onchange_before_03-install-brew-packages.sh.tmpl) | Recreates a daily Homebrew update, upgrade, and cleanup LaunchAgent |
| before | [GPG agent](../.chezmoiscripts/run_once_before_04-setup-gpg-agent.sh) | Fetches the YubiKey public key before encrypted targets are synchronized |
| before | [Case-sensitive volume](../.chezmoiscripts/run_once_before_05-setup-case-sensitive-volume.py) | Creates and persistently mounts the `~/Code` APFS volume |
| before | [Node.js](../.chezmoiscripts/run_once_before_06-install-nodejs.sh) | Via proto; includes pnpm |
| before | [Global developer tools](../.chezmoiscripts/run_onchange_before_07-reconcile-dev-tools.sh.tmpl) | Global npm tool and Pyright versions declared in [`package.json`](dev-tools/package.json) and [`requirements.txt`](dev-tools/requirements.txt) |
| before | [Rust](../.chezmoiscripts/run_once_before_08-install-rust.sh) | |
| before | [Claude Code](../.chezmoiscripts/run_once_before_09-install-claude-code.sh) | |
| after | [Git config](../.chezmoiscripts/run_onchange_after_01-setup-gitconfig.sh.tmpl) | Regenerates provider configs when rendered inputs change and resolves signing keys from GPG/YubiKey at runtime |
| after | [macOS defaults](../.chezmoiscripts/run_onchange_after_02-setup-macos-defaults.sh.tmpl) | |
| after | [zsh completions](../.chezmoiscripts/run_once_after_03-reload-zsh-completions.sh) | |
| after | [Envchain seed](../.chezmoiscripts/run_onchange_after_04-seed-envchain.sh.tmpl) | Seeds user-managed encrypted values into Keychain namespaces |

`before` scripts run before file sync, `after` scripts run after file sync.

Homebrew autoupdate is a periodic LaunchAgent, so its process does not need to
remain active between runs. `brew autoupdate status` checks the caller's
bootstrap namespace and may report `stopped` from another app even while the
Terminal-installed agent is loaded. Verify the durable GUI-domain state with:

```sh
launchctl print "gui/$(id -u)/com.github.domt4.homebrew-autoupdate"
```

The case-sensitive volume step uses Python's plist parser to find the APFS
container that stores `$HOME`, installs an exact UUID mount through `vifs`, and
refuses to cover a non-empty `~/Code` or automatically unmount a volume from
another path. If it fails, resolve the reported conflict and rerun
`chezmoi apply`; a failed `run_once` is retried, but a successful run does not
reconcile later drift. Its disk-free checks are:

```sh
/usr/bin/python3 .github/tests/setup_case_sensitive_volume_test.py
```

Docker cannot validate macOS APFS or Disk Arbitration. Fresh-machine acceptance
still requires `apply`, a reboot, confirmation that the same volume is mounted
at `~/Code`, and a second no-op `apply`.

[Renovate](renovate.json) checks daily in the `Asia/Singapore` timezone and batches routine updates from every dependency manager, including major updates, into one `All dependencies` PR. Path-scoped CI validates the dependency surfaces changed by that PR. The next `chezmoi apply` installs only missing or mismatched global npm tools and Pyright versions.

Zsh plugins are pinned to upstream commits in [`.chezmoiexternal.toml`](../.chezmoiexternal.toml). [CI](workflows/validate-zsh-plugins.yml) verifies that each pinned archive applies and its entry point loads.

## Contribution Guidelines

If you have any suggestions or issues, feel free to open an [Issue](https://github.com/liby/dotfiles/issues/new) or [Pull Request](https://github.com/liby/dotfiles/pulls).
