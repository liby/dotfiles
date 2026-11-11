# Setup

The full setup targets Apple Silicon Macs. Before installing, compare your macOS major version with [the version set checked at the start of `main()` in the notification script](../.chezmoiscripts/run_after_setup-macos-notifications.py).

Some settings depend on my accounts, GPG keys, and filesystem layout. Adjust them for a different environment.

## Adapt it

Copy only the parts you need, or fork this repository to adapt the full setup. Before applying a fork, review and adjust `.chezmoi.toml.tmpl`, `Brewfile`, and `.chezmoiscripts/`. The encrypted `*.asc` files decrypt only with my YubiKey, so [replace the ciphertext and the GPG recipients](CONCEPTS.md#identity-and-encrypted-data) with your own, or remove them along with the parts that use them; the recipients are declared in `.chezmoi.toml.tmpl`. Some features read credentials from [Maskey](https://github.com/Entwining/maskey): create [the entries they use](CONCEPTS.md#credential-backed-features) in your own Maskey, or switch those features to a similar tool you use. The commands below apply my complete setup; use your fork's repository name when installing your adapted version.

## Set up a new Mac

Open Terminal.app on the new Mac and install Apple's [Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/) before cloning this repository:

```sh
xcode-select --install
```

Wait for the installer window to finish, then confirm `xcode-select -p` and `git --version` both print something.

Sign in to the App Store before continuing so `Brewfile` can install its apps under [mas's account requirements](https://github.com/mas-cli/mas#app-store-apple-account-requirements). Turn on iCloud Keychain for the same Apple Account as your other Macs, so the [credentials in Maskey](CONCEPTS.md#credential-backed-features) reach this Mac before setup reads them. Keep Terminal.app open to enter private template values, respond to `sudo` prompts, use your YubiKey when needed, and finish the GitLab sign-in that opens in your browser.

Before running the setup command, grant Terminal.app Full Disk Access in System Settings > Privacy & Security > Full Disk Access for [automatic notification preferences](CONCEPTS.md#configuration-ownership). The terminal running later applies needs the same permission; without it, apply stops at the notification step and names the app to turn on. Apps that register for notifications later are configured on the next apply.

Install the full setup with [chezmoi's bootstrap command](https://www.chezmoi.io/user-guide/daily-operations/#install-chezmoi-and-your-dotfiles-on-a-new-machine-with-a-single-command):

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$(mktemp -d)" init --apply liby
```

`-b` keeps the bootstrap binary temporary; `Brewfile` owns the chezmoi installation used and updated afterwards.

If setup fails, resolve the reported error and rerun the same command to continue under [chezmoi's script lifecycle](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/).

If chezmoi is already installed, run:

```sh
chezmoi init --apply liby
```

After setup, run `gh auth login`: Git uses that sign-in over HTTPS to push to GitHub and to fetch private repositories, and the background upgrade job updates gh extensions only with it.

If you use [Rex](https://www.superlogical.com/rex), install and open it manually, then run `setup-rex` once from an ordinary Rex pane. Rex settings that `chezmoi apply` writes take effect after you reopen the app.

## Common operations

Use [chezmoi's daily workflow](https://www.chezmoi.io/user-guide/daily-operations/) to edit and apply managed files. When troubleshooting this repository's bootstrap, run `chezmoi apply -v` to stream each script step's full output.

[Editing encrypted files](https://www.chezmoi.io/reference/commands/edit-encrypted/) requires a YubiKey and should not be delegated to an agent.

## Update an existing Mac

When updating an existing Mac or merging upstream into a fork, review commits since the version last applied on that machine for retired paths and fields. Check their current contents before removing them, keeping any local changes you still need. Applying the new source [does not clean up all retired configuration](CONCEPTS.md#configuration-ownership), even when `chezmoi status` is empty.

If `.chezmoi.toml.tmpl` changed, run [`chezmoi init`](https://www.chezmoi.io/reference/commands/init/) before applying to regenerate this machine's configuration.
