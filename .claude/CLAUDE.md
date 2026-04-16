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
- **Before committing, run `chezmoi diff`** to check if destination files were edited externally. If only destination changed, `chezmoi re-add` to pull changes back to source. If both source and destination changed, review the diff and ask which version to keep
- **`.chezmoi.toml.tmpl` is special — edit the template, then run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`.** Never edit the live config directly: it's a generated artifact, and chezmoi hashes the template to detect drift (warning `config file template has changed, run chezmoi init to regenerate` until `chezmoi init` is run)
- New files: `chezmoi add <file>` (or `--encrypt` for secrets)
- Cross-machine sync: `chezmoi update` on target machine

## Design decisions (do not "fix")

These look like config inconsistencies to a cold reader but are intentional. Reviewers and agents: read before proposing changes.

- **`[1m]` model variant + `autoCompactWindow` < 1M** in `dot_claude/settings.json`. The 1M context is chosen for spike headroom, not as the working budget; `autoCompactWindow` (currently 400k) is the intended compact threshold — statusline should read 100% there. Recommended by Claude Code maintainer ([@trq212](https://x.com/trq212/status/1912480953408282856): *"400k context is a good compromise"*). Do not raise `autoCompactWindow` or drop `[1m]` to "make them agree".
- **`CLAUDE_CODE_EFFORT_LEVEL` set via `env` (not `effortLevel`)** in `dot_claude/settings.json`. Env takes precedence over `effortLevel` and over `/effort` mid-session. This is intentional: on the current model's first launch, `effortLevel` in settings is shadowed by the model's hardcoded launch-default (CLI's `UhH()` resolver has a `q ? K` branch keyed on specific model IDs) until session state "unpins". Env sidesteps that. Accepted trade-off: `/effort` can't override live; restart to change.
- **`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`** in `dot_claude/settings.json`. No-op under current model (CLI hardcodes the env to only apply when model contains `opus-4-6` or `sonnet-4-6`). Kept for future 4.6-series use; do not remove.
- **`statusLine` custom script** at `dot_claude/scripts/executable_statusline.sh` reads `CLAUDE_CODE_EFFORT_LEVEL` env first, then falls back to `effortLevel` only when env is truly unset (not when it's `auto`/`unset`/empty, which are explicit "use model default" overrides per CLI's `MYH()`).
