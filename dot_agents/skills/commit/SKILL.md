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

Create coherent local history for the requested work. Determine the delivery and its authorized content before choosing commit mode or wording.

## Authority and protected content

- Commit when the user requested a commit or the requested workflow requires one, such as creating an MR/PR or an explicitly requested release step. An implementation request alone does not authorize a commit; report the prepared state instead.
- Honor explicit scope, grouping, staged-only choices, and authorized amend or fixup targets without asking again. Push, discard operations, and history rewrites require authorization for the operation; a fixup commit does not authorize a later rebase.
- Resolve the delivery repository, checkout, and branch or detached HEAD from the request and governing source ownership before choosing where to commit. Record that target separately from the execution cwd; linked worktrees share a repository but can have different delivery states. Use `git -C <delivery-checkout>` for its operations. For literal filenames passed to Git commands that accept pathspecs, quote each argument with per-path literal magic, such as `':(literal)src/[id]/file.ts'`. `--` ends options but does not disable pathspec matching. Keep literalization per argument; process-wide `--literal-pathspecs` also changes Git calls inside hooks.
- Before reading bodies from the working tree or a relevant history range, use governing instructions and non-value evidence to distinguish ordinary content, protected plaintext, and opaque ciphertext. A name containing `secret`, `credential`, or `token` alone does not classify a source or fixture. Do not read or stage declared environment files, private keys, credential stores, or unresolved potentially secret plaintext. Resolve uncertainty through bounded non-value evidence or one focused classification question; continue independent safe inspection, but do not silently omit required content from the delivery.
- Keep established ciphertext bodies out of every diff, including history. Metadata and authorized Git operations remain available. Describe encrypted changes generically using user or project classification; never infer plaintext behavior.
- Do not read shell history or dump raw transcripts. Load [transcript recovery](references/transcript-recovery.md) only when commit motivation remains missing or relevant prior work must be recovered.

## Inspect and group

1. Identify any in-progress merge, cherry-pick, revert, or rebase and confirm that completing it is authorized. Gather changed path names before content: tracked changes against `HEAD`, staged and unstaged names separately, and untracked names. Use NUL-delimited Git output for path comparisons. Keep intermediate inspection, staging, and verification records in memory; scratch files require an explicitly authorized location. Record the original index hunks and current `HEAD` before mutations. Use the empty tree as the baseline when no commit or parent exists.
2. Read ordinary staged and unstaged diffs separately, including safe untracked files needed for the task. Use committed content to establish the baseline, prospective hunks for the delta, and the request or recovered context for motivation. Motivation explains why changes belong together; it cannot prove that a behavior changed. Local environment state, skipped checks, and rejected alternatives belong in the final report, not the commit message.
3. Reconstruct the requested observable outcomes and each hunk's purpose. Keep implementation, migration cleanup, tests, and supporting guidance together when they complete one evidenced delivery. Separate independent requested outcomes or delivery decisions unless the user deliberately bundles them. Different paths, types, or independent revertibility alone do not justify splitting. Type and subject length must not determine the boundary.
4. Choose ordinary commit, authorized `HEAD` amend, or fixup against the recorded target identity. A follow-up completing the same delivery belongs with that commit when the operation is authorized. For amend, inspect the target and prospective replacement relative to its parent, including rationale that must survive. For fixup, inspect the specified target and verify the correction belongs to it; do not substitute the current `HEAD` or rewrite intervening commits.
5. Read recent full human-authored commit messages and applicable message configuration. Limit content searches to known safe configuration and contribution files. Derive any type from the verified primary change; use analogous history as evidence, not a vote. Resolve active commit hooks through Git configuration, including `core.hooksPath`, and inspect the applicable hooks before running them under the repository's execution rules.

## Prepare the commit content

The planned content is a set of hunks for the current unit, not merely a list of paths. Map pre-staged content to the requested units; authorization to split task-owned content permits staging those units in turn, while preserving the working tree and unrelated staging choices. Compare `HEAD`, the original index, the working tree, and task evidence before staging:

- Explicit staged-only: commit the existing index and leave unstaged content unchanged. A partially staged file is not a blocker.
- Deliberate batches or selected hunks: preserve that boundary even if the remaining edits concern the same feature. A general commit request does not override an explicit staging choice.
- Attributable follow-up: include unstaged revisions when conversation or tool evidence establishes that they complete the same authorized delivery and no deliberate boundary excludes them. Partial staging alone does not require confirmation. Use whole-path staging only when every staged and unstaged change in that path belongs in this commit; otherwise stage the exact patch.
- Unrelated or uncertain unstaged edits: leave them intact and stage only established in-scope hunks. Ask only if the missing attribution prevents an exact authorized commit.
- Unrelated pre-staged content: do not include it or change its real-index entries, even temporarily, unless that staging change is explicitly authorized. Saving and restoring entries afterward does not satisfy a boundary that must hold throughout. For an ordinary commit consisting of complete tracked paths, `git commit --only ... -- ':(literal)<path>' ...` can preserve other index entries; first verify that every working-tree hunk in those paths belongs in the commit. Never use this mode for staged-only or mixed-hunk paths. When whole-path isolation does not apply, use another exact method that preserves those real-index entries, or report the conflict before mutation.

