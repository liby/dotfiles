---
name: commit
description: Create or amend a local Git commit from the relevant changes. Use for every commit you are about to create, regardless of how the request arrived, which repository it targets, or what tooling wraps git. Stage only in-scope files and write a repository-matching message. Not for message drafts or branch creation.
argument-hint: "[additional context]"
context: fork
background: false
allowed-tools:
  - Bash(git:*)
  - Bash(cat .git/hooks/pre-commit)
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(jq:*)
  - Read
---

Create one git commit for: $ARGUMENTS. With empty arguments, commit the work from the current conversation.

## Contract

- Commit only after an explicit user request.
- When the commit targets a repository other than the cwd, resolve its directory first and run every git command in this skill with `git -C <dir>`.
- Do not push, reset, checkout, rebase, or rewrite history unless the user explicitly asked for that operation.
- Recover motivation from the current conversation, linked issue or plan, project docs, current diff, and targeted agent transcript search when the user wants one commit for work spread across prior conversations or agents.
- Do not read shell history. Treat transcripts as secret surfaces: search them narrowly, do not dump raw snippets into chat, and extract only the motivation needed for the commit message.
- Screen changed paths before reading bodies, then classify them by exposure risk rather than name alone:
  - Raw secret surfaces include real `.env*` files, private keys, credential stores or dumps, shell history, and logs that may contain secrets. Stop without reading or staging them.
  - Opaque ciphertext is established by repository instructions or an encryption marker, not by extension alone. Keep its body out of diffs, but allow metadata inspection and Git stage, commit, rename, or delete operations. Use project or user-supplied change classification as motivation, never infer plaintext, and keep ciphertext-only messages generic.
  - Ambiguous paths include names that suggest secrets without proving plaintext or ciphertext, PEM bundles, unknown SSH material, and source or fixture names containing `credential`, `secret`, or `token`. Report only the caution count and ask for one explicit classification before reading or staging them. Public certificates, public keys, `authorized_keys`, `known_hosts`, and SSH client configuration are not secret by type.

## Explain why, not an inventory

The subject names the concrete behavior or boundary that changed. When a body is needed, use comparable recent, human-authored commits to match its tone and shape. Add a body whenever the reason the change exists, a constraint behind the approach, a material trade-off, or a non-obvious consequence is not clear from the subject alone; the diff is not a substitute for that context. Do not add a body that only repeats the subject or inventories the diff. Omit investigation history and validation narration.

Wrong: `chore: update package manager path` with body `Move the package manager home to the new directory.`
Right: `chore: keep package binaries and store on one volume` with a body explaining that cross-volume installs recreated the store and colocating them prevents that mismatch.

## Message Rules
- Build the message from an evidence ledger:
  - `diff`: a staged hunk or committed doc proves the changed artifact, behavior, policy, path, config key, tool, spec, or external integration.
  - `motivation`: the conversation, issue, plan, or transcript explains why a staged change exists.
  - `report`: uncommitted local config, operator workflow, skipped tools, environment state, or rejected alternatives.
- For opaque ciphertext, `diff` evidence proves only path, status, and encrypted format. Derive no plaintext claim from it; use the ordinary changed files for behavior evidence and the user's classification only for motivation.
- Use `diff` evidence for the subject, approach, and every named path, tool, config key, policy, service, spec, external behavior, and changed behavior. Use `motivation` evidence only for why the staged change exists. Move `report` evidence to the post-commit report.
- Bug fixes name the root cause only when evidence identifies it and the patch fixes it; otherwise name the behavior or boundary that now changes. Features name the user-visible gap. Refactors name the constraint that forced the restructure.
- Anchor every included body claim to ledger entries. Rewrite or remove sentences whose source is missing or whose source category is `report`.
- Use concrete verbs: `reject empty subscriber list`, `validate write access before subscribing`, `reduce p99 from 200ms to 50ms`.
- Replace a vague verb with the exact behavior, metric, bound, invariant, or threat model that changed. Examples to inspect are `tighten`, `streamline`, `enhance`, `refine`, `polish`, bare `optimize`, and bare `harden`; the failure is missing meaning, not the token itself.
- Use backticks for code references. Reference related commits by short hash only when the new commit depends on them.

Format precedence:

