---
name: switch
description: Create a new git branch with the repository's branch naming convention after the user says "new branch", "/switch", "create a branch", or asks to branch off for a task. Not for switching to an existing branch.
argument-hint: "[ticket-number] [additional context]"
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Read
---

Create one new git branch for: $ARGUMENTS

## Naming Rules

- Use an explicit user-provided branch name when it is valid and unambiguous.
- If local instructions or the active agent runtime require a specific prefix, use that prefix.
- Otherwise choose `feature/`, `bugfix/`, or `hotfix/` from the requested change.
- If a ticket number is provided, include it immediately after the prefix.
- Use lowercase letters, numbers, and hyphens in the descriptive slug. Preserve uppercase ticket prefixes such as `PROJ-1234`.
- Use `.` only inside version numbers.
- Use 3 to 8 descriptive words after the prefix or ticket.
- Use concrete verbs such as `add`, `fix`, `validate`, `reject`, `expose`, or `migrate`. Avoid `tighten`, `streamline`, `enhance`, `refine`, and `polish`.

Examples:

- `feature/upgrade-react-to-version-18`
- `bugfix/PROJ-3456-fix-login-redirect`
- `hotfix/1.2.3-reject-empty-token`

## Process

1. Confirm the user asked to create a new branch. If they asked to switch to an existing branch, do not use this skill.
2. Run read-only context checks:
   - `git branch --show-current`
   - `git status --short`
   - `git diff HEAD --stat`
3. Read local branch-naming instructions when present: `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `CONTRIBUTING.md`, or `README.md`. Keep this lookup bounded to the repo root and direct instruction files.
4. Generate the branch name from `$ARGUMENTS`, prior conversation context, local instructions, and the current diff summary.
5. Validate the name:
   - no spaces
   - no empty path segment
   - no leading `-`
   - no `..`, `~`, `^`, `:`, `?`, `*`, `[`, `\`, or trailing `.`
6. Run `git check-ref-format --branch <branch-name>`. If it fails, choose a corrected name and validate again before touching git state.
7. Check existence with `git rev-parse --verify --quiet refs/heads/<branch-name>`. If it exists, stop and report the existing branch.
8. Run `git switch -c <branch-name>`.
9. Verify `git branch --show-current` exactly equals `<branch-name>`.

## Output

Return the new branch name and the validation result. If creation failed, return the failing command and stderr summary.
