---
name: new-branch
description: Create a new Git branch for a task using the repository's naming convention. Use when the user asks to create a branch, or a requested task such as opening an MR or PR needs one as a step. Not for switching to an existing branch.
argument-hint: "[ticket-number] [additional context]"
allowed-tools:
  - Bash(git:*)
  - Read
---

## Naming Rules

- Use an explicit user-provided branch name when it is valid and unambiguous.
- If local instructions, the user, or the active agent runtime explicitly require one fixed prefix, use that prefix.
- Otherwise reuse a stable prefix pattern from recent repository branches when one exists. Only fall back to `feature/`, `bugfix/`, or `hotfix/` from the requested change when the sample has no stable convention. Treat runtime default prefixes such as `codex/` as fallbacks, not requirements.
- If a ticket number is provided, include it immediately after the prefix, preserving its case, as in `bugfix/PROJ-3456-restore-login-redirect-state`.
- Name the change itself, as `restore-login-redirect-state` does. Avoid a verb that only repeats the prefix meaning, such as `bugfix/fix-login-redirect`, and vague verbs such as `tighten`, `streamline`, `enhance`, or `polish`, which hide what changed.

## Process

1. Run read-only context checks:
   - `git branch --show-current`
   - `git status --short`
   - `git diff HEAD --stat`
   - `git for-each-ref --sort=-committerdate --count=30 --format='%(refname:lstrip=2)' refs/heads refs/remotes`
2. Read local branch-naming instructions when present: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, or `README.md`. Keep this lookup bounded to the repo root and direct instruction files.
3. Generate the branch name from the request, prior conversation context, local instructions, the current diff summary, and the recent branch sample. Ignore `<remote>/HEAD` and the current/default branch when inferring a convention.
4. Run `git check-ref-format --branch <branch-name>`. If it fails, choose a corrected name and validate again before touching git state.
5. Check existence with `git for-each-ref --format='%(refname:short)' refs/heads/<branch-name> 'refs/remotes/*/<branch-name>'`. If it prints anything, stop and report it: a local match is an existing branch or a ref-path conflict, and a remote-tracking match is someone else's branch that a later push would be rejected against.
6. If a base ref is required:
   - Treat a remote-tracking base as the current local snapshot. Do not fetch unless the user or repository instructions explicitly require a fresh remote base.
   - When that refresh is authorized, resolve the configured remote and remote branch, then run `git fetch --no-prune --no-tags --refmap= <remote> refs/heads/<branch>:refs/remotes/<remote>/<branch>`. The empty `--refmap=` keeps configured fetch mappings from storing other refs, `--no-tags` stops tag following, and the full `refs/heads/<branch>` source matters under `fetch.prune`: with a bare `<branch>` source, Git deletes the destination ref and, when the remote tip moved, fails with `cannot lock ref`. `--no-prune` also prevents that deletion.
   - Resolve the base and `HEAD` to commits before switching.
   - If the commits differ and the index or working tree has staged, unstaged, or untracked changes, stop unless the user explicitly asked to carry those changes to the requested base.
   - A branch from current `HEAD`, or from a base resolving to the same commit, may retain the current changes.
7. Create the branch with `git switch --no-track -c <branch-name> [<base-ref>]`, passing `<base-ref>` only when the user or repository instructions require one.
8. Verify `git branch --show-current` exactly equals `<branch-name>`.

## Output

Return the new branch name, the base ref and its short commit when a base was used, and the validation result. If creation failed, return the failing command and stderr summary.
