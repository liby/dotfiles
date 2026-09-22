---
name: commit
description: Create or amend local Git commits from the relevant changes. Use for every commit operation, regardless of how the request arrived, which repository it targets, or what tooling wraps git. Stage only in-scope files and write repository-matching messages. Not for message drafts or branch creation.
argument-hint: "[additional context]"
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Bash(jq:*)
  - Read
---

Create coherent local history for the requested work. Decide what is being delivered and what is authorized before choosing commit mode or wording.

## Authority

- Commit when the user asked for one or the requested workflow needs one, such as creating an MR/PR or an explicitly requested release step. An implementation request alone does not authorize a commit; report the prepared state instead. A repository instruction that prescribes amend or fixup for follow-ups is authorization for that mode.
- Honor explicit scope, grouping, staged-only choices, and authorized amend or fixup targets without asking again; a fixup does not authorize a later rebase.
- Resolve the delivery repository, checkout, and branch or detached HEAD from the request and governing source ownership, not from the cwd: linked worktrees share a repository but not a delivery state. Run its operations as `git -C <delivery-checkout>`. Quote literal filenames per argument with literal magic, such as `':(literal)src/[id]/file.ts'`; `--` ends options but does not stop pathspec matching. Do not set process-wide literal pathspec behavior, which also changes Git calls inside hooks.
- Do not commit or stage declared environment files, private keys, credential stores, or unresolved potentially secret plaintext, and keep established ciphertext bodies out of every diff; this covers content a previous step already staged, so a staged-only request that would include one stops and leaves the index as it is. Load [transcript recovery](references/transcript-recovery.md) only when the commit's motivation is still missing after the request and diff are read.

## Decide the unit

Check for an in-progress merge, cherry-pick, revert, or rebase, and finish one only when finishing it is authorized. Establish staged, unstaged, and untracked state separately, read the safe content needed to determine and verify the authorized commit, and reconstruct what each hunk delivers against the committed baseline. Record `HEAD` and the original index before any mutation, and the unborn state when the repository has no commit.

One commit is one requested observable outcome. Implementation, migration cleanup, tests, and the guidance that documents them belong together when they complete that outcome. Different paths, different types, and independent revertibility do not justify a split, and neither do type prefixes or subject length. Separate genuinely independent outcomes unless the user bundled them.

Then choose ordinary commit, authorized `HEAD` amend, or fixup against the recorded target. For an amend, compare the replacement against the target's parent, or against the empty tree for a root commit, so rationale that must survive is carried over. For a fixup, verify the correction belongs to the specified target; never substitute the current `HEAD` or rewrite intervening commits.

## Stage exactly the unit

The index belongs to the user. Do not add, remove, or temporarily alter an index entry outside the unit, and do not rely on restoring it afterwards.

- Staged-only request: commit the index as it stands. A partially staged file is not a blocker.
- Deliberate batches or hand-picked hunks: that boundary holds even when the remaining edits concern the same feature.
- Unstaged work that conversation or tool evidence shows completes the same authorized delivery: include it. Otherwise leave it intact, and ask only when the missing attribution blocks an exact commit.

Stage whole paths only when every working-tree hunk in them belongs in this commit; `git commit --only -F - -- ':(literal)<path>' ...` then preserves the other index entries but still takes those paths' working-tree contents. An ordinary `git commit` consumes the whole index, so when a path holds excluded hunks, or unrelated content is already staged, isolate the unit through a separate index, and after that commit reconcile the shared index for the unit paths to the new commit so a later ordinary commit cannot revert them; applying a patch to the shared index does not by itself exclude those entries. For an amend, `git commit --amend --only` commits no staged change and needs no paths. Verify the committed tree against the plan, and if no method preserves the required boundary, stop before mutating and report the conflict. A patch file belongs only inside an explicitly authorized scratch location. Before writing, check the staged set against the plan for both extra and missing content, and for an amend check the complete prospective replacement against the target's parent, or against the empty tree for a root commit.

## Write the message

Read any message configuration and several recent messages in this repository, and follow that dialect, tense, ordinary subject case, and scope convention; exact user wording and repository instructions come first. Only when none of those establishes a convention, use imperative present tense, no trailing period, a subject near 50 characters, and a body wrapped near 72. Accuracy beats the length preference.

The subject must let a repository reader recover the primary changed behavior or boundary without the request or the body; when the repository uses type prefixes, derive the type from the verified primary change. Do not hide a replacement, a removal, or a direction of change behind an area name or a generic improvement claim. Put supporting changes and the material reasons, constraints, trade-offs, or non-obvious consequences in the body when the subject cannot carry them, and preserve that rationale when amending or consolidating. Check each claim against the committed baseline and the delta, and each reason against recovered motivation. Leave out unsupported causes, file inventories, subject restatements, and narration of investigation, local environment, or skipped checks; those belong in the final report, along with a rejected alternative that only records an attempt. When the implementation is authorized but the diff contradicts the stated motivation, describe the diff and put the contradiction in the report instead of stopping to ask.

`chore: keep package binaries and store on one volume` names the outcome, with a body for the cross-volume store recreation that motivated it. `chore: update package manager path` plus a body restating the move loses the reason.

- Use backticks for code references and keep each pair on one line; a literal longer than the wrap width may exceed it.
- Name another commit's short hash only when the result depends on it, and omit self-references such as "this commit".
- For a standard fixup, keep Git's target-derived `fixup!` subject, or `fixup! <target-hash>` when two commits share a title, so the marker uniquely identifies the recorded target; an unsquashed fixup is not completed consolidation.

## Commit and verify

Resolve active commit hooks through Git configuration, and inspect them before running when their content or execution authorization is not already established for this task.

Recheck `HEAD` and the staged content against the plan. For a message you authored, read it once more: does the subject alone identify the primary change, does the body carry the material meaning and rationale, and does each name you wrote follow the naming rule, leaving quoted text, trailers, and wording the user dictated exactly as given? For a fixup, only check that the generated subject uniquely identifies the recorded target.

```bash
git -C "<delivery-checkout>" commit -F - <<'COMMIT_MSG_END'
<message>
COMMIT_MSG_END
```

For whole-path isolation write the options before `--`, which ends option parsing: `git commit -F - --only -- ':(literal)<path>' ... <<'COMMIT_MSG_END'`. Use `--amend -F -`, or `--amend --only` to leave the index untouched, for an authorized amend, and `git commit --fixup=<recorded-target>` for a fixup; autosquash belongs to its own authorized workflow.

Do not bypass configured hooks, whether through `--no-verify` or by changing `core.hooksPath`. A failing hook may already have changed files, so inspect `HEAD`, the index, and the working tree before any retry, and report the actionable error without exposing protected output.

After success, verify the new commit's parent, tree, and message in the recorded checkout and branch or detached HEAD, and check what its index and working tree still hold. Do not rewrite an unexpected commit automatically: reconcile it within existing authority or report what needs resolving. Reuse the style and motivation already established for further units.

## Report

- Commit: the delivery checkout and branch or detached HEAD, with the short hash and subject of each created or amended commit, or `none` with the blocking reason.
- Included beyond initial staging: paths or hunks included beyond the original index, or `none`.
- Leftover: preserved staged content and remaining modified or untracked paths with their task relationship, counts only for protected or unresolved material, plus any unresolved failure or verification gap. An incomplete requested delivery stays incomplete even when some commits succeeded.
