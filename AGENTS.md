Dotfiles managed by [chezmoi](https://www.chezmoi.io/) from `~/.local/share/chezmoi` to `$HOME`. Standard source prefixes and template mechanics live in the [chezmoi reference](https://www.chezmoi.io/reference/); this file records only repository-specific workflows and traps.

## Workflow

- After editing `.chezmoi.toml.tmpl`, run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`; never edit that generated file directly.
- On a fresh `chezmoi init`, `R` status for every `run_once` script is expected.
- Before committing, run `chezmoi status --exclude=encrypted <dest-path>` and `chezmoi diff <dest-path>` for each changed non-secret managed target in scope; never run bare `chezmoi status` or `chezmoi diff`, which can generate decrypted target content. Reserve repository-wide status checks for requested drift audits, and report inaccessible targets as gaps in those audits without widening permissions. Read `-` as destination-only and `+` as rendered-target-only. Re-add destination-only drift only when it belongs to the requested change; report unrelated drift without modifying it. When both destination and target changed, show the scoped diff.
- Use `chezmoi merge <dest-path>` only for an explicitly selected non-encrypted, non-`modify_` target; a templated target requires manual review to preserve template directives.
- Fold a follow-up change to the same logical unit into its existing unpushed commit (`git commit --amend` or fixup) instead of appending a commit per request; append-only committing turns one feature into a chain that later needs a history rewrite. Start a new commit only for a separate concern, a pushed base, or another author's commit.
- When retiring or replacing a managed path, verify the exact non-secret destination, then delete the obsolete source and the existing live destination in the same change. Never add `remove_` entries, compatibility readers, or other migration markers; handle any later residue through an explicit audit. In retirement commits, name the affected non-secret target paths or fields, explain why they were removed, and note any local content to preserve.
- For agent skill changes, run `ruby dot_agents/skills/scripts/validate-skills.rb --smoke`. Keep `CLI_SMOKE_COMMANDS` in sync only for skills whose instructions depend on current CLI behavior.
- Preserve order where it affects behavior, including workflow steps and hook lists. When choosing a layout for unordered configuration keys, prefer an established upstream order from the schema, examples, or generated output; otherwise use alphabetical order for small or unrelated sets and functional groups when they aid navigation. Do not reorder an existing file merely to match another one.
- In Markdown source, never hard-wrap prose to a fixed column. Keep each prose paragraph, including the prose portion of a list item or blockquote, on one physical line; when content needs intentional separation, create an explicit Markdown block instead of a soft line break. Preserve separate lines for headings, blank paragraph boundaries, separate list items, table rows, fenced code, and explicit hard breaks ending in two spaces or a backslash.
- After an auto-review denial, state the exact action and risk and retry only after explicit user reapproval. Treat the task-reported approval policy, reviewer, and permission profile as authoritative.

## Encrypted Files

Protect the plaintext boundary, not repository-declared ciphertext. Treat a tracked ciphertext source as an opaque artifact: agents may inspect its metadata and encryption marker and may stage, commit, rename, or delete it when project documentation or the user supplies the change intent. Do not read its body for semantic evidence, infer plaintext changes, or describe them in a commit message. If encryption is not established, stop before reading the body.

- Hand every operation that can expose or derive secret plaintext to the user, including add or re-encrypt from a real secret, decrypt, `chezmoi edit`, `chezmoi re-add`, and `chezmoi merge`. Never run `chezmoi merge` for any encrypted target.
- Add a non-secret encrypted file with `chezmoi add --encrypt <file>`. Edit encrypted non-secret content through `chezmoi edit <dest-path>` or edit its deployed plaintext and run `chezmoi re-add`; never edit an `encrypted_*.asc` source directly. Decryption requires a YubiKey.
- `.secrets/seed.asc` is secret-bearing, repository-only ciphertext for envchain namespaces. The user must edit it with `chezmoi edit-encrypted .secrets/seed.asc` and then run `chezmoi apply ~/.chezmoiscripts/seed-envchain.sh` to reseed the Keychain. The [Credential-backed features](.github/CONCEPTS.md#credential-backed-features) section owns the plaintext format and repository consumer contract.
- A ciphertext source may share a commit with related non-secret changes; it does not require a commit of its own. Whatever the commit shape, describe the ciphertext generically, such as `update encrypted zshenv`: metadata and user-supplied change classification may justify the commit, but describing inferred plaintext changes defeats the encryption boundary.

## Maintenance map

Keep prose only when omission can cause a realistic wrong edit or operation. Place it at the first decision it must change:

| Surface | Owns |
| --- | --- |
| Agent entrypoint | Actions needed before choosing or reading a narrower owner |
| Human setup and reuse | User-facing setup, operation, and adaptation guidance |
| Cross-file contract | Design, lifecycle, and operator rationale that spans sources |
| Path or capability instruction | Instructions needed only when that path or capability is active |
| Exact edit rationale | A non-obvious reason or invalidation condition at that line or block |
| Deterministic requirement | Enforcement that should not depend on Agent recall |

Keep one owner per action. Retain overlap only when each surface constrains a different decision, boundary, or audience, and link rather than restate supporting detail.

This repository targets Apple Silicon macOS only. Use the `/opt/homebrew` prefix directly; do not add Intel `/usr/local` branches until a supported machine requires them.

## Before inspecting, changing, or running a matching surface

Read its narrowest owner, then read the owner for the behavior under test.

| Area | Trigger | Read |
| --- | --- | --- |
| Repository validation | `.github/workflows/**`, `.github/tests/**` | [Repository validation](.github/CONCEPTS.md#repository-validation) |
| Bootstrap and packages | `Brewfile`, `.chezmoiexternal.toml`, `.chezmoiscripts/**`, `.chezmoitemplates/input-source-pro/**`, `.github/dev-tools/**`, `.github/renovate.json`, `dot_config/uv/uv.toml`, `dot_proto/dot_prototools` | [Bootstrap](.github/CONCEPTS.md#bootstrap), [Package and tool ownership](.github/CONCEPTS.md#package-and-tool-ownership); for a script that writes preferences, also [Configuration ownership](.github/CONCEPTS.md#configuration-ownership) |
| Git signing | `dot_config/git/executable_git-ssh-gpg-agent`, `.chezmoitemplates/git/**`, `private_dot_ssh/private_config`, `.chezmoiscripts/run_onchange_after_setup-gitconfig.sh.tmpl` | [Git identity and signing](.github/CONCEPTS.md#git-identity-and-signing) |
| GitLab CLI | `.chezmoiscripts/run_onchange_after_configure-glab.sh`, glab's live configuration | [GitLab CLI configuration](.github/CONCEPTS.md#gitlab-cli-configuration) |
| Codex | `.chezmoitemplates/codex/**`, `dot_codex/**`, `.chezmoiscripts/run_onchange_after_setup-codex-requirements.sh.tmpl`, `~/.codex/config.toml`, the bundled Browser cache | [Codex configuration](.github/CONCEPTS.md#codex-configuration) |
| Claude Code | `.chezmoitemplates/claude/**`, `modify_dot_claude.json`, `dot_claude/**`, `~/.claude/settings.json` | [`.claude/rules/claude-code-settings.md`](.claude/rules/claude-code-settings.md); for changes shared with Codex, also [Shared agent instructions](.github/CONCEPTS.md#shared-agent-instructions) |
| Shared agent instructions | `.chezmoitemplates/agents/**`, `dot_claude/CLAUDE.md.tmpl`, `dot_codex/AGENTS.md.tmpl`, `private_dot_pi/private_agent/private_AGENTS.md.tmpl` | [Shared agent instructions](.github/CONCEPTS.md#shared-agent-instructions), then the runtime-specific owner for every root template in scope |
| Pi | `.chezmoitemplates/pi/**`, `private_dot_pi/**`, `~/.pi/agent/**` | [Pi configuration](.github/CONCEPTS.md#pi-configuration) |
| Oracle | `private_dot_oracle/**`, `~/.oracle/config.json` | [Oracle configuration](.github/CONCEPTS.md#oracle-configuration). Treat the deployed file as credential-bearing: inspect the overlay source, and do not read, diff, or re-add the destination |
| Herdr integrations | `.chezmoiscripts/run_onchange_after_install-herdr-integrations.sh.tmpl` | [Herdr integrations](.github/CONCEPTS.md#herdr-integrations) |
| Managed skills | `dot_agents/skills/**`, `~/.agents/skills/**` | `write-skill` and [Managed skill registry](.github/CONCEPTS.md#managed-skill-registry); for `dot_agents/skills/snow/**`, also [Shared agent execution](.github/CONCEPTS.md#shared-agent-execution) |
| Credentials | `.chezmoi.toml.tmpl`, `.secrets/**`, `.chezmoiscripts/run_onchange_after_seed-envchain.sh.tmpl`, any source that invokes `envchain` | [Identity and encrypted data](.github/CONCEPTS.md#identity-and-encrypted-data) and the [Credential-backed features](.github/CONCEPTS.md#credential-backed-features) consumer contract. [Encrypted Files](#encrypted-files) remains authoritative for plaintext and ciphertext handling |