1. Dialect, tense, and subject case come from recent full commit messages. Ignore clearly automated dependency commits when inferring prose style.
2. Type (`feat`, `fix`, `chore`, `refactor`) comes from the intent of this change.
3. Scope comes only from declarative config: `commitlint`, `commitizen`, or a Scopes section in `CONTRIBUTING.md`. If no config pins scopes, omit scope even when recent commits use one.

Format:

- Follow repository-configured limits and the stable recent pattern. If neither establishes a format, use imperative present tense without a trailing period, aim for a subject of 50 characters or fewer, and wrap an optional body near 72 characters after one blank line. Exceed the fallback preference rather than make the subject vague or inaccurate.
- Do not refer to "this PR" or "this commit" inside the body.
- Do not quote the new commit's own hash.

## Process

1. Gather context in one read-only batch:
   - `git diff -z --name-only HEAD`
   - `git ls-files -z --others --exclude-standard`
   - `git diff --cached -z --name-only`
   - `git diff -z --name-only`
   - `git branch --show-current`
   - `git log -15 --no-merges --format='%h%n%s%n%b%n---'`
   - `cat .git/hooks/pre-commit` if present
2. Classify every changed path under the Contract. Abort on raw secret surfaces. Record opaque ciphertext separately, exclude its body from every later diff, and continue with ordinary paths once every ambiguous path is classified.
3. Decide ordinary commit mode unless the user explicitly asked to amend the previous git commit. In amend mode, read `git show --stat --patch HEAD` and treat staged changes as the net replacement relative to `HEAD^`; ordinary commit mode must not use `git commit --amend`.
4. Read `git diff HEAD` for ordinary commit mode or the amend-mode net diff, limited to ordinary paths. Inspect opaque ciphertext through `--name-status`, `--stat`, or encryption markers only.
5. If the log dialect is Conventional Commits, look for scope config with:
   - `rg -l --no-ignore-vcs '"?commitlint"?|"?commitizen"?' -g '!node_modules' -g '!.git' .`
   - `fd CONTRIBUTING -d 3 .`
6. Record the pre-staged set from `git diff --cached -z --name-only`. Before any `git add`, compute the intersection of planned commit paths with `git diff -z --name-only`; if a pre-staged planned file also has unstaged changes, abort with `abort: partially staged path in commit scope` and the count. Do not collapse staged and unstaged hunks with `git add <path>`.
7. Stage only files that belong to the requested commit. If an unrelated staged file is already present, stop and report it instead of unstaging user work.
8. Verify `git diff --staged --name-only` matches every file named by the message.
9. Search the current conversation, linked issue, plan, and project docs for motivation behind each staged change. For dotfile or config changes, check the tool's documentation or changelog for the reason the path, key, or default changed. If a search returns zero hits, verify the search syntax before concluding motivation is absent (`rg` uses `|` for alternation, not `\|`; `grep` is the opposite).
10. If motivation is still missing or the user indicates prior agent work, use the transcript recovery workflow below.
11. Build an evidence ledger for the subject and every included body claim. Mark each entry as `diff`, `motivation`, or `report`, and name the staged path, hunk, issue, plan, or transcript source.
12. Draft the message from ledger-approved entries, applying the Message Rules source categories. If it has no body, verify that the subject itself preserves every recoverable reason, constraint, material trade-off, and non-obvious consequence a future reader needs; otherwise add the body.
13. Scan the draft message for vague verbs from Message Rules. Treat a match as an error only when it substitutes for the exact behavior, metric, bound, invariant, or threat model; rewrite the missing meaning rather than deleting a token mechanically.
14. Commit with a single-quoted heredoc:

   ```bash
   git commit -F - <<'COMMIT_MSG_END'
   <message exactly as it should read in git log>
   COMMIT_MSG_END
   ```

   Single quotes on the terminator preserve backticks, `$`, `\`, `!`, and `"`.

   In amend mode only, replace `git commit` with `git commit --amend`.

15. After commit, run `git status --short`.

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
- Raw-secret path abort: first line is `abort: raw secret path in commit scope`, followed by the count only.
- Pre-commit hook failure: surface the hook output and stop.
- Do not bypass failures with `--no-verify`.

## Output

Return a labeled report:

- Commit: short hash and subject.
- Auto-staged: files this skill staged that were not pre-staged, or `none`.
- Leftover: modified or untracked files still present, each with a one-line relevance note.
