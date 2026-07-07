Bryan's dotfiles managed by [chezmoi](https://www.chezmoi.io/). Source directory: `~/.local/share/chezmoi`, deploys to `$HOME`. Standard chezmoi mechanics (source-state prefixes like `dot_`/`executable_`/`encrypted_`, `.tmpl` templates, `.chezmoiscripts/` naming, `.chezmoiignore`) are in the [chezmoi reference](https://www.chezmoi.io/reference/); this file records only project specifics and known traps.

## Workflow

- Edit source, then apply: data flow is one-way, source -> `$HOME`. `chezmoi edit <dest-path>` opens the source file, `chezmoi apply` deploys, `chezmoi add <file>` brings a new file under management.
- `.chezmoi.toml.tmpl` is the one file with an extra step: after editing it, run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`. Never edit that live config directly; it is a generated artifact, and chezmoi warns about template drift until re-init.
- `Brewfile` is not deployed (listed in `.chezmoiignore`); a `run_onchange` script consumes it at apply time, retriggered by a template hash comment on its content.
- On a fresh `chezmoi init`, all `run_once` scripts showing `R` status is expected, not a bug.
- Before committing, run `chezmoi diff` to catch external edits to destination files: destination-only drift -> `chezmoi re-add`; both sides changed -> show the diff and ask which version to keep. Read the output as "what `chezmoi apply` would do": `-` lines exist only in `$HOME` (apply would remove them), `+` lines only in source (apply would add them); check the source file before concluding which side drifted.
- Agent skill changes: run `ruby dot_agents/skills/scripts/validate-skills.rb --smoke` before reporting done. Update `CLI_SMOKE_COMMANDS` in it when adding or removing a CLI-backed skill.

## Encrypted files

GPG-encrypted to dual Yubikey recipients (config in `.chezmoi.toml.tmpl`). The `encrypted_*.asc` sources are ciphertext, so every touchpoint differs from plain files:

- Adding: `chezmoi add --encrypt <file>`.
- Editing: never edit the `.asc` source directly. `chezmoi edit <dest-path>` decrypts to a private temp file, opens the editor (`code --wait` here), and re-encrypts on exit; decryption needs a Yubikey present. Editing the destination plaintext then `chezmoi re-add` also re-encrypts. Secret-bearing files (`.env`, ssh keys): agents hand the edit to the user (`! chezmoi edit <path>`); encrypted skills are agent-editable via their deployed plaintext plus `re-add`.
- Diffing: scope to one file, `chezmoi diff <dest-path>`. Bare `chezmoi diff` decrypts every encrypted file inline, rendering secrets (e.g. tokens in `~/.config/claude-code/.env`) into the terminal and any agent's context.
- Committing: keep messages generic (`update encrypted zshenv`). Describing what changed inside leaks exactly what the encryption hides.

## Design decisions (do not "fix")

These look like config inconsistencies to a cold reader but are intentional; read before proposing changes.

- **`[1m]` model suffix + `autoCompactWindow: 400000`** in `dot_claude/settings.json`: the 1M context window is spike headroom, not the working budget; 400k is the intended compact threshold (recommended by a Claude Code maintainer, [@trq212](https://x.com/trq212/status/1912480953408282856)). The `[1m]` suffix is load-bearing: it opts the model into the 1M-context beta, and it stays across model switches so the pin survives models whose native window is smaller. Do not raise `autoCompactWindow` or drop `[1m]` to reconcile the two.
- **Statusline script** (`dot_claude/scripts/executable_statusline.sh`): context % uses `COMPACT_RESERVE=33000`, reverse-engineered from the CLI binary so that 100% lands on the actual auto-compact trigger (`autoCompactWindow` minus the reserve). Re-derive the constant whenever touching the script; the script also ignores the `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env overrides.
- **env flags in `dot_claude/settings.json`**: read `.claude/rules/claude-code-env-flags.md` (per-flag rationale, parser value formats, GrowthBook gate mechanics) before adding, removing, or normalizing any of them.
- **Flat skill registry**: the filesystem under `dot_agents/skills` is the only skill registry. Do not add index READMEs, manifests, or topical bucket folders: chezmoi mirrors source paths into `~/.agents/skills`, and Claude Code only scans the top level of a skills directory, so any non-ignored subfolder makes the skills inside it undiscoverable.
