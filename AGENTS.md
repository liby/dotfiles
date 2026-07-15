Dotfiles managed by [chezmoi](https://www.chezmoi.io/) from `~/.local/share/chezmoi` to `$HOME`. Standard source prefixes and template mechanics live in the [chezmoi reference](https://www.chezmoi.io/reference/); this file records only repository-specific workflows and traps.

## Workflow

- After editing `.chezmoi.toml.tmpl`, run `chezmoi init` to regenerate `~/.config/chezmoi/chezmoi.toml`; never edit that generated file directly.
- Edit `Brewfile` in source. It is ignored for deployment and consumed by a `run_onchange` script whose template hash retriggers on content changes.
- Number scripts independently within the `before`, unqualified update, and `after` phases using contiguous two-digit prefixes. Renumber a phase when inserting a script instead of reserving numeric gaps.
- On a fresh `chezmoi init`, `R` status for every `run_once` script is expected.
- Before committing, run `chezmoi status --exclude=encrypted`; plain `chezmoi status` generates encrypted target state and can expose decrypted content. For each changed non-secret target in scope, run `chezmoi diff <dest-path>`; never run bare `chezmoi diff`. Read `-` as destination-only and `+` as rendered-target-only. Re-add destination-only drift only when it belongs to the requested change; report unrelated drift without modifying it. When both destination and target changed, show the scoped diff.
- Use `chezmoi merge <dest-path>` only for an explicitly selected non-secret, non-`modify_` target; a templated target requires manual review to preserve template directives.
- For agent skill changes, run `ruby dot_agents/skills/scripts/validate-skills.rb --smoke`. Keep `CLI_SMOKE_COMMANDS` in sync only for skills whose instructions depend on current CLI help.

## Encrypted Files

Protect the plaintext boundary, not repository-declared ciphertext. Treat a tracked ciphertext source as an opaque artifact: agents may inspect its metadata and encryption marker and may stage, commit, rename, or delete it when project documentation or the user supplies the change intent. Do not read its body for semantic evidence, infer plaintext changes, or describe them in a commit message. If encryption is not established, stop before reading the body.

- Hand every operation that can expose or derive secret plaintext to the user, including add or re-encrypt from a real secret, decrypt, `chezmoi edit`, `chezmoi re-add`, and `chezmoi merge`. Never run `chezmoi merge` for any encrypted target.
- Add a non-secret encrypted file with `chezmoi add --encrypt <file>`. Edit encrypted non-secret content through `chezmoi edit <dest-path>` or edit its deployed plaintext and run `chezmoi re-add`; never edit an `encrypted_*.asc` source directly. Decryption requires a Yubikey.
- `.secrets/seed.asc` is secret-bearing, repository-only ciphertext for envchain namespaces. The user must edit it with `chezmoi edit-encrypted .secrets/seed.asc` and then run `chezmoi apply ~/.chezmoiscripts/05-seed-envchain.sh` to reseed the Keychain. Its plaintext is TOML with one top-level table per namespace and one environment variable per single-line string value; quote numeric and boolean-looking values too.

  ```toml
  [service]
  API_KEY = "replace-with-value"
  ```
- Keep ciphertext-only commit messages generic, such as `update encrypted zshenv`; metadata and user-supplied change classification may justify the commit, but describing inferred plaintext changes defeats the encryption boundary.

## Project Invariants

Keep only non-obvious, durable relationships that name the harmful "fix" they prevent; otherwise rewrite or delete them.

- **Codex App write-backs**: Enable Computer Use only through `plugins."computer-use@openai-bundled"` and leave App-owned `mcp_servers.computer-use` unmanaged. Keep `desktop.followUpQueueMode = "steer"`, `features.js_repl = false`, and the managed `mcp_servers.node_repl.command`. Codex CLI ignores `js_repl`, but the App restores `false` when absent, so removing it causes recurring drift; see [openai/codex#24387](https://github.com/openai/codex/issues/24387#issuecomment-4531286877).
- **Codex unattended approvals**: Keep `approval_policy = "on-request"`, `approvals_reviewer = "auto_review"`, and custom `default_permissions = "development"` together. Auto-review only replaces the human reviewer for escalation requests; an effective task policy of `never` produces no requests to review. Treat the task-reported policy as authoritative when it differs from the config file, and do not use `:danger-full-access` to suppress prompts.
- **Codex filesystem blacklist**: Keep the custom `development` profile standalone with `:root = write` and explicit credential and workspace environment-file denies. Do not extend `:workspace`, mirror per-tool cache allowlists, or add command `allow` rules for routine workflows: inherited protected paths recreate special cases, while command rules execute outside the sandbox and bypass filesystem denies. Filesystem capability does not authorize state-changing Git or secret-bearing chezmoi operations.
- **Codex direct networking**: Keep `features.network_proxy = false` with `permissions.development.network.enabled = true`; this leaves public and local networking direct while the permission profile still enforces filesystem access. Add proxy-only `domains` and `allow_local_binding` only with managed proxy enforcement; see [openai/codex#33227](https://github.com/openai/codex/issues/33227).
- **Flat skill registry**: the filesystem under `dot_agents/skills` is the only skill registry. Do not add index READMEs, manifests, or topical bucket folders: chezmoi mirrors source paths into `~/.agents/skills`, and Claude Code only scans the top level of a skills directory, so any non-ignored subfolder makes the skills inside it undiscoverable.
- **Global developer tools**: `.github/dev-tools/package.json` declares exact global npm tool versions, and `.github/dev-tools/requirements.txt` declares Pyright. Renovate updates both; their shared `run_onchange` installer reconciles each declaration independently, so retries skip versions that already match. Do not split the installer or update or prune entire npm and uv stores; unmanaged machine-local tools may coexist.
