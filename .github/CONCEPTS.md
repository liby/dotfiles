# Repository concepts

This document explains the repository-specific choices that matter when understanding or adapting this setup. It is not a file inventory or a replacement for the [chezmoi reference](https://www.chezmoi.io/reference/). Source files define behavior; [`AGENTS.md`](../AGENTS.md) defines contributor workflows, safety boundaries, and validation rules.

## Bootstrap

Bootstrap remains interactive because it crosses account-specific input, system-level installation, and hardware-backed GPG keys. Scripts provision tools and machine state that file synchronization alone cannot express.

Scripts in [`.chezmoiscripts`](../.chezmoiscripts/) use `before` and `after` attributes to place ordering dependencies around file synchronization. Their filenames remain the source of truth for order within each phase, while `run_once` and `run_onchange` encode rerun behavior using the standard semantics in [chezmoi's script guide](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/).

Three dependencies shape the sequence:

- Homebrew and [`Brewfile`](../Brewfile) packages provide tools used by later scripts.
- GPG agent and YubiKey public-key setup must finish before encrypted files are synchronized, because chezmoi needs the corresponding private keys during file synchronization.
- A dedicated case-sensitive `Code` volume is provisioned as machine infrastructure rather than managed as a normal file target.

## Configuration ownership

Most source files and templates render to paths under `$HOME`. Standard source names and template mechanics follow chezmoi rather than repository-specific conventions.

Not every configuration is fully replaced. Applications such as Codex and Claude Code write mutable runtime state, so [`modify_` sources](https://www.chezmoi.io/reference/target-types/#modify-file) manage selected fields while preserving application-owned values. Other files are declarations rather than home-directory targets: [`Brewfile`](../Brewfile) drives package installation and the Homebrew autoupdate LaunchAgent, while [`.github/dev-tools`](dev-tools/) declares tools installed by another bootstrap script. The rest of `.github` contains repository-only documentation, tests, and workflows.

## Identity and encrypted data

[`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl) defines prompts for account-specific template values. Each user supplies their own values during `init`; a fork should first review which fields still apply.

Encrypted files use GPG, with private keys stored on a YubiKey. Repository-only encrypted data can seed envchain namespaces in the macOS Keychain instead of deploying credentials as ordinary dotfiles. Adapting the full repository therefore requires replacing or removing its GPG recipients and personal encrypted data.
