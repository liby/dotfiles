---
name: commit
description: Create a git commit following repository conventions. Use when the user says "commit", "/commit", or asks to commit changes.
argument-hint: "[additional context]"
context: fork
allowed-tools:
  - Bash(git:*)
  - Bash(cat:.git/hooks/*)
  - Bash(rg:*)
  - Read
---

Create a git commit for: $ARGUMENTS

## Focus on WHY over WHAT

The diff already shows what changed. The message captures what the diff cannot: motivation, trade-offs, why this approach beat alternatives, non-obvious consequences for future readers. **Lead with motivation, end with the chosen approach.**

By change type: bug fix surfaces the root cause, feature names the user-visible gap, refactor names the constraint that forced the restructure. Add a before/after snippet when the contrast sharpens the point.

The body should read as a self-contained story so the message doubles as the PR description without rewriting. **An inventory body (`add X, update Y, remove Z`) has zero value.** Rewrite around motivation.

### Examples

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

## Commit message rules

- Anchor every bullet to a specific diff hunk. Read the bullet, then name the hunk it describes. If you cannot point at one, the bullet is about a development conversation or a non-change, not the commit. Rewrite it to name the actual change, or drop it.
- Use concrete action verbs. **Right**: `reject empty subscriber list`, `validate write access before subscribing`, `cut p99 from 200ms to 50ms`.
- Skip vague verbs; replace each with the exact behavior, metric, bound, invariant, or threat model that changed. **Wrong**: `tighten`, `streamline`, `enhance`, `refine`, `polish`, bare `optimize` (no metric), bare `harden` (no named threat).
- Format precedence chain. Each part of the message takes its format from one named source; do not let a source for one part bleed into another.
  - **Dialect** (Conventional Commits / ticket-prefix / plain prose), **tense**, **subject case**: from `git log --oneline -10`.
  - **Type** (`feat`, `fix`, `chore`, `refactor`, ...): from the intent of the change. Not from the surrounding commits' types, not from the files touched.
  - **Scope**: take from declarative config only. Valid sources are `commitlint` / `commitizen` config (in their own files or as a `commitlint` block in `package.json`), or a Scopes section in `CONTRIBUTING.md`. Do not treat `git log` as a scope dictionary. Bot commits (e.g. Renovate's `fix(deps):`), one-off conventions, and contributor drift make history-based scope vocabulary unreliable. If config does not pin a scope, omit it even if recent commits include one.
- Use backticks for code references; reference related commits by short hash.
- When rewriting history (amend, rebase, force push), describe only the net effect vs the base commit the rewrite lands on. Intermediate states are erased from the remote, so the message must not reference them.
- Format rules:
  - Subject ≤ 50 chars, imperative present tense, no trailing period.
  - Body wrapped at 72 chars, after one blank line below the subject.
  - Do not refer to "this PR" or "this commit" inside the body.
  - Never quote the commit's own hash.

## Steps

1. Gather context in parallel (single tool-call batch):
  - `git status --short`, `git diff HEAD`, `git branch --show-current`, `git log --oneline -10`. When amending, also `git show HEAD`.
  - When `git log` reveals the dialect is Conventional Commits, also run `rg -l --no-ignore-vcs '"?commitlint"?|"?commitizen"?' -g '!node_modules' -g '!.git' .` and `fd CONTRIBUTING -d 3 .` to detect whether the repo pins a scope vocabulary. If both commands return nothing, no scope list exists. Per the format precedence chain above, omit the scope in that case, even if `git log` shows one.
  - `cat .git/hooks/pre-commit` if present, so you can interpret any files the hook modifies or any failures it raises. Step 5 surfaces hook failures verbatim.
  - If motivation is not in this conversation or a linked plan/issue, search prior session transcripts before drafting (see "Recovering motivation" below). Skip for trivial one-line changes.
2. Stage the commit:
  - **Tracked modifications**: `git add` the ones that belong to this commit.
  - **Untracked files** (list with `git ls-files --others --exclude-standard`): `git add` any that the planned message references.
  - Unstage anything unrelated. Verify the result with `git diff --staged --name-only`.
3. Cross-check the draft message before committing:
  - Every file path the message names must appear in `git diff --staged --name-only`. If not, `git add` it or rewrite the message.
  - Scan for banned vague verbs from the anti-slop "Skip vague verbs" rule (`tighten`, `streamline`, `enhance`, `refine`, `polish`, bare `optimize`, bare `harden`). Replace each with the specific behavior, metric, or invariant that changed.
  - Both are hard errors.
4. Pipe a single-quoted heredoc straight into `git commit -F -`:

    ```bash
    git commit -F - <<'COMMIT_MSG_END'
    <message exactly as it should read in `git log`>
    COMMIT_MSG_END
    ```

    Single quotes on the terminator (`'COMMIT_MSG_END'`) disable shell expansion, so backticks, `$`, `\`, `!`, and `"` write literally.

    Use a custom terminator like `COMMIT_MSG_END` rather than `EOF`. `EOF` is common in technical prose and collides whenever the message discusses heredoc syntax or end-of-file semantics.

    Do not wrap the heredoc in `"$(cat <<'...' ... )"` or fall back to `git commit -m "..."`. The extra double-quoted layer reintroduces escaping bugs.
5. After commit, run `git status --short` and return a labeled report (this skill runs in `context: fork`, so labels are the only signal back to the main session):

    - **Commit**: short hash + subject.
    - **Auto-staged**: files this skill `git add`-ed in step 2 that weren't pre-staged. "none" if empty.
    - **Leftover**: any untracked or modified files still around, each with a one-line note on relevance.

    Failure modes:

    - **Cross-check abort (step 3)**: first line is `abort: <reason>`, then the specific mismatch.
    - **Pre-commit hook failure**: surface the hook output verbatim and stop.
    - Never bypass either with `--no-verify`.

### Recovering motivation from prior sessions

Past Claude Code sessions live at `~/.claude/projects/<slug>/*.jsonl` (and `<session>/subagents/*.jsonl` for subagent runs). The slug is the absolute cwd with `/` and `.` replaced by `-` (for example `/Users/foo/.config/proj` -> `-Users-foo--config-proj`).

Use `rg -l` against the changed file paths or related identifiers across those `*.jsonl` files, then read the matched turns to recover the original motivation.
