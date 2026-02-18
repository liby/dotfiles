---
description: Create a git commit following repository conventions
argument-hint: "[additional context] | dot [context]"
context: fork
allowed-tools:
  - Bash(git:*)
  - Bash(dot:*)
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
- Be ACCURATE - describe what the diff actually shows, not assumptions about intent

## Your task

Based on the context above, create a git commit following these steps:

1. Examine the recent commits to understand the repository's commit style and conventions
2. Stage the relevant files using the appropriate command:
   - For `git`: use `git add` with appropriate options
   - For `dot`: 
     - Use `dot add -u` to stage only tracked files (default)
     - Use `dot add <specific-file>` for new files only when explicitly needed
     - NEVER use `dot add -A` to stage all files
3. Create a commit with a CONCISE message that:
   - Focuses on "WHY" rather than "WHAT"
   - Follows the commit message rules above
   - Matches the existing style for prefixes, tense, and formatting