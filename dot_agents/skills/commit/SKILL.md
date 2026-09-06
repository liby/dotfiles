---
name: commit
description: Create or amend local Git commits from the relevant changes. Use for every commit operation, regardless of how the request arrived, which repository it targets, or what tooling wraps git. Stage only in-scope files and write repository-matching messages. Not for message drafts or branch creation.
argument-hint: "[additional context]"
background: false
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(jq:*)
  - Read
  - WebFetch
  - WebSearch
---

Create a coherent local commit history for the requested work, one semantic unit at a time. Recover what prompted the work, the outcome the history must preserve, and its scope from the invocation, available conversation or transcript context, and current repository evidence.

## Contract

- Commit when the user requested a commit or the requested workflow cannot complete without one, such as creating an MR/PR or an explicitly requested release step. An implementation request alone does not authorize a commit; stop and report the prepared state instead.
- When the commit targets a repository other than the cwd, resolve its directory first and run every git command in this skill with `git -C <dir>`.
- Do not push, reset, checkout, rebase, or rewrite history unless the user or governing repository instructions authorize the exact operation.
- Honor explicit scope, grouping, and authorized amend or fixup targets. A deliberate request to bundle independent work overrides the default grouping convention; do not ask the user to authorize the same choice again.
- Do not read shell history. Treat transcripts as secret surfaces: search them narrowly, do not dump raw snippets into chat, and extract only the motivation needed for the commit message.
- Screen changed paths before reading bodies, then classify them by exposure risk rather than name alone:
  - Raw secret surfaces include real `.env*` files, private keys, credential stores or dumps, shell history, and logs that may contain secrets. Stop without reading or staging them.
  - Opaque ciphertext is established by repository instructions or an encryption marker, not by extension alone. Keep its body out of diffs, but allow metadata inspection and Git stage, commit, rename, or delete operations. Use project or user-supplied change classification as motivation, never infer plaintext, and keep ciphertext-only messages generic.
  - Ambiguous paths include names that suggest secrets without proving plaintext or ciphertext, PEM bundles, unknown SSH material, and source or fixture names containing `credential`, `secret`, or `token`. Report only the caution count and ask for one explicit classification before reading or staging them. Public certificates, public keys, `authorized_keys`, `known_hosts`, and SSH client configuration are not secret by type.

## Model the change

Build an evidence ledger before staging and finalize it from the staged state:

- `baseline`: committed code, docs, tests, config, or history establishes the behavior or contract before the change.
- `delta`: a candidate hunk establishes the prospective artifact, behavior, policy, path, config key, tool, spec, or external integration; the staged diff confirms it.
- `motivation`: the conversation, issue, plan, or transcript explains why a candidate change exists.
- `report`: uncommitted local config, operator workflow, skipped tools, environment state, or rejected alternatives.

Use the requested outcome and its evidenced purpose to determine the commit boundary; use `baseline` and `delta` to verify which changes deliver it. Motivation can establish why changes belong together, but cannot prove that an artifact or behavior changed. When the repository dialect uses types, derive the type from the verified result. For opaque ciphertext, `delta` proves only path, status, and encrypted format; derive no plaintext claim, use ordinary files for behavior evidence, and use the user's classification only for motivation.

## Write the message

The subject names the primary changed behavior or boundary at the level of the delivered outcome. Use the body for supporting changes needed to understand that outcome and for its reason, constraints, material trade-offs, or non-obvious consequences when the subject cannot preserve them. Match comparable recent, human-authored messages. Preserve important rationale when amending or consolidating history, but rewrite the message around the final net result. Do not repeat the subject, inventory files, or narrate investigation and validation.

Wrong: `chore: update package manager path` with body `Move the package manager home to the new directory.`

Right: `chore: keep package binaries and store on one volume` with a body explaining that cross-volume installs recreated the store and colocating them prevents that mismatch.

- Use `baseline` and finalized `delta` evidence to support the subject, approach, and every named behavior or boundary. Use `motivation` only for why the change exists. Move `report` evidence to the post-commit report.
- Name a cause, gap, or constraint only when ledger evidence establishes it and the staged change addresses it; otherwise name the resulting behavior or boundary.
- Anchor every included body claim to ledger entries. Rewrite or remove sentences whose source is missing or whose source category is `report`.
- Use concrete verbs: `reject empty subscriber list`, `validate write access before subscribing`, `reduce p99 from 200ms to 50ms`.
- Judge specificity from the finalized ledger, not a word list. An established repository or domain term expresses only the requirements its evidenced definition entails; merely naming an area, artifact, request, or category that contains the changes expresses none.
- Use backticks for code references. Reference related commits by short hash only when the new commit depends on them.

Format precedence:

1. Dialect, tense, and subject case come from recent full commit messages. Ignore clearly automated dependency commits when inferring prose style.
2. Scope comes only from declarative config: `commitlint`, `commitizen`, or a Scopes section in `CONTRIBUTING.md`. If no config pins scopes, omit scope even when recent commits use one.

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
   - `git rev-parse --path-format=absolute --git-path hooks/pre-commit`, then read the resolved file if it exists
