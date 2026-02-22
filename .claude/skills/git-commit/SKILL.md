---
name: git-commit
description: Create a git commit following repository conventions. Use when the user says "commit", "/commit", or asks to commit changes.
argument-hint: "[additional context] | dot [context]"
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(dot:*)
---

Create a git commit for: $ARGUMENTS

Use `dot` instead of `git` when the request mentions "dot" or "dotfiles", or when the current directory is $HOME and `$HOME/.dotfiles` exists. `dot` is an alias for `git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`.

## Commit message rules

- Match the repository's existing format (prefix, emoji, tense) from recent commits
- Present tense verbs: `Add`, `Fix`, `Update`, `Remove`
- Backticks for code references: `` `$variable` ``, `` `someMethod()` ``
- Reference related commits: `Fix bug introduced by [abc123]`
- Be CONCISE, specific, and ACCURATE to the actual diff
- Focus on "WHY" rather than "WHAT"

## Steps

1. Gather context by running `[git|dot] status --short`, `diff HEAD`, `branch --show-current`, and `log --oneline -10`
2. Examine recent commits to match the repository's commit style
3. Stage relevant files:
    - `git`: use `git add` with appropriate options
    - `dot`: use `dot add -u` by default; `dot add <file>` only for new files; NEVER `dot add -A` (work tree is $HOME, would stage everything)
4. Commit. Use `dangerouslyDisableSandbox: true` for all `dot` commands and `git commit` (sandbox blocks `$HOME/.dotfiles/` writes and `$HOME/.gnupg` for GPG signing)
