---
name: new-branch
description: Create a new Git branch for a task using the repository's naming convention. Use when the user asks to create a branch, or a requested task such as opening an MR or PR needs one as a step. Not for switching to an existing branch.
argument-hint: "[ticket-number] [additional context]"
allowed-tools:
  - Bash(git:*)
  - Read
---

Create one new git branch for the requested task.

## Naming Rules

- Use an explicit user-provided branch name when it is valid and unambiguous.
- If local instructions, the user, or the active agent runtime explicitly require one fixed prefix, use that prefix.
- Otherwise reuse a stable prefix pattern from recent repository branches when one exists. Only fall back to `feature/`, `bugfix/`, or `hotfix/` from the requested change when the sample has no stable convention. Treat runtime default prefixes such as `codex/` as fallbacks, not requirements.
- If a ticket number is provided, include it immediately after the prefix.
- Use lowercase letters, numbers, and hyphens in the descriptive slug. Preserve uppercase ticket prefixes such as `PROJ-1234`.
- Use `.` only inside version numbers.
- Use 3 to 8 descriptive words after the prefix or ticket.
- When the slug needs an action, use concrete verbs such as `add`, `validate`, `reject`, `expose`, or `migrate`.
- Avoid adding a verb that only repeats the prefix meaning, such as `bugfix/fix-login-redirect`.
- Avoid `tighten`, `streamline`, `enhance`, `refine`, and `polish`.

Examples:

- `feature/upgrade-react-to-version-18`
- `bugfix/PROJ-3456-restore-login-redirect-state`
- `hotfix/1.2.3-reject-empty-token`

## Process

1. Confirm the user asked for a new branch, or for a task that needs one as a step, such as opening an MR or PR from new work. If they asked to switch to an existing branch, do not use this skill.
2. Run read-only context checks:
   - `git branch --show-current`
   - `git status --short`
   - `git diff HEAD --stat`
   - `git for-each-ref --sort=-committerdate --count=30 --format='%(refname:short)' refs/heads refs/remotes`
3. Read local branch-naming instructions when present: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, or `README.md`. Keep this lookup bounded to the repo root and direct instruction files.
4. Generate the branch name from the request, prior conversation context, local instructions, the current diff summary, and the recent branch sample. Ignore remote HEAD pointers and the current/default branch when inferring a convention.
5. Validate the name:
   - no spaces
   - no empty path segment
   - no leading `-`
   - no `..`, `~`, `^`, `:`, `?`, `*`, `[`, `\`, or trailing `.`
6. Run `git check-ref-format --branch <branch-name>`. If it fails, choose a corrected name and validate again before touching git state.
7. Check existence with `git rev-parse --verify --quiet refs/heads/<branch-name>`. If it exists, stop and report the existing branch.
8. If a base ref is required:
   - Treat a remote-tracking base as the current local snapshot. Do not fetch unless the user or repository instructions explicitly require a fresh remote base.
   - When that refresh is authorized, resolve the configured remote and remote branch, then fetch with an explicit `<source>:<destination>` refspec that updates only the selected remote-tracking ref.
   - Resolve the base and `HEAD` to commits before switching.
   - If the commits differ and the index or working tree has staged, unstaged, or untracked changes, stop unless the user explicitly asked to carry those changes to the requested base.
   - A branch from current `HEAD`, or from a base resolving to the same commit, may retain the current changes.
9. Create the branch without inheriting the upstream of a base ref:
   - If no base ref is required, run `git switch -c <branch-name>`.
   - If the user or repo instructions require a base ref such as `origin/develop`, run `git switch --no-track -c <branch-name> <base-ref>`. Do not use `git switch -c <branch-name> origin/develop`; Git can set the new branch to track `origin/develop`, so a later push may update the base branch.
10. Verify `git branch --show-current` exactly equals `<branch-name>`.
11. Verify upstream safety before any commit or push:
   - Run `git rev-parse --abbrev-ref --symbolic-full-name @{u}`.
   - If it reports no upstream, continue.
   - If it reports the matching remote branch for the new branch name, continue.
   - If it reports a base branch such as `origin/develop`, run `git branch --unset-upstream`, then verify again.

## Output

Return the new branch name and the validation result. If creation failed, return the failing command and stderr summary.
