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
- When the repo uses Conventional Commits, choose prefix by the **intent** of the change, NOT by the type of files changed
- Focus on "WHY" rather than "WHAT"
- Be CONCISE, specific, and ACCURATE to the actual diff
- When rewriting history (amend, rebase, force push), write the message from the remote's perspective — don't reference intermediate local states that will never be published
- Present tense verbs
- Backticks for code references: `` `$variable` ``, `` `someMethod()` ``
- Reference related commits: `fix bug introduced by [abc123]`

## Steps

1. Gather context by running `[git|dot] status --short`, `diff HEAD`, `branch --show-current`, and `log --oneline -10`
2. Examine recent commits to match the repository's commit style
3. Stage relevant files:
    - `git`: use `git add` with appropriate options
    - `dot`: use `dot add -u` by default; `dot add -f <file>` for new files (`~/.gitignore` ignores `*`); NEVER `dot add -A` (work tree is $HOME, would stage everything). Always use **absolute paths** — relative paths resolve from CWD, not from work-tree root
4. Commit with a message following the commit message rules above
