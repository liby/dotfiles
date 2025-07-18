---
allowed-tools: Bash(dot add:*), Base(dot branch:*), Bash(dot commit:*), Bash(dot diff:*), Bash(dot log:*), Bash(dot status:*), Bash(git add:*), Base(git branch:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git status:*)
description: Create a git commit following repository conventions
argument-hint: "[additional context] | dot [context]"
---

## Context

User request: $ARGUMENTS.

IMPORTANT: Use `dot` command instead of `git` when:
  - Request mentions "dot" or "dotfiles", OR
  - Current directory is $HOME and *~/.dotfiles* directory exists
`dot` is an alias for: `git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`.

- Current git status: `[git|dot] status --short`
- Current git diff (staged and unstaged changes): `[git|dot] diff HEAD`
- Current branch: `[git|dot] branch --show-current`
- Recent commits: `[git|dot] log --oneline -10`

## Commit Message Rules

- Use present tense verbs: `Add`, `Fix`, `Update`, `Remove`
- Use backticks for code references: "`$variable`", "`someMethod()`", "`ClassName`"
- Reference related commits with hash: `Fix bug introduced by [abc123]`
- Be specific - mention all significant changes in one commit
- Be CONCISE - avoid unnecessary words

## Your task

Based on the context above, create a git commit following these steps:

1. Examine the recent commits to understand the repository's commit style and conventions
2. Stage the relevant files using the appropriate command (`git add` or `dot add`)
3. Create a commit with a CONCISE message that:
   - Focuses on "WHY" rather than "WHAT"
   - Follows the commit message rules above
   - Matches the existing style for prefixes, tense, and formatting