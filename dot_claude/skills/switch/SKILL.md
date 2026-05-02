---
name: switch
description: Create a new git branch with proper prefix and naming conventions. Use when the user says "new branch", "/switch", or asks to create a branch.
argument-hint: "[ticket-number] [additional context]"
allowed-tools:
  - Bash(git:*)
---

Create a new git branch based on: $ARGUMENTS

## Naming rules

- Prefix: `feature/`, `bugfix/`, or `hotfix/`
- If a ticket number is provided (e.g., PROJ-1234), include it after the prefix
- Lowercase letters and numbers only (except uppercase ticket prefix)
- Hyphens `-` to separate words, no other special characters
- Period `.` only in version numbers
- 3-8 words in the description, concise but descriptive, present tense
- Use concrete action verbs (`add`, `fix`, `validate`, `reject`, `expose`, `migrate`). Skip vague AI verbs (`tighten`, `streamline`, `enhance`, `refine`, `polish`); they describe nothing.

### Examples

- `feature/upgrade-react-to-version-18`
- `bugfix/PROJ-3456-fix-login-redirect-issue`

## Steps

1. Analyze current changes with `git diff HEAD` and `git status --short` to determine the prefix.
2. Generate the branch name per the rules above. Include the ticket number after the prefix when available, sourced from `$ARGUMENTS` or from prior conversation context (e.g., Jira URLs, ticket IDs mentioned earlier).
3. `git switch -c <branch-name>`
