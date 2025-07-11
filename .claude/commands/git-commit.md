---
allowed-tools: Bash(dot add:*), Base(dot branch:*), Bash(dot commit:*), Bash(dot diff:*), Bash(dot log:*), Bash(dot status:*), Bash(git add:*), Base(git branch:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git status:*)
description: Create a git commit following repository conventions
---

User request: $ARGUMENTS

## Your task

Based on the user request above and the repository context below, create a git commit following these rules:

1. IMPORTANT: Use `dot` command instead of `git` when:
   - Request mentions "dot" or "dotfiles", OR
   - Current directory is $HOME and *~/.dotfiles* directory exists
   - `dot` is an alias for: `git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`
   - Replace ALL `git` commands with `dot` (e.g., `dot add`, `dot commit`, `dot status`)
2. Examine the recent commit messages to match the repository's commit style
3. Stage relevant files using the appropriate command
4. Create a commit with a concise message that focuses on "why" rather than "what"
5. Match the existing style for prefixes, tense, and formatting

## Context

- Current git status: !`git status --short`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`