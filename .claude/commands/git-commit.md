---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*)
description: Create a git commit following repository conventions
---

## Context

- Current git status: !`git status --short`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Based on the above changes, create a git commit following rules:

1. Examine the recent commit messages to match the repository's commit style
2. Stage relevant files
3. Create a commit with a concise message that focuses on "why" rather than "what"
4. Match the existing style for prefixes, tense, and formatting
5. NEVER ADD CO-AUTHOR CREDITS

Additional context: $ARGUMENTS