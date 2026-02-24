---
name: git-new
description: Create a new git branch with proper prefix and naming conventions. Use when the user says "new branch", "/git-new", or asks to create a branch.
argument-hint: "ticketNumber [context] | [additional context]"
disable-model-invocation: true
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

### Examples

- `feature/upgrade-react-to-version-18`
- `bugfix/PROJ-3456-fix-login-redirect-issue`

## Steps

1. Analyze current changes with `git diff HEAD` and `git status --short`
2. Extract ticket number from $ARGUMENTS if provided
3. Determine prefix based on the nature of changes
4. Generate branch name following the rules above
5. Run `git switch -c <branch-name>`
