---
name: commit
description: Create or amend a local git commit after the user explicitly asks to commit, `/commit`, amend, save changes, or needs committed work before a requested git action such as push. Use to stage relevant files, write a repository-matching message, and run `git commit`. Not for message-only drafts or branch creation.
argument-hint: "[additional context]"
context: fork
allowed-tools:
  - Bash(git:*)
  - Bash(cat:.git/hooks/*)
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(jq:*)
  - Read
---

Create one git commit for: $ARGUMENTS

## Contract

- Commit only after an explicit user request.
- Do not push, reset, checkout, rebase, or rewrite history unless the user explicitly asked for that operation.
- Recover motivation from the current conversation, linked issue or plan, project docs, current diff, and targeted agent transcript search when the user wants one commit for work spread across prior conversations or agents.
- Do not read shell history. Treat transcripts as secret surfaces: search them narrowly, do not dump raw snippets into chat, and extract only the motivation needed for the commit message.
- Screen changed paths before reading diffs. Stop without reading or staging hard secret surfaces: `.env*`, private keys, certificates, `.ssh/`, shell history, logs, credential dumps, token files, or paths whose basename clearly names a secret. For ambiguous substring hits in source, tests, fixtures, docs, or public-key material such as `*.pub`, report the caution path count and ask for one explicit confirmation before including them.

## Message Rules

- The diff shows what changed. The message must explain what the diff cannot: motivation, trade-offs, user-visible behavior, and why the chosen approach fits the current constraints.
- Build the message from an evidence ledger:
  - `diff`: a staged hunk or committed doc proves the changed artifact, behavior, policy, path, config key, tool, spec, or external integration.
  - `motivation`: the conversation, issue, plan, or transcript explains why a staged change exists.
  - `report`: uncommitted local config, operator workflow, skipped tools, environment state, or rejected alternatives.
- Use `diff` evidence for the subject, approach, named artifacts, changed behavior, and durable policy claims. Use `motivation` evidence only for why the staged change exists. Move `report` evidence to the post-commit report.
- Bug fixes name the root cause. Features name the user-visible gap. Refactors name the constraint that forced the restructure.
- Lead with the reason the change exists, then name the approach. A body that only says `add X`, `update Y`, or `remove Z` is inventory; rewrite it around the invariant, consequence, or decision.
- Anchor every body bullet to ledger entries. Rewrite or remove sentences whose source is missing or whose source category is `report`.
- Use concrete verbs: `reject empty subscriber list`, `validate write access before subscribing`, `reduce p99 from 200ms to 50ms`.
- Replace vague verbs with the exact behavior, metric, bound, invariant, or threat model that changed. Avoid `tighten`, `streamline`, `enhance`, `refine`, `polish`, bare `optimize`, and bare `harden`.
- Use backticks for code references. Reference related commits by short hash only when the new commit depends on them.

Format precedence:

1. Dialect, tense, and subject case come from `git log --oneline -10`.
2. Type (`feat`, `fix`, `chore`, `refactor`) comes from the intent of this change.
3. Scope comes only from declarative config: `commitlint`, `commitizen`, or a Scopes section in `CONTRIBUTING.md`. If no config pins scopes, omit scope even when recent commits use one.

Format:

- Subject is 50 characters or fewer, imperative present tense, and has no trailing period.
- Body wraps at 72 characters, after one blank line below the subject.
- Do not refer to "this PR" or "this commit" inside the body.
- Do not quote the new commit's own hash.

## Process

1. Gather context in one read-only batch:
   - `git diff -z --name-only HEAD`
   - `git ls-files -z --others --exclude-standard`
   - `git diff --cached -z --name-only`
   - `git diff -z --name-only`
   - `git branch --show-current`
   - `git log --oneline -10`
   - `cat .git/hooks/pre-commit` if present
2. Refuse secret-like paths before reading file diffs.
3. Decide ordinary commit mode unless the user explicitly asked to amend the previous git commit. In amend mode, read `git show --stat --patch HEAD` and treat staged changes as the net replacement relative to `HEAD^`; ordinary commit mode must not use `git commit --amend`.
4. Read `git diff HEAD` for ordinary commit mode or the amend-mode net diff.
5. If the log dialect is Conventional Commits, look for scope config with:
   - `rg -l --no-ignore-vcs '"?commitlint"?|"?commitizen"?' -g '!node_modules' -g '!.git' .`
   - `fd CONTRIBUTING -d 3 .`
6. Record the pre-staged set from `git diff --cached -z --name-only`. Before any `git add`, compute the intersection of planned commit paths with `git diff -z --name-only`; if a pre-staged planned file also has unstaged changes, abort with `abort: partially staged path in commit scope` and the count. Do not collapse staged and unstaged hunks with `git add <path>`.
7. Stage only files that belong to the requested commit. If an unrelated staged file is already present, stop and report it instead of unstaging user work.
8. Verify `git diff --staged --name-only` matches every file named by the message.
9. If motivation is missing or the user indicates prior agent work, use the transcript recovery workflow below.
10. Build an evidence ledger for the subject, lead paragraph, and each body bullet. Mark each entry as `diff`, `motivation`, or `report`, and name the staged path, hunk, issue, plan, or transcript source.
11. Draft the message from ledger-approved entries. Each named path, tool, config key, policy, service, spec, external behavior, and changed behavior needs a `diff` source. Motivation may use conversation or transcript evidence only to explain why a staged hunk exists.
12. Scan the draft message for banned vague verbs from Message Rules. Treat each match as a hard error.
13. Commit with a single-quoted heredoc:

   ```bash
   git commit -F - <<'COMMIT_MSG_END'
   <message exactly as it should read in git log>
   COMMIT_MSG_END
   ```

   Single quotes on the terminator preserve backticks, `$`, `\`, `!`, and `"`.

   In amend mode only, replace `git commit` with `git commit --amend`.

14. After commit, run `git status --short`.

## Transcript Recovery

Use transcripts to recover motivation when the final commit spans multiple agents, directories, or conversations.

Search targets:

- Claude Code: `~/.claude/projects/**.jsonl` and `~/.claude/projects/**/subagents/*.jsonl`
- Codex: `~/.codex/sessions/**/*.jsonl`

Workflow:

1. Build search terms from changed file paths, branch names, issue IDs, function names, and user-provided context. Do not use broad terms such as `fix`, `update`, or `commit`.
2. Search in this order:
   - Claude current-project slug under `~/.claude/projects`
   - Codex sessions mentioning the current repo absolute path, repo basename, active branch, or changed path
   - Global transcript search only when the user indicates cross-agent or cross-directory work and at least two specific search terms are available
3. List candidate transcript files with `rg -l --fixed-strings <term> <transcript-root>`. Cap broad searches with date, project slug, or another term before reading.
4. Prefer assistant summaries, final messages, plan text, and tool-call result summaries. Avoid raw command output, environment dumps, logs, process lists, auth output, and secret-like paths.
5. For JSONL files, use `jq` to extract bounded text fields instead of printing whole records. Keep only lines needed to identify motivation, accepted trade-offs, test results, or manual verification gaps.
6. If the transcript evidence conflicts with the current diff, trust the current diff for what changed and use transcripts only for why the work happened.
7. Route transcript-only facts about uncommitted local config, rejected alternatives, skipped tools, or operator workflow to the post-commit report.
8. If no targeted evidence appears after one broad search plus one refinement, ask one specific motivation question rather than continuing to trawl transcripts.

## Failure Modes

- Cross-check abort: first line is `abort: <reason>`, followed by the exact mismatch.
- Secret-like path abort: first line is `abort: secret-like path in commit scope`, followed by the count only.
- Pre-commit hook failure: surface the hook output and stop.
- Do not bypass failures with `--no-verify`.

## Output

Return a labeled report:

- Commit: short hash and subject.
- Auto-staged: files this skill staged that were not pre-staged, or `none`.
- Leftover: modified or untracked files still present, each with a one-line relevance note.
