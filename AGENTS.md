Dotfiles managed by [chezmoi](https://www.chezmoi.io/) from `~/.local/share/chezmoi` to `$HOME`. Standard source prefixes and template mechanics live in the [chezmoi reference](https://www.chezmoi.io/reference/); this file records only repository-specific workflows and traps.

## Workflow

- After editing `.chezmoi.toml.tmpl`, run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`; never edit that generated file directly.
- Edit `Brewfile` in source. It is ignored for deployment and consumed by a `run_onchange` script whose template hash retriggers on content changes.
- Number scripts independently within the `before`, unqualified update, and `after` phases using contiguous two-digit prefixes. Renumber a phase when inserting a script instead of reserving numeric gaps.
- On a fresh `chezmoi init`, `R` status for every `run_once` script is expected.
- Before committing, run `chezmoi status --exclude=encrypted`; plain `chezmoi status` generates encrypted target state and can expose decrypted content. For each changed non-secret target in scope, run `chezmoi diff <dest-path>`; never run bare `chezmoi diff`. Read `-` as destination-only and `+` as rendered-target-only. Re-add destination-only drift only when it belongs to the requested change; report unrelated drift without modifying it. When both destination and target changed, show the scoped diff.
- Use `chezmoi merge <dest-path>` only for an explicitly selected non-secret, non-`modify_` target; a templated target requires manual review to preserve template directives.
- Fold a follow-up change to the same logical unit into its existing unpushed commit (`git commit --amend` or fixup) instead of appending a commit per request; append-only committing turns one feature into a chain that later needs a history rewrite. Start a new commit only for a separate concern, a pushed base, or another author's commit.
- When retiring or replacing a managed path, verify the exact non-secret destination, then delete the obsolete source and the existing live destination in the same change. Never add `remove_` entries, compatibility readers, or other migration markers; handle any later residue through an explicit audit.
- For agent skill changes, run `ruby dot_agents/skills/scripts/validate-skills.rb --smoke`. Keep `CLI_SMOKE_COMMANDS` in sync only for skills whose instructions depend on current CLI behavior.
- In Markdown source, never hard-wrap prose to a fixed column. Keep each prose paragraph, including the prose portion of a list item or blockquote, on one physical line; when content needs intentional separation, create an explicit Markdown block instead of a soft line break. Preserve separate lines for headings, blank paragraph boundaries, separate list items, table rows, fenced code, and explicit hard breaks ending in two spaces or a backslash.
- After an auto-review denial, state the exact action and risk and retry only after explicit user reapproval. Treat the task-reported approval policy, reviewer, and permission profile as authoritative.

## Encrypted Files

Protect the plaintext boundary, not repository-declared ciphertext. Treat a tracked ciphertext source as an opaque artifact: agents may inspect its metadata and encryption marker and may stage, commit, rename, or delete it when project documentation or the user supplies the change intent. Do not read its body for semantic evidence, infer plaintext changes, or describe them in a commit message. If encryption is not established, stop before reading the body.

- Hand every operation that can expose or derive secret plaintext to the user, including add or re-encrypt from a real secret, decrypt, `chezmoi edit`, `chezmoi re-add`, and `chezmoi merge`. Never run `chezmoi merge` for any encrypted target.
- Add a non-secret encrypted file with `chezmoi add --encrypt <file>`. Edit encrypted non-secret content through `chezmoi edit <dest-path>` or edit its deployed plaintext and run `chezmoi re-add`; never edit an `encrypted_*.asc` source directly. Decryption requires a YubiKey.
- `.secrets/seed.asc` is secret-bearing, repository-only ciphertext for envchain namespaces. The user must edit it with `chezmoi edit-encrypted .secrets/seed.asc` and then run `chezmoi apply ~/.chezmoiscripts/04-seed-envchain.sh` to reseed the Keychain. The [Credential-backed features](.github/CONCEPTS.md#credential-backed-features) section owns the plaintext format and repository consumer contract.
- A ciphertext source may share a commit with related non-secret changes; it does not require a commit of its own. Whatever the commit shape, describe the ciphertext generically, such as `update encrypted zshenv`: metadata and user-supplied change classification may justify the commit, but describing inferred plaintext changes defeats the encryption boundary.

## Maintenance map

Keep prose only when omission can cause a realistic wrong edit or operation. Place it at the first decision it must change:

- **Agent entrypoint**: This file owns actions needed before choosing or reading a narrower owner.
- **Human setup and reuse**: The READMEs own user-facing setup, operation, and adaptation guidance.
- **Cross-file contract**: [`.github/CONCEPTS.md`](.github/CONCEPTS.md) owns design, lifecycle, and operator rationale that spans sources.
- **Path or capability instruction**: The narrowest path rule or skill owns instructions needed only when that path or capability is active.
- **Exact edit rationale**: An adjacent comment owns a non-obvious reason or invalidation condition needed at that line or block.
- **Deterministic requirement**: A schema, test, or hook owns enforcement that should not depend on Agent recall.

Keep one owner per action. Retain overlap only when each surface constrains a different decision, boundary, or audience, and link rather than restate supporting detail.

This repository targets Apple Silicon macOS only. Use the `/opt/homebrew` prefix directly; do not add Intel `/usr/local` branches until a supported machine requires them.

Before inspecting, changing, or running a matching surface, read its narrowest owner:

- **Repository validation**: For `.github/workflows/**` or `.github/tests/**`, read [Repository validation](.github/CONCEPTS.md#repository-validation), then read the owner for the behavior under test.
- **Bootstrap and packages**: For `Brewfile`, `.chezmoiexternal.toml`, `.chezmoiscripts/**`, `.github/dev-tools/**`, `.github/renovate.json`, or `dot_config/git/executable_git-ssh-gpg-agent`, read [Bootstrap](.github/CONCEPTS.md#bootstrap) and [Package and tool ownership](.github/CONCEPTS.md#package-and-tool-ownership).
- **GitLab CLI**: For `.chezmoiscripts/run_onchange_after_05-configure-glab.sh` or glab's live configuration, also read [GitLab CLI configuration](.github/CONCEPTS.md#gitlab-cli-configuration).
- **Codex**: For `.chezmoitemplates/codex/**`, `dot_codex/**`, `~/.codex/config.toml`, or the bundled Browser cache, read [Codex configuration](.github/CONCEPTS.md#codex-configuration).
- **Claude Code**: For `.chezmoitemplates/claude/**`, `modify_dot_claude.json`, `dot_claude/**`, or `~/.claude/settings.json`, read [`.claude/rules/claude-code-settings.md`](.claude/rules/claude-code-settings.md). For changes shared with Codex, also read [Shared agent execution](.github/CONCEPTS.md#shared-agent-execution).
- **Pi**: For `.chezmoitemplates/pi/**`, `private_dot_pi/**`, or `~/.pi/agent/**`, read [Pi configuration](.github/CONCEPTS.md#pi-configuration).
- **Managed skills**: For `dot_agents/skills/**` or `~/.agents/skills/**`, use `write-skill` and read [Managed skill registry](.github/CONCEPTS.md#managed-skill-registry) before editing. For `dot_agents/skills/snow/**`, also read [Shared agent execution](.github/CONCEPTS.md#shared-agent-execution).
- **Credentials**: Before inspecting or changing `.chezmoi.toml.tmpl`, `.secrets/**`, `.chezmoiscripts/run_onchange_after_04-seed-envchain.sh.tmpl`, or any source that invokes `envchain`, read [Identity and encrypted data](.github/CONCEPTS.md#identity-and-encrypted-data) and the [Credential-backed features](.github/CONCEPTS.md#credential-backed-features) consumer contract. [Encrypted Files](#encrypted-files) remains authoritative for plaintext and ciphertext handling.
