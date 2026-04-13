---
name: commit
description: Create a git commit following repository conventions. Use when the user says "commit", "/commit", or asks to commit changes.
argument-hint: "[additional context]"
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(cat:.git/hooks/*)
  - Agent
---

Create a git commit for: $ARGUMENTS

## Commit message rules

- Be CONCISE, specific, and ACCURATE to the actual diff
- Focus on WHY over WHAT, present-tense verbs. The diff already shows what changed — the message captures what the diff cannot: the problem being solved, the trade-offs considered, the reason this approach won over alternatives. For any non-trivial change, structure the body as Background / Problem / Solution, with a before/after snippet when it helps, so `git log` reads as a self-contained story and the message can double as the PR description without rewriting. A body that is just a list of changed files or functions ("add X, update Y, remove Z") has zero value — rewrite it around motivation, not inventory.
- Match the repository's existing format (prefix, tense) from recent commits
- When the repo uses Conventional Commits, choose prefix by the intent of the change, NOT by the type of files changed. Do not add a scope unless the repo has an established, documented set of scopes — a scope that appears in a few past commits is convention, not specification
- Use backticks for code references, reference related commits by short hash
- When rewriting history (amend, rebase, force push), describe only the net effect vs the base commit the rewrite lands on. Intermediate states — whether never pushed or previously pushed then overwritten by force push — are erased from the remote's history, so the message must not reference them

## Steps

1. Gather context in parallel (single tool-call batch):
  - `git status --short`, `git diff HEAD`, `git branch --show-current`, `git log --oneline -10`. When amending, also `git show HEAD`.
  - `cat .git/hooks/pre-commit` if present. Some repos auto-stage via hooks (formatters, `git add -u`) at commit time — anything modified in the working tree lands in the commit regardless of what you staged. If the hook auto-stages and you only want a subset, `git stash push -- <unrelated-paths>` before step 2 so the hook has nothing extra to sweep in. Otherwise the message must cover every modified managed file.
  - If the diff touches code you did not just write in this session, and the motivation is not already in the current conversation or a linked plan/issue, spawn `compound-engineering:research:session-historian` in the same batch — pass it the list of changed paths and ask for the motivation behind each one from prior sessions. Skip only for trivial one-line changes or when you already hold the full reasoning.
2. Stage relevant files with `git add`.
3. Verify staging: `git diff --staged --name-only`. Unstage anything unrelated.
4. Commit with a message following the rules above. Before sending, sanity-check: does the body explain why a reader should care? If it only describes what moved, rewrite.
