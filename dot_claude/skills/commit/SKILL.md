---
name: commit
description: Create a git commit following repository conventions. Use when the user says "commit", "/commit", or asks to commit changes.
argument-hint: "[additional context]"
allowed-tools:
  - Bash(git:*)
  - Bash(cat:.git/hooks/*)
  - Agent
---

Create a git commit for: $ARGUMENTS

## Commit message rules

- Be specific and accurate to the actual diff. Every claim in the body must correspond to a line that actually changed; the subject line stays under 50 characters.
- Use concrete action verbs in subject and body: `reject empty subscriber list`, `validate write access before subscribing`, `cut p99 from 200ms to 50ms`.
- Avoid vague change verbs in commit messages: `tighten`, `streamline`, `enhance`, `refine`, `polish`, bare `optimize` (no metric), and bare `harden` (no named threat). Replace them with the exact behavior, metric, bound, invariant, or threat model that changed.
- Focus on WHY over WHAT, present-tense verbs. The diff already shows what changed; the message captures what the diff cannot: the motivation behind the change, the trade-offs considered, the reason this approach won over alternatives, and any non-obvious consequence a future reader would need. Lead with motivation, end with the chosen approach. For bug fixes that means surfacing the root cause; for features that means the user-facing problem or capability gap; for refactors that means the constraint or pain that forced the restructure. Add a before/after snippet when the contrast sharpens the point. The body should read as a self-contained story, so the message can double as the PR description without rewriting. A body that lists changed files or functions ("add X, update Y, remove Z") has zero value: rewrite it around motivation, not inventory.
- Match the repository's existing format. Read the `git log --oneline -10` output you already gathered to extract the prefix pattern (Conventional Commits, ticket prefix, plain prose) and tense, then conform.
- For Conventional Commits, choose the type by the intent of the change, not by the files touched or subsystem affected. Only add a scope when the repository documents an explicit list (commonly `commitlint` / `commitizen` config or a Scopes section in `CONTRIBUTING.md`); otherwise omit it.
- Use backticks for code references; reference related commits by short hash.
- When rewriting history (amend, rebase, force push), describe only the net effect vs the base commit the rewrite lands on. Intermediate states are erased from the remote, so the message must not reference them.

## Output contract

- Subject line: ≤ 50 characters, imperative present tense, no trailing period.
- Body: wrapped at 72 characters, separated from the subject by a blank line.
- Do not refer to "this PR" or "this commit" inside the body, and never quote the commit's own hash.

## Example

Inventory style (avoid):

```plaintext
fix: update SessionProvider

Modified useEffect dependency array.
```

Motivation style (use):

```plaintext
fix(auth): stop session refresh from racing with sign-out

Two effects in `SessionProvider` both subscribed to `authState`: one
refreshed the token, the other cleared local storage on sign-out. When
sign-out fired during a refresh window, the refresh callback wrote a
stale token back after the clear, leaving users half-signed-in.

Consolidating into a single effect keyed by the auth phase removes the
ordering dependency.
```

## Steps

1. Gather context in parallel (single tool-call batch):
  - `git status --short`, `git diff HEAD`, `git branch --show-current`, `git log --oneline -10`. When amending, also `git show HEAD`.
  - `cat .git/hooks/pre-commit` if present. Some repos auto-stage via hooks (formatters, `git add -u`) at commit time, so anything modified in the working tree lands in the commit regardless of staging. If the hook auto-stages and you only want a subset, run `git stash push -- <unrelated-paths>` before step 3 so the hook has nothing extra to sweep in. Otherwise the message must cover every modified managed file.
  - If the motivation for the change is not present in the current conversation or a linked plan/issue, search prior session transcripts before drafting; do not infer from the diff alone. Past Claude Code sessions live at `~/.claude/projects/<slug>/*.jsonl` (and `<session>/subagents/*.jsonl` for subagent runs); the slug is the absolute cwd with `/` and `.` replaced by `-` (for example `/Users/foo/.config/proj` -> `-Users-foo--config-proj`). Use `rg -l` against the changed file paths or related identifiers across those `*.jsonl` files, then read the matched turns to recover the original motivation. Skip for trivial one-line changes.
2. Stage relevant files with `git add`, then verify with `git diff --staged --name-only`. Unstage anything unrelated.
3. Pipe a single-quoted heredoc straight into `git commit -F -`:

    ```bash
    git commit -F - <<'COMMIT_MSG_END'
    <message exactly as it should read in `git log`>
    COMMIT_MSG_END
    ```

    Single quotes on the terminator (`'COMMIT_MSG_END'`) disable shell expansion, so backticks, `$`, `\`, `!`, and `"` write literally. Use a custom terminator like `COMMIT_MSG_END` rather than `EOF`: `EOF` is common in technical prose and collides whenever the message discusses heredoc syntax or end-of-file semantics. Do not wrap the heredoc in `"$(cat <<'...' ... )"` or fall back to `git commit -m "..."`; the extra double-quoted layer reintroduces escaping bugs.
4. Report the short hash and subject after the commit succeeds. If a pre-commit hook fails, surface the failure to the user and stop. Do not bypass with `--no-verify`.
