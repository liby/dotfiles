---
name: commit
description: Create a git commit following repository conventions. Use when the user says "commit", "/commit", or asks to commit changes.
argument-hint: "[additional context]"
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
---

Create a git commit for: $ARGUMENTS

## Commit message rules

- Be CONCISE, specific, and ACCURATE to the actual diff
- Focus on "WHY" rather than "WHAT", present tense verbs
- Match the repository's existing format (prefix, emoji, tense) from recent commits
- When the repo uses Conventional Commits, choose prefix by the **intent** of the change, NOT by the type of files changed
- When commit messages use emoji as a change-type indicator (e.g. `chore: 🔧 ...`, `🐛 fix ...`), select emoji by **intent**, not by copying past commits
  - Common: 🔧 update config values, ✨ add new tool/script/plugin, 🐛 bug fix, ♻️ refactor/restructure, 🔥 remove, 📝 rules/guidelines, 🔨 scripts
  - Full list: https://raw.githubusercontent.com/carloscuesta/gitmoji/master/packages/gitmojis/src/gitmojis.json
- Use backticks for code references, reference related commits by short hash
- When rewriting history (amend, rebase, force push), describe only the net effect vs the last **published** commit — changes added then removed within unpublished commits don't exist from the remote's perspective

## Steps

1. Gather context: `git status --short`, `diff HEAD`, `branch --show-current`, `log --oneline -10`. When amending, also run `show HEAD` to see the full commit being amended
2. Verify staging: `git diff --staged --name-only` — unstage any unrelated files
3. Stage relevant files with `git add`
4. Commit with a message following the rules above
