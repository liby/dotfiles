Bryan's dotfiles managed by [chezmoi](https://www.chezmoi.io/). Source directory: `~/.local/share/chezmoi`, deploys to `$HOME`.

## Chezmoi Concepts

### Source → Destination Mapping

- `dot_` prefix → `.` in destination (e.g., `dot_zshrc` → `~/.zshrc`)
- `executable_` prefix → file gets `+x` permission
- `readonly_` prefix → file is read-only
- `encrypted_` suffix `.asc` → GPG-encrypted file (decrypted on apply)
- `.tmpl` suffix → Go template, rendered before deployment
- Files starting with `.` in source (without `dot_` prefix) are **NOT managed** by chezmoi — they are repo-internal files (e.g., `.github/`, `.chezmoiignore`, `.chezmoi.toml.tmpl`)

### Scripts & Ignore

- Script naming in `.chezmoiscripts/` is self-documenting: `run_{once|onchange}_{before|after}_NN-name.sh`
- `run_onchange` scripts use template hash comments to trigger on data file changes (e.g., `# Brewfile hash: {{ include "Brewfile" | sha256sum }}`)
- On a fresh `chezmoi init`, all `run_once` scripts show `R` status — this is expected, not a bug
- `.chezmoiignore` lists source files NOT deployed to `$HOME` (e.g., `Brewfile` is consumed by a run script only)

## Configuration

- GPG encryption with dual Yubikey recipients (see `.chezmoi.toml.tmpl`)

## Workflow

- **Edit source, apply to destination.** chezmoi's data flow is one-way: source → `$HOME`. Use `chezmoi edit <dest-path>` to open the source file, then `chezmoi apply` to deploy
- Destination files are often edited directly (e.g., Claude Code editing `~/.claude/CLAUDE.md`). A git pre-commit hook runs `chezmoi re-add` automatically, so commits always include the latest destination changes
- New files: `chezmoi add <file>` (or `--encrypt` for secrets)
- Cross-machine sync: `chezmoi update` on target machine
