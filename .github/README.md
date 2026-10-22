<h4 align="right"><strong>English</strong> | <a href="README_CN.md">简体中文</a></h4>

# My Dotfiles

These dotfiles configure my macOS development environment and stay in sync across my Macs with [chezmoi](https://www.chezmoi.io/). The repository also includes bootstrap scripts for setting up a new Mac.

This setup supports Apple Silicon Macs only; Intel Macs are not supported.

Some settings depend on my accounts, GPG keys, and filesystem layout. Adjust them for a different environment.

## Scope

This repository keeps my Macs in sync, sets up a new Mac, and configures the coding agents I work with: their shared instructions, skills, sandboxes, and guards. It deliberately leaves out:

- Unattended setup; see [Set up a new Mac](#set-up-a-new-mac).
- Drift repair: a bootstrap script runs again only when its rendered content changes, so a tool removed by hand or a YubiKey holding a different key stays that way until that script runs again; [Bootstrap](CONCEPTS.md#bootstrap) shows how to rerun one.
- Cleanup of retired configuration on machines that applied it earlier; see [Updating existing machines](#updating-existing-machines).
- One pinned snapshot of every tool: coding agents, Homebrew packages, and self-updating apps follow their own update channels, and only the background development tools are pinned; see [Package and tool ownership](CONCEPTS.md#package-and-tool-ownership).
- Application runtime state and sign-in sessions, which stay with the applications that write them; see [Configuration ownership](CONCEPTS.md#configuration-ownership).

## Project overview

| Area | Start with |
| --- | --- |
| Agent tooling | [`dot_agents`](../dot_agents/), [`dot_claude`](../dot_claude/), [`dot_codex`](../dot_codex/), [`private_dot_pi`](../private_dot_pi/), [`.chezmoitemplates/agents`](../.chezmoitemplates/agents/) |
| Git | [`dot_config/git`](../dot_config/git/), [`.chezmoitemplates/git`](../.chezmoitemplates/git/) |
| Repository design | [`CONCEPTS.md`](CONCEPTS.md) |
| Packages and bootstrap | [`Brewfile`](../Brewfile), [`.chezmoiscripts`](../.chezmoiscripts/) |
| Shell and applications | [`dot_zshenv`](../dot_zshenv), [`dot_zprofile`](../dot_zprofile), [`dot_zshrc`](../dot_zshrc), [`dot_zsh`](../dot_zsh/), [`dot_config`](../dot_config/) |
| chezmoi configuration and templates | [`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl), [`.chezmoitemplates`](../.chezmoitemplates/) |

## Set up a new Mac

A fresh macOS install ships `git` as a stub that only opens the Command Line Tools installer dialog and exits with an error, so `chezmoi init` cannot clone this repository yet. Open Terminal.app on the new Mac and install the tools first:

```sh
xcode-select --install
```

Wait for the installer window to finish, then confirm `xcode-select -p` and `git --version` both print something. Now run:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$(mktemp -d)" init --apply liby
```

This starts an interactive setup, not an unattended installation. Sign in to the App Store first, because `Brewfile` installs App Store apps through `mas`, which needs a signed-in account. Keep Terminal.app open to enter private template values, respond to `sudo` prompts, use your YubiKey when needed, and finish the GitLab sign-in that opens in your browser. Afterwards, run `gh auth login`: Git uses that sign-in over HTTPS to push to GitHub and to fetch private repositories, and the background upgrade job updates gh extensions only with it.

The command installs chezmoi, clones this repository into `~/.local/share/chezmoi`, runs the bootstrap scripts, and applies the managed files to `$HOME`. `-b` puts that first binary in a temporary directory instead of the `bin` directory the install script creates in the working directory, which in Terminal.app is `~/bin`: `Brewfile` installs the chezmoi every later command should use, so a copy left there would only linger and never update.

A bootstrap script that fails stops the apply. Run the same one-liner again to continue; it reinstalls chezmoi into a new temporary directory and picks up where the failed run left off.

If chezmoi is already installed, run:

```sh
chezmoi init --apply liby
```

Install Rex, the terminal in which agents open panes you can watch, by hand. Open it and run `setup-rex`, which imports its theme and installs Rex's skill for the coding agents. `chezmoi apply` also writes Rex's other settings, which take effect after you reopen the app.

## Common operations

```sh
chezmoi status                     # Show configuration status
chezmoi diff <target>              # Inspect changes to one configuration file
chezmoi apply                      # Apply configuration to $HOME
chezmoi apply -v                   # Also show file diffs and each script step's full output
chezmoi edit <target>              # Edit a managed file (pass its target path)
chezmoi edit-encrypted <filename>  # Edit an encrypted file (pass its source path)
```

Editing encrypted files requires a YubiKey and should not be delegated to an agent.

See chezmoi's [daily operations guide](https://www.chezmoi.io/user-guide/daily-operations/) for other commands.

## Updating existing machines

When updating an existing Mac or merging upstream into a fork, review commits since the version last applied on that machine for retired paths and fields. Check their current contents before removing them, keeping any local changes you still need. Applying the new source [does not clean up all retired configuration](CONCEPTS.md#configuration-ownership), even when `chezmoi status` is empty.

## Reuse

Fork this repository and adapt it to your environment, or copy only the parts you need. Before applying the full setup, review and adjust `.chezmoi.toml.tmpl`, `Brewfile`, and `.chezmoiscripts/`. The encrypted `*.asc` files decrypt only with my YubiKey, so replace them and the GPG recipients in `.chezmoi.toml.tmpl` with your own, or remove them along with the parts that use them; see [Identity and encrypted data](CONCEPTS.md#identity-and-encrypted-data).

## Contributing

Before changing this repository, read [`AGENTS.md`](../AGENTS.md) for repository-specific workflows, safety boundaries, and validation rules. Open an [issue](https://github.com/liby/dotfiles/issues/new) to report a problem or a [pull request](https://github.com/liby/dotfiles/pulls) to propose a change.
