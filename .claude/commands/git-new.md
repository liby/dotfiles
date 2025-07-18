---
allowed-tools: Bash(git new:*), Bash(git branch:*), Bash(git diff:*), Bash(git status:*)
description: Create a new git branch with proper prefix and following naming conventions
argument-hint: ticketNumber [context] | [additional context]
---

Create a new git branch using the `git new` command based on: $ARGUMENTS.

IMPORTANT: You MUST use the exact command `git new` (which is a git alias). DO NOT substitute with `git checkout -b` or `git switch -c` or any other git commands.

## Your Task

Analyze the current changes and generate an appropriate branch name following GitFlow conventions and naming rules.

## Branch Naming Conventions

### Format Rules

- Branch name must start with one of these prefixes: `feature/`, `bugfix/`, `hotfix/`
- If a ticket number is provided (e.g., PROJ-1234), incorporate it into the branch name
- Only lowercase letters and numbers (except ticket prefix which is uppercase)
- Use hyphens `-` to separate words
- No special characters (`_`, `\`, `@`, `()`, `*`, `&`, `%`, etc.)
- Period `.` only allowed in version numbers

### Content Rules

- 3-8 words in the description part
- Omit unnecessary words like "the" when possible
- Use present tense verbs
- Be concise but descriptive

### Examples

- `feature/upgrade-react-to-version-18`
- `feature/DEV-1234-add-user-authentication`
- `bugfix/PROJ-3456-fix-login-redirect-issue`
- `hotfix/TASK-5678-restore-database-connection`

## Process

1. Analyze current changes with `git diff` and !`git status`
2. Extract ticket number from $ARGUMENTS (if provided)
3. Determine appropriate prefix based on the changes
4. Generate descriptive suffix based on the code changes
5. Format branch name following the rules above
6. Execute `git new <branch-name>`
7. Confirm creation with !`git branch --show-current`