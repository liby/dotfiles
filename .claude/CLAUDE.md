Bryan's dotfiles managed by [chezmoi](https://www.chezmoi.io/). Source directory: `~/.local/share/chezmoi`, deploys to `$HOME`.

## Chezmoi Concepts

### Source -> Destination Mapping

- `dot_` prefix -> `.` in destination (e.g., `dot_zshrc` -> `~/.zshrc`)
- `executable_` prefix -> file gets `+x` permission
- `readonly_` prefix -> file is read-only
- `encrypted_` suffix `.asc` -> GPG-encrypted file (decrypted on apply)
- `.tmpl` suffix -> Go template, rendered before deployment
- Files starting with `.` in source (without `dot_` prefix) are **NOT managed** by chezmoi — they are repo-internal files (e.g., `.github/`, `.chezmoiignore`, `.chezmoi.toml.tmpl`)

### Scripts & Ignore

- Script naming in `.chezmoiscripts/` is self-documenting: `run_{once|onchange}_{before|after}_NN-name.sh`
- `run_onchange` scripts use template hash comments to trigger on data file changes (e.g., `# Brewfile hash: {{ include "Brewfile" | sha256sum }}`)
- On a fresh `chezmoi init`, all `run_once` scripts show `R` status — this is expected, not a bug
- `.chezmoiignore` lists source files NOT deployed to `$HOME` (e.g., `Brewfile` is consumed by a run script only)

## Configuration

- GPG encryption with dual Yubikey recipients (see `.chezmoi.toml.tmpl`)

## Workflow

- **Edit source, apply to destination.** chezmoi's data flow is one-way: source -> `$HOME`. Use `chezmoi edit <dest-path>` to open the source file, then `chezmoi apply` to deploy
- **Before committing, run `chezmoi diff`** to check if destination files were edited externally. If only destination changed, `chezmoi re-add` to pull changes back to source. If both source and destination changed, review the diff and ask which version to keep
- **`chezmoi diff` direction: it shows what `chezmoi apply` would do to the destination.** `-` lines are present in `$HOME` but missing from source (apply would remove them); `+` lines are present in source but missing from `$HOME` (apply would add them). Check the source file before concluding which side drifted
- **Encrypted files (`encrypted_*.asc`): keep the commit message generic.** Say only that the file changed (e.g., `update encrypted zshenv`), never what changed inside (env var names, secret purpose). The file is encrypted to stay private on GitHub; a message that describes its contents leaks exactly what the encryption hides
- **`.chezmoi.toml.tmpl` is special — edit the template, then run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`.** Never edit the live config directly: it's a generated artifact, and chezmoi hashes the template to detect drift (warning `config file template has changed, run chezmoi init to regenerate` until `chezmoi init` is run)
- New files: `chezmoi add <file>` (or `--encrypt` for secrets)
- Cross-machine sync: `chezmoi update` on target machine
- Agent skill changes: run `ruby dot_agents/skills/scripts/validate-skills.rb --include-deployed-snow --smoke` before reporting done. The validator checks Claude Code/Codex frontmatter basics, local links, fixed temp-path examples, bash blocks against `allowed-tools`, review shell syntax, and the current help path for CLI-backed skills (`gh`, `glab`, `snow`). Update `CLI_SMOKE_COMMANDS` when adding or removing a CLI skill whose behavior depends on installed help output.

## Design decisions (do not "fix")

These look like config inconsistencies to a cold reader but are intentional. Reviewers and agents: read before proposing changes.

- **`[1m]` model variant + `autoCompactWindow` < 1M** in `dot_claude/settings.json`. The 1M context is chosen for spike headroom, not as the working budget; `autoCompactWindow` (currently 400k) is the intended compact threshold. Since 2026-06-10 the model is `claude-fable-5[1m]`: Fable 5's window is natively 1M per the model docs, so the suffix is redundant-but-accepted there; it stays so the 1M pin survives switching back to Opus/Sonnet variants. Statusline reads 100% at the actual auto-compact trigger point (400k minus `COMPACT_RESERVE=33000` = 367k). Recommended by Claude Code maintainer ([@trq212](https://x.com/trq212/status/1912480953408282856): *"400k context is a good compromise"*). Do not raise `autoCompactWindow` or drop `[1m]` to "make them agree".
- **`statusLine` custom script** at `dot_claude/scripts/executable_statusline.sh` reads effort from stdin `.effort.level` first (CC >= 2.1.121), then falls back to `CLAUDE_CODE_EFFORT_LEVEL` env, then to `effortLevel` in settings. Context % uses `COMPACT_RESERVE=33000` (reverse-engineered from CLI 2.1.150) to align 100% with the actual auto-compact trigger. The 33000 constant is unverified against 2.1.170 (string-grep could not relocate it; re-derive at the next statusline touch), and 2.1.170 adds `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env overrides the script does not read.
- **env flags in `dot_claude/settings.json`** — see `.claude/rules/claude-code-env-flags.md` for verified flag inventory, value format (`mH`/`tK`), GrowthBook gates, and why `effortLevel` must stay as env.
