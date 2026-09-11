# Repository concepts

This document owns repository-specific design, lifecycle, and operator decisions that span files. It is not a file inventory or a replacement for the [chezmoi reference](https://www.chezmoi.io/reference/). Source files define behavior; [`AGENTS.md`](../AGENTS.md) owns contributor workflows and safety boundaries and routes each maintenance task here or to a narrower path rule or skill.

## Bootstrap

Bootstrap remains interactive because it crosses account-specific input, system-level installation, and hardware-backed GPG keys. Scripts provision tools and machine state that file synchronization alone cannot express.

Scripts in [`.chezmoiscripts`](../.chezmoiscripts/) use `before` and `after` attributes to place ordering dependencies around file synchronization. Their filenames remain the source of truth for order within each phase, while `run_once` and `run_onchange` encode rerun behavior using the standard semantics in [chezmoi's script guide](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/).

Script identity includes rendered comments and other non-executable bytes. A comment-only edit to a `run_once` or `run_onchange` source can therefore schedule the script again, and a `Brewfile` comment changes the explicit hash embedded in its installer. Treat those comments as operational input and edit them only when the resulting rerun is in scope.

Three dependencies shape the sequence:

- Homebrew and [`Brewfile`](../Brewfile) packages provide tools used by later scripts.
- launchd LaunchAgents own gpg-agent and keyboxd, and `no-autostart` in `~/.gnupg/common.conf` stops every client from starting one implicitly: a daemon started from a sandboxed agent shell keeps that sandbox for life and cannot reach the YubiKey. The GPG script writes and bootstraps those jobs in the `before` phase after Homebrew installation, because chezmoi needs the private keys while synchronizing encrypted files. dirmngr is deliberately unmanaged, so keyserver operations fail explicitly instead of autostarting it; the script imports the card's public key over HTTPS from the URL stored on the card instead of using the card's `fetch` command.
- A dedicated case-sensitive `Code` volume is provisioned as machine infrastructure rather than managed as a normal file target.

The bootstrap targets Apple Silicon macOS and uses `/opt/homebrew` directly.

The unique case-sensitive `Code` volume belongs to the APFS container that stores `$HOME` and is mounted persistently by UUID through `vifs`. Provisioning must refuse a non-empty or differently mounted `~/Code` and must never unmount a volume automatically. The `run_once` script provisions fresh-machine state rather than reconciling later drift; its Python test covers deterministic logic, while APFS, Disk Arbitration, and reboot acceptance remain manual Mac checks.

## Package and tool ownership

[`Brewfile`](../Brewfile) is the package declaration. Its installer also recreates the Homebrew update, upgrade, and cleanup job with a 10:00 local-time daily calendar trigger plus `RunAtLoad = true`, which intentionally adds an immediate login or reload run, removes the independent `StartInterval` timer, and verifies the job in the user's `gui/$UID` launchd domain. Upstream `brew autoupdate status` is not an equivalent check because it sees the caller's bootstrap namespace and does not understand the calendar schedule.

Logseq deliberately remains outside Homebrew ownership: this machine uses manually installed 0.10.15 because 2.x is incompatible. `Brewfile` owns the `proto` executable, while the Node bootstrap owns only Node.js and pnpm under `PROTO_HOME`; neither Logseq's cask nor proto's standalone installer is a fallback path. `proto upgrade` breaks that ownership in two places at once, so upgrade proto through Homebrew only. It writes `proto` and `proto-shim` into `$PROTO_HOME/bin`, which the tool shims and any shell that puts that directory first both resolve ahead of Homebrew, so later `brew upgrade` runs stop reaching the proto those callers execute. It also rewrites the directory of the running executable, because that executable sits outside proto's own inventory; under Homebrew that directory is the Cellar. Proto's own version check does not conflict with Homebrew ownership, because it only prints a notice pointing at `proto upgrade` and never installs anything; `PROTO_VERSION_CHECK=0` silences it.

The exact global npm tool versions live in [`.github/dev-tools/package.json`](dev-tools/package.json), and Pyright lives in [`.github/dev-tools/requirements.txt`](dev-tools/requirements.txt). Renovate groups both declarations with other dependencies, and one shared `run_onchange` installer reconciles each declaration independently without pruning unrelated machine-local npm or uv tools; do not split the installer. It also provisions uv-managed Python >=3.11 for envchain seeding independently of Pyright's installed version; the seeding script owns credential writes. The dev-tools workflow supplies their status check; a file-scoped Renovate `ignoreTests` must not be restored because it can become branch-level configuration on a mixed dependency group. `typescript`, `typescript-language-server`, and Pyright back Claude Code's LSP plugins, which [`.chezmoitemplates/claude/settings.json`](../.chezmoitemplates/claude/settings.json) enables; `typescript-language-server` falls back to the global `typescript` when a workspace's own cannot provide tsserver.

Both declarations carry a release-age cooldown, so a compromised upstream release has time to be reported and yanked before it is pinned here. Each ecosystem enforces it twice, and the two halves are coupled: the installer refuses to resolve an artifact younger than its window, so the matching Renovate rule in [`.github/renovate.json`](renovate.json) has to wait at least as long or it pins a version the installer cannot reach. [`dot_config/uv/uv.toml`](../dot_config/uv/uv.toml) sets the PyPI window through uv's `exclude-newer`, and because chezmoi deploys that file after the `before` phase that runs the installer, the installer renders the same value into its own `uv tool install` command rather than relying on the deployed file. The installer sets the npm window through `npm config set`, which writes `~/.npmrc` and therefore also covers npm processes that do not inherit the environment `.zshenv` sets up. That file also carries registry tokens, so the source declares the setting through the command rather than tracking the file. The two windows are deliberately different: the agent CLIs in `package.json` are invoked by everyday review and delegation workflows, so npm trades some cooldown for staying near upstream.

[`.chezmoiexternal.toml`](../.chezmoiexternal.toml) pins the zsh plugin archives at fixed commits. A Renovate custom manager in [`.github/renovate.json`](renovate.json) advances each commit from the branch named by the `# renovate: currentValue=` comment above its `url`, so an archive without that comment stops updating.

## Repository validation

GitHub discovers workflow YAML only directly under [`.github/workflows`](workflows/), so keep that directory flat and give each file one independently triggered validation concern. Keep behavior tests beside their owner when chezmoi ignores the test filename; reserve [`.github/tests`](tests/) for repository-only tests that cannot safely live beside a managed source. Python tests there use the conventional `test_*.py` name and must be reachable through `unittest discover` from the matching workflow; add a concern subdirectory only when multiple tests benefit from that grouping.

Every path-filtered workflow lists itself, the tests or validator it runs, and the production sources that can change the result. When a non-required workflow filters both `pull_request` and `push`, use a [YAML anchor](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations#yaml-anchors-and-aliases) for the identical path lists. GitHub leaves the required check for a [workflow skipped by pull-request path filters](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks#handling-skipped-but-required-checks) pending, so before making one required, trigger it for every pull request and move any filtering below the workflow level. Keep `permissions` read-only, disable checkout credential persistence, cancel superseded runs for the same ref, and give every job a finite timeout. Extract a reusable workflow only for a complete job shared by multiple callers, or a composite action for a meaningful repeated step sequence; do not hide isolated fields or one checkout step behind an abstraction.

The [agent-instruction workflow](workflows/validate-agent-instructions.yml) runs for every pull request and push because it checks local link targets plus the pre-action routing and credential consumer contracts that govern the whole repository, and can therefore become required without a path-filter skip deadlock.

## Configuration ownership

Most source files and templates render to paths under `$HOME`. Standard source names and template mechanics follow chezmoi rather than repository-specific conventions.

The [Codex global source](../dot_codex/AGENTS.md.tmpl) and [Claude global source](../dot_claude/CLAUDE.md.tmpl) retain `.tmpl` so Codex does not load them as directory instructions when started inside their source directories.

Not every configuration is fully replaced. Applications such as Codex and Claude Code write mutable runtime state, so [`modify_` sources](https://www.chezmoi.io/reference/target-types/#modify-file) manage selected fields while preserving application-owned values.

Replace subtrees that source fully owns so that removed fields disappear from the destination. For shared subtrees, preserve application-owned fields through an overlay or explicit exceptions during replacement. Establish ownership from the application's writers rather than the shape of the configuration. An overlay preserves undeclared fields; removing a source declaration does not by itself retire its destination state.

Deleting a source file likewise leaves its existing destination in place, and `chezmoi status` no longer reports that unmanaged path. The repository avoids persistent deletion lists and migration markers so source describes the current configuration without accumulating past removals. The trade-off is that existing machines need explicit cleanup; `.chezmoiremove` would automate file deletion but not cleanup of fields in shared configurations.

The JSON and TOML modifiers compare parsed values before serializing, so reordering object keys in their fragments alone leaves the destination unchanged. Fragments embedded in scripts, such as [`codex/requirements.toml`](../.chezmoitemplates/codex/requirements.toml), also affect script trigger hashes; their ordering changes can rerun the consuming script.

Chezmoi source manages portable, durable preferences, including established interaction habits, when they should remain consistent across machines. It leaves matching convenience defaults implicit unless an explicit value enforces a repository boundary or counters observed write-back drift. Generated runtime state, machine-specific paths, and settings synchronized elsewhere remain owned by their existing systems.

### Codex configuration

[`.chezmoitemplates/codex/config.toml`](../.chezmoitemplates/codex/config.toml) declares the source-owned portion of `~/.codex/config.toml`. The modifier replaces `plugins`, `permissions.development`, and each source-declared `mcp_servers` table, carrying forward only the destination's existing `node_repl.env` and `node_repl.env_vars` within those server tables. All other declared configuration is deep-overlaid. Replacing server tables removes stale transport fields that can make Codex reject the whole configuration. Removing an entire server from source still requires explicit destination cleanup.

Leave `features.js_repl`, `model_reasoning_effort`, and per-app authorization under Desktop control. [Herdr integrations](#herdr-integrations) owns `features.hooks`. Desktop generates `node_repl` environment fields and can later replace its runtime tables, so an apply does not prevent subsequent application write-backs. Keep the legacy standalone `mcp_servers.computer-use` registration unmanaged: source declarations can override the same-named plugin registration and conflict with [Desktop-owned runtime state](https://github.com/openai/codex/issues/24387#issuecomment-4531286877). Keep the bundled `computer-use` and `unified-computer-use` plugins enabled; `unified-computer-use` provides Desktop's `cua_repl` browser and computer runtime.

Desktop's settings store writes every registered preference to the `[desktop]` table and removes its legacy global-state or persisted-atom copy after migration. Manage a registered preference in [`.chezmoitemplates/codex/config.toml`](../.chezmoitemplates/codex/config.toml); reserve the global-state fragment for current persisted atoms that have no registered Desktop setting.

`~/.codex/.codex-global-state.json` is also partially managed. [`dot_codex/modify_dot_codex-global-state.json`](../dot_codex/modify_dot_codex-global-state.json) overlays [the portable global-state fragment](../.chezmoitemplates/codex/global-state.json), which keeps onboarding completion, dismissed announcements, active-line Git blame, Work home composer mode, and explicit review diff filter (`branch`) portable; every other global-state entry remains Desktop-owned. These keys belong to the current Desktop implementation rather than the public `config.toml` schema, so verify the installed app before changing or expanding their managed paths. A running Desktop process can overwrite an external apply with its in-memory persisted-atom values, so change these preferences through the UI or apply this target while Desktop is stopped.

Keep `approval_policy = "on-request"`, `approvals_reviewer = "auto_review"`, and the sole custom `default_permissions = "development"` profile together. [`.chezmoitemplates/codex/requirements.toml`](../.chezmoitemplates/codex/requirements.toml) constrains that tuple so task loading cannot replace it with `never` / `user` as described in [#33552](https://github.com/openai/codex/issues/33552), and intentionally removes the built-in modes, including Full Access. [#37511](https://github.com/openai/codex/pull/37511) added runtime enforcement, and Codex 0.151 tests that this global reviewer requirement rejects incompatible thread setting updates; neither proves that Desktop hot-reloads an edited `requirements.toml`, so restart Desktop after changing it until a no-restart reproduction establishes that boundary.

The `development` filesystem profile remains standalone with `:root = write`, `~/.ssh` denied except the exact `config`, `allowed_signers`, and `known_hosts` entries that ssh and Git signature verification use, exact read-only `.env` and `.env.local` entries under every workspace root, and no copied per-tool cache lists or broad command allows. Programs may consume credential and environment files through their normal interfaces; changing or deleting one still requires the user's explicit request. Filesystem capability does not authorize remote Git or secret-bearing chezmoi operations.

[openai/codex#40254](https://github.com/openai/codex/issues/40254) tracks the current macOS reproduction in which Chrome fails trusted RPC path validation without an explicit Browser cache read rule. Keep `~/.codex/plugins/cache/openai-bundled/browser` as the only extra read-only path so the trusted worker can load Desktop's runtime-owned Browser service; a chezmoi `private_` or `readonly_` source and `chmod` do not create a trusted permission root. Remove the exception only after deleting the source rule, applying the rendered configuration, fully restarting Desktop, confirming the effective permission table no longer contains the rule, and succeeding on the first Chrome initialization in a fresh task without a prior Browser attempt or retry.

Both `cli_auth_credentials_store` and `mcp_oauth_credentials_store` stay on explicit `keyring`; `auto` may fall back to plaintext files. Before activating this on another machine, use a credential-safe status check against the exact store to confirm the existing login. Agents never migrate, rewrite, or delete the real store.

One managed zsh `PreToolUse` Bash guard is enabled by [`.chezmoitemplates/codex/requirements.toml`](../.chezmoitemplates/codex/requirements.toml) from `~/.codex/managed-hooks`. Non-interactive zsh autoloads the same provider-aware `claude` function used interactively, and the guard rejects common top-level forms that bypass that launcher so the persisted provider mode is selected before gateway credentials are expanded. It is a model-misuse guardrail for common top-level direct-display, credential-extraction, and launcher-bypass commands, not child-process isolation, output redaction, a general shell parser, a client allowlist, a secret broker, or an authentication boundary.

The guard distinguishes ordinary search patterns, file operands and common option values; it does not validate every CLI option or reproduce option precedence. Explicit token-display flags are rejected even if canceled later. Unrecognized search options may conservatively treat their values as operands. Shell compounds and child-command strings remain outside inspection. With a heredoc, checks continue through same-line pipelines and logical operators, then stop at the first newline or semicolon instead of parsing its body.

The same requirements file enables a second managed hook, [`contextual-markdown-links`](../dot_codex/managed-hooks/executable_contextual-markdown-links), on `UserPromptSubmit`. It injects the Markdown link-placement instruction as `additionalContext` on every prompt because Codex ignores `UserPromptSubmit` matchers and the same context must cover links discovered after tool calls.

The [Codex requirements script](../.chezmoiscripts/run_onchange_after_06-setup-codex-requirements.sh.tmpl) writes the rendered requirements to the macOS preference independently of Apple UI defaults. Keep these lifecycle owners separate so a hook registration or timeout change does not restart ControlCenter, Dock, or Finder.

Keep `features.network_proxy = false` with `permissions.development.network.enabled = true` so public and local networking remain direct while the filesystem profile stays enforced. Add proxy-only `domains` or `allow_local_binding` only when managed proxy enforcement exists; [openai/codex#33227](https://github.com/openai/codex/issues/33227) documents the unresolved proxy-only local binding failure.

### GitLab CLI configuration

The [glab preference script](../.chezmoiscripts/run_onchange_after_05-configure-glab.sh) uses `glab config set --global` to seed portable preferences through the CLI's normal configuration path. Keep authentication and mutable runtime fields owned by glab: chezmoi must not relocate or adopt its credential-capable `config.yml`, and must not replace this client-owned write path with a `modify_` source. After its initial run, ordinary applies leave manual changes untouched until the script content changes.

### Claude Code configuration

[`.claude/rules/claude-code-settings.md`](../.claude/rules/claude-code-settings.md) is the path-scoped owner for Claude Code settings, sandbox, integration, and runtime-state decisions. Its path frontmatter makes Claude Code load it only for the matching sources; other Agents must follow the route in [`AGENTS.md`](../AGENTS.md) before changing those sources.

### Pi configuration

`~/.pi/agent/models.json` is fully managed, while `~/.pi/agent/settings.json` is partially managed. The [settings modifier](../private_dot_pi/private_agent/modify_private_settings.json) replaces each top-level key declared in the [settings fragment](../.chezmoitemplates/pi/settings.json), including the entire `modelThinkingLevels` map, and preserves undeclared keys. Applies intentionally overwrite UI-saved startup and per-model defaults so devices share the source configuration.

Temporary `/model` and `/thinking` selections remain available. After applying settings, use `/reload`, then select the model again with `/model` to activate the thinking defaults; resuming a session can restore its recorded model and thinking level. `defaultProjectTrust = "always"` intentionally lets every directory load project-local settings, resources, packages, and extensions without a trust prompt.

`thinkingLevelMap` describes model controls, not preferred defaults. Expose documented controls for the serving route, not compatibility aliases: an HTTP 200 does not prove the requested effort was honored ([gateway mappings](https://vercel.com/docs/ai-gateway/models-and-providers/reasoning#how-reasoning-is-mapped), [Fireworks API](https://docs.fireworks.ai/api-reference/post-chatcompletions)).

Credentials, sessions, installed packages, and recorded trust decisions under `~/.pi/agent` remain runtime-owned, so the directory must never be adopted wholesale. Both managed source directories stay `private_` to preserve mode `0700`. The gateway base URL comes from `.private.rcGatewayBaseUrl`, and the rendered model file resolves `RC_GATEWAY_API_KEY` at runtime from the `pi` envchain namespace instead of carrying a secret.

### Herdr integrations

[`run_onchange_after_07-install-herdr-integrations.sh.tmpl`](../.chezmoiscripts/run_onchange_after_07-install-herdr-integrations.sh.tmpl) installs the Pi, Claude Code, and Codex integrations so each agent reports its native session ID to Herdr and a restarted Herdr server resumes the pane in its previous conversation instead of a bare shell. Herdr owns every file it writes, and `herdr integration status` lists them; the surprising one is `features.hooks` inside the otherwise managed `~/.codex/config.toml`. Leave that key out of [`.chezmoitemplates/codex/config.toml`](../.chezmoitemplates/codex/config.toml). The installer owns the flag's name, having already migrated `codex_hooks` to `hooks` and deleted the retired key, so a source declaration would restore what a later migration removes. Omitting it costs nothing: the modifier compares parsed values, so the installed flag survives an apply and the flush-left line the installer writes never surfaces as drift. The rendered `herdr --version` in the script is the only refresh signal, because Herdr reports outdated integrations from `herdr update`, which a Homebrew upgrade bypasses. The Claude `SessionStart` registration is the one entry that must live in source because the settings modifier replaces the whole `hooks` key; [`.claude/rules/claude-code-settings.md`](../.claude/rules/claude-code-settings.md) owns its required form.

### Shared agent execution

The installed Homebrew `snow` command has one native-SSO execution identity. Codex Rules own both broad approval and inner-sandbox exclusion for Codex; Claude's `permissions.allow` and `sandbox.excludedCommands` own those decisions separately. The personal `snow` skill owns query and same-task SSO behavior, while Snowflake RBAC owns server authorization. Do not narrow the route to `snow sql -q` or restore workspace `uvx` runtimes.

## Managed skill registry

[`dot_agents/skills/<name>/SKILL.md`](../dot_agents/skills/) is the canonical source layout for chezmoi-managed skills and is mirrored into `~/.agents/skills`; Claude Code reads that mirror through the managed `~/.claude/skills` symlink, so never add a skill under `~/.claude/skills` directly. Resolve an installed path with `chezmoi source-path` and edit the source, not the deployed copy. Exclude unmanaged installed skills from bulk maintenance, change one only when the user names it, adopt one only when explicitly requested, and leave `~/.agents/.skill-lock.json` as runtime-owned install state. Supporting `references`, `scripts`, and `assets` stay inside their owning skill; the registry has no index, manifest, or category directories.

A managed skill preapproves every tool and command family needed by its normal contract without making a permission prompt the authorization boundary. Exact entries are for exhaustive stable sets; otherwise use the appropriate command family or bare `Bash`. Retain runtime confirmation only for user-confirmed high-impact actions outside the skill contract. If Claude ignores a matching skill grant, preserve the contract and add the narrowest effective runtime exception backed by a reproducer.

## Identity and encrypted data

[`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl) defines prompts for account-specific template values. Each user supplies their own values during `init`; a fork should first review which fields still apply.

Encrypted files use GPG, with private keys stored on a YubiKey. Repository-only encrypted data can seed envchain namespaces in the macOS Keychain instead of deploying credentials as ordinary dotfiles. Adapting the full repository therefore requires replacing or removing its GPG recipients and personal encrypted data.

Agents may read `~/.ssh` client config (`config`, `config.*`), public keys, `allowed_signers`, and `known_hosts`, and nothing else under that directory. The Claude and Codex Bash guards, Claude's file-tool hook, and Claude's sandbox enforce that list by directory, so private keys deployed there need no naming convention and no per-key rule. The Codex sandbox reopens only the exact files ssh and Git signature verification need, because its read rules take no globs; public keys stay unreadable inside that sandbox.

### Git identity and signing

Both forges verify commits signed by the YubiKey, in different formats. GitHub verifies OpenPGP signatures from the card's signature key. GitLab verifies SSH signatures from the card's authentication key against the encrypted `~/.ssh/allowed_signers`, so the work address never becomes a user ID on the personal OpenPGP key: nothing about the employer is published with that key or has to be revoked from it later. [`run_onchange_after_01-setup-gitconfig.sh.tmpl`](../.chezmoiscripts/run_onchange_after_01-setup-gitconfig.sh.tmpl) reads the key id from `gpg --card-status` and installs [`github.config`](../.chezmoitemplates/git/github.config) with it and [`gitlab.config`](../.chezmoitemplates/git/gitlab.config) with the exported authentication key in Git's `key::` form into `~/.config/git/`, so signing reads no file under `~/.ssh`; `dot_config/git/config` includes the GitHub file everywhere and the GitLab file for repositories under `~/Code/GitLab/`. The script derives the key itself on every rerun because the `run_once` GPG script does not rerun with it.

[`git-ssh-gpg-agent`](../dot_config/git/executable_git-ssh-gpg-agent) exists because gpg-agent serves the card's SSH key on `~/.gnupg/S.gpg-agent.ssh` while shells keep the macOS ssh-agent in `SSH_AUTH_SOCK`. The wrapper points `SSH_AUTH_SOCK` at the gpg-agent socket, then runs `ssh` for `core.sshCommand --transport` or `ssh-keygen` as `gpg.ssh.program`, so Git transport and SSH signing reach the YubiKey from any shell, including sandboxed agent shells that inherit no agent environment. `ssh` outside Git keeps the macOS agent and file keys.

### Credential-backed features

The [seeding script](../.chezmoiscripts/run_onchange_after_04-seed-envchain.sh.tmpl) reads `.secrets/seed.asc` and stores each entry in the macOS Keychain through envchain. Its plaintext is TOML with one top-level table per namespace and one environment variable per single-line string value; numeric and boolean-looking values remain quoted. The template below is the machine-checked contract for entries consumed by files in this repository; other seed entries are not repository requirements.

```toml
[claude-gateway]
ANTHROPIC_AUTH_TOKEN = "replace-with-value"
ANTHROPIC_VERTEX_BASE_URL = "replace-with-value"
ANTHROPIC_VERTEX_PROJECT_ID = "replace-with-value"
CLAUDE_CODE_SKIP_VERTEX_AUTH = "1"
CLAUDE_CODE_USE_VERTEX = "1"

[context7]
CONTEXT7_API_KEY = "replace-with-value"

[pi]
RC_GATEWAY_API_KEY = "replace-with-value"
```

The [Claude launcher](../dot_zsh/functions/claude) injects the `claude-gateway` namespace only in gateway mode. The [Codex configuration](../.chezmoitemplates/codex/config.toml) and [Claude user configuration](../.chezmoitemplates/claude/claude.json) obtain Context7 request headers through `envchain context7`, because envchain injects credentials only into its child process. After a Context7 change, validate library resolution and returned documentation in a fresh client session. The [Pi model configuration](../private_dot_pi/private_agent/private_models.json.tmpl) reads `RC_GATEWAY_API_KEY` from the `pi` namespace. The [agent instruction contract test](tests/test_agent_instructions.py) parses the TOML block and verifies its exact keys, consumer paths, and local namespace wiring without reading the encrypted seed.