2. Classify every changed path under the Contract. Abort on raw secret surfaces. Record opaque ciphertext separately, exclude its body from every later diff, and continue with ordinary paths once every ambiguous path is classified.
3. Record the history operations authorized by the user and governing repository instructions. Ordinary commits are the default; do not choose an amend for a unit before reconstructing its semantic relationship to `HEAD`.
4. Read `git diff HEAD`, limited to ordinary paths. When amend is authorized and may apply, also read `git show --stat --patch HEAD` and the net diff relative to `HEAD^`. Inspect opaque ciphertext through `--name-status`, `--stat`, or encryption markers only.
5. If the log dialect is Conventional Commits, look for type and scope config with:
   - `rg -l --no-ignore-vcs '"?commitlint"?|"?commitizen"?' -g '!node_modules' -g '!.git' .`
   - `fd CONTRIBUTING -d 3 .`
6. Reconstruct what prompted the work, the requested observable outcome, what purpose each ordinary hunk serves, and whether it belongs to that outcome from the current conversation, linked issue or plan, project docs, and when relevant the tool's documentation or changelog. If context remains missing or the user indicates prior agent work, load and follow [transcript recovery](references/transcript-recovery.md). Verify a zero-hit search's syntax before concluding that evidence is absent (`rg` uses `|` for alternation, not `\|`; `grep` is the opposite).
7. Before staging, build the evidence ledger and reconstruct semantic units from the requested outcomes. Keep implementation, migration cleanup, verification, and supporting guidance together when they complete one evidenced outcome. Split changes that serve separate requested outcomes or have independent delivery decisions. Being separately describable or revertible, touching another directory, or admitting another commit type does not by itself establish a separate delivery.
8. Choose each unit's authorized ordinary, amend, or fixup mode from its relationship to the target commit. A follow-up completing the same delivery belongs with that commit when the rewrite is authorized; publication affects authorization, not semantic independence. Record the target identity before creating other commits so an amend cannot accidentally target a new `HEAD`. Choose any required type for the primary semantic change after grouping; type or subject-length pressure must not determine the boundary. If type remains unclear, inspect analogous human-authored changes.
9. Record the original pre-staged paths and hunks. For an explicit staged-only request, use the existing index as the planned content and skip staging; an unstaged edit in the same file does not block committing that index. Otherwise, if the index includes unrelated content, remove only content the user explicitly excluded from the commit, preserving its working-tree changes; without that instruction, stop and report it. Before any `git add`, compute the intersection of planned paths with `git diff -z --name-only`; if a pre-staged planned file also has unstaged changes, abort with `abort: partially staged path in commit scope` and the count. Do not collapse staged and unstaged hunks with `git add <path>`.
10. In causal order, stage only the current unit using exact paths or patches. Preserve working-tree content and index choices the user has not authorized changing. If exact staging requires an unauthorized index change, stop and report it.
11. Verify the complete NUL-delimited `git diff --cached -z --name-only` set equals the current unit's planned path set and every staged hunk belongs to that unit; abort on any extra or missing content. Use `git diff --staged` in ordinary mode or `git diff --cached HEAD^` in amend mode to finalize `delta`, including for newly added files. Inspect opaque ciphertext through metadata only.
12. Finalize the unit's ledger from the staged diff. Identify its primary changed behavior or boundary, the supporting changes a future reader needs, and the important rationale. For an authorized history rewrite, judge the replacement commit against its parent, not against an intermediate draft or only the new fixup patch.
13. Draft the subject so a repository reader can recover the primary change without the request context. Do not hide a concrete replacement, removal, or direction of change behind an area name or a generic improvement claim. Put supporting details and important rationale in the body when needed; they need not all fit in the subject. Check every message claim against the finalized ledger.
14. Immediately before invoking `git commit`, verify that the subject identifies the primary change and the complete message preserves the material meaning and rationale of the final result. Repeat the complete staged-set and hunk-membership check from step 11. Do not commit until both checks pass. Then commit with a single-quoted heredoc:

   ```bash
   git commit -F - <<'COMMIT_MSG_END'
   <message exactly as it should read in git log>
   COMMIT_MSG_END
   ```

   Single quotes on the terminator preserve backticks, `$`, `\`, `!`, and `"`.

   In amend mode only, replace `git commit` with `git commit --amend`.

15. After each commit, refresh the remaining work's baseline and index state against the new history; revisit grouping only if that evidence changes it. Reuse established repository style and recovered motivation unless new evidence invalidates them. After the final commit, run `git status --short`.

## Failure Modes

- Cross-check abort: first line is `abort: <reason>`, followed by the exact mismatch.
- Raw-secret path abort: first line is `abort: raw secret path in commit scope`, followed by the count only.
- Pre-commit hook failure: surface the hook output and stop.
- Do not bypass failures with `--no-verify`.

## Output

Return a labeled report:

- Commit: one short hash and subject per created or amended commit.
- Auto-staged: paths this skill staged minus the recorded pre-staged set, or `none`; re-adding an already staged file does not make it newly auto-staged.
- Leftover: modified or untracked files still present, each with a one-line relevance note.
