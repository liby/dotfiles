---
allowed-tools: Bash(git new:*), Bash(git branch:*)
description: Create a new git branch with proper prefix and optional ticket number
---

Create a new git branch using the `git new` command based on: $ARGUMENTS.

IMPORTANT: You MUST use the exact command `git new` (which is a git alias). DO NOT substitute with `git checkout -b` or `git switch -c` or any other git commands.

## Rules

1. Branch name must start with one of these prefixes: `feature/`, `bugfix/`, `hotfix/`
2. If a ticket number is provided (e.g., PROJ-1234), incorporate it into the branch name
3. Convert spaces to hyphens and ensure lowercase for the descriptive part
4. Keep branch names concise but descriptive

## Examples

- Input: "PROJ-1234 add user authentication" → `feature/PROJ-1234-add-user-authentication`
- Input: "fix memory leak" → `bugfix/fix-memory-leak`
- Input: "TASK-567 urgent fix for login" → `hotfix/TASK-567-urgent-fix-for-login`
- Input: "implement search functionality" → `feature/implement-search-functionality`

## Process

1. Parse the input to identify ticket number (if any) and description
2. Determine the appropriate prefix based on keywords or ask user if unclear
3. Format the branch name properly
4. Execute `git new <branch-name>`
5. Confirm branch creation with !`git branch --show-current`