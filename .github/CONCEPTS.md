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

### Credential-backed features

The [seeding script](../.chezmoiscripts/run_onchange_after_04-seed-envchain.sh.tmpl) reads `.secrets/seed.asc` and stores each entry in the macOS Keychain through envchain. The template below lists only entries consumed by files in this repository.

```toml
# Used for Claude Code gateway mode.
[claude-gateway]
ANTHROPIC_AUTH_TOKEN = "replace-with-value"
ANTHROPIC_VERTEX_BASE_URL = "replace-with-value"
ANTHROPIC_VERTEX_PROJECT_ID = "replace-with-value"
CLAUDE_CODE_SKIP_VERTEX_AUTH = "1"
CLAUDE_CODE_USE_VERTEX = "1"

# Used for optional Context7 authentication.
[context7]
CONTEXT7_API_KEY = "replace-with-value"

# Used for the Pi rc-gateway provider.
[pi]
RC_GATEWAY_API_KEY = "replace-with-value"
```

The [Claude launcher](../dot_zsh/functions/claude) injects the `claude-gateway` namespace only in gateway mode. The [Codex configuration](../.chezmoitemplates/codex/config.toml) launches the Context7 MCP through the `context7` namespace, and the [Claude instructions](../dot_claude/CLAUDE.md) route Context7 CLI calls through the same namespace. The [Pi model configuration](../private_dot_pi/private_agent/private_models.json.tmpl) reads `RC_GATEWAY_API_KEY` from the `pi` namespace.