For an index commit, stage the current unit using exact paths or patches and verify the complete staged path set and each staged hunk against the plan. For exact-hunk staging, construct and review the patch in memory, then send identical bytes through a quoted heredoc or `printf` pipe to `git apply --cached --check -` and `git apply --cached -`. Do not create an intermediate patch file unless its location is within an explicitly authorized scratch scope. For a whole-path commit, verify the complete `HEAD`-to-working-tree delta of the selected paths and record the unrelated index entries to preserve. In either mode, check for extra and missing content. For amend, also verify the complete prospective replacement relative to the target's parent. Keep opaque ciphertext checks metadata-only.

## Compose the message

Write from the verified planned commit content. The subject must let a repository reader recover the primary changed behavior or boundary without the request or body. Do not hide a replacement, removal, or direction of change behind an area name or a generic improvement claim. An established domain term carries only its evidenced meaning.

Put supporting changes and material reasons, constraints, trade-offs, or non-obvious consequences in the body when the subject cannot preserve them. Preserve this rationale when amending or consolidating; rewrite around the final net result. Check each factual claim against the committed baseline and planned delta, and each reason against recovered motivation. Remove unsupported causes, file inventories, subject restatements, and investigation or validation narration.

For example, `chore: keep package binaries and store on one volume` names the outcome; a body can explain the evidenced cross-volume store recreation that motivated it. `chore: update package manager path` plus a body restating the move loses that reason.

- Honor exact user wording and repository instructions first, then configured format limits and the stable recent dialect, tense, and subject case. Use a scope only when declarative configuration or contribution guidance defines it. If neither configuration nor history establishes a format, use imperative present tense, no trailing period, a subject near 50 characters, and an optional body wrapped near 72. Prefer accuracy over the fallback length preference.
- Use backticks for code references. Mention another commit's short hash only when the result depends on it; omit self-references such as "this commit" or "this PR".
- For a standard fixup, use Git's target-derived `fixup!` subject. The patch corrects the target; do not invent a replacement message or treat an unsquashed fixup as completed consolidation.

## Commit and verify

Immediately before committing, recheck that `HEAD`, the complete planned content, the preserved index entries, and the message still match the plan. If concurrent changes invalidate it, reconcile from fresh evidence before writing. For ordinary commits and amends, read the subject alone to check the primary change, then the complete message to check material meaning and rationale. For fixups, check that the generated subject identifies the recorded target.

Use a single-quoted heredoc so shell expansion cannot change the message:

```bash
git commit -F - <<'COMMIT_MSG_END'
<message>
COMMIT_MSG_END
```

For verified whole-path isolation, use `git commit -F - --only -- ':(literal)<path>' ...` with the same heredoc. For authorized `HEAD` amend, use `git commit --amend -F -` with the same heredoc. For a standard fixup, use `git commit --fixup=<recorded-target>`; leave autosquash or other history rewriting to its separately authorized workflow.

Never bypass a failure with `--no-verify`. On hook or commit failure, inspect the resulting `HEAD`, index, and working tree before any retry: a failed hook may already have changed files. Report the actionable error without exposing protected output; resolve only repairs within the task's authorization.

After success, verify the actual commit's parent, tree, and message in the recorded delivery checkout and branch or detached HEAD, and check that checkout's remaining index and working tree. A commit in another worktree or a matching copied file does not complete a required delivery to this target. Complete any remaining authorized delivery step; if it requires missing authorization, report the unmet target rather than declaring completion. Hooks can alter the result after the pre-commit check. Do not report success or rewrite an unexpected commit automatically; reconcile the discrepancy within existing authority or report what needs resolution. Refresh the remaining units against the new history without repeating unchanged style or motivation discovery.

## Output

- Commit: verified delivery checkout and branch or detached HEAD, with the short hash and subject for each created or amended commit, or `none` with the blocking reason.
- Included beyond initial staging: safe paths or additional hunks actually included beyond the original index, or `none`. This includes whole-path commits and revisions to already staged files.
- Leftover: preserved staged content and remaining modified or untracked paths with their known task relationship; use counts for protected or unresolved material. Include unresolved failures or verification gaps. An incomplete requested delivery remains incomplete even if some commits succeeded.
