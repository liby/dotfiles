Dotfiles managed by [chezmoi](https://www.chezmoi.io/) from `~/.local/share/chezmoi` to `$HOME`. Standard source prefixes and template mechanics live in the [chezmoi reference](https://www.chezmoi.io/reference/); this file records only repository-specific workflows and traps.

## Workflow

- After editing `.chezmoi.toml.tmpl`, run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`; never edit that generated file directly.
- Edit `Brewfile` in source. It is ignored for deployment and consumed by a `run_onchange` script whose template hash retriggers on content changes.
- On a fresh `chezmoi init`, `R` status for every `run_once` script is expected.
- Before committing, run `chezmoi status --exclude=encrypted`; plain `chezmoi status` generates encrypted target state and can expose decrypted content. For each changed non-secret target in scope, run `chezmoi diff <dest-path>`; never run bare `chezmoi diff`. Read `-` as destination-only and `+` as rendered-target-only. Re-add destination-only drift only when it belongs to the requested change; report unrelated drift without modifying it. When both destination and target changed, show the scoped diff. Use `chezmoi merge <dest-path>` only for an explicitly selected non-secret, non-`modify_` target; a templated target requires manual review to preserve template directives.
- For agent skill changes, run `ruby dot_agents/skills/scripts/validate-skills.rb --smoke`. Keep `CLI_SMOKE_COMMANDS` in sync only for skills whose instructions depend on current CLI help.

## Encrypted Files

Agents may handle encrypted non-secret files. Hand every secret-bearing add, edit, diff, merge, re-add, and decrypt operation to the user without reading deployed plaintext. Never run `chezmoi merge` for an encrypted target.

- Add a non-secret encrypted file with `chezmoi add --encrypt <file>`.
- Edit encrypted non-secret content through `chezmoi edit <dest-path>` or edit its deployed plaintext and run `chezmoi re-add`; never edit an `encrypted_*.asc` source directly. Decryption requires a Yubikey.
- Keep encrypted-file commit messages generic, such as `update encrypted zshenv`; describing plaintext changes defeats the encryption boundary.

## Project Invariants

Keep only non-obvious, durable relationships that name the harmful "fix" they prevent; otherwise rewrite or delete them.

- **Claude settings, model/context pins, compact-window math, statusline calculations, managed keys**: read `.claude/rules/claude-code-env-flags.md` and adjacent source comments before changing any of them; they own per-flag rationale, parser value formats, provider branches, runtime-owned keys, and intentional feature disables.
- **Codex partial config ownership and desktop write-backs**: `.chezmoitemplates/codex-config.toml` is the managed fragment; `dot_codex/modify_private_config.toml` recursively overwrites only values declared there and replaces `plugins` as a whole, leaving undeclared project trust and machine-local state untouched. Preserve `desktop.followUpQueueMode = "steer"`, `features.js_repl = false`, and `mcp_servers.node_repl.command = "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node_repl"` in the fragment. The CLI removes and ignores `js_repl`, but Codex App startup sync currently restores `false` when the key is absent, so deleting it creates recurring target drift rather than meaningful cleanup; see [openai/codex#24387](https://github.com/openai/codex/issues/24387#issuecomment-4531286877).
- **Flat skill registry**: the filesystem under `dot_agents/skills` is the only skill registry. Do not add index READMEs, manifests, or topical bucket folders: chezmoi mirrors source paths into `~/.agents/skills`, and Claude Code only scans the top level of a skills directory, so any non-ignored subfolder makes the skills inside it undiscoverable.
