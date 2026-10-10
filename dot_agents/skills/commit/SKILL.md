---
name: commit
description: Create or amend local Git commits from the relevant changes. Use for every commit operation, regardless of how the request arrived, which repository it targets, or what tooling wraps git. Stage only in-scope files and write repository-matching messages. Not for message drafts or branch creation.
argument-hint: "[additional context]"
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Read
  - Write
---

## Authority and target

- Commit when the user asked for one or the requested workflow needs one, such as creating an MR/PR or an explicitly requested release step. An implementation request alone does not need a commit; report the prepared state instead.
- Honor explicit scope, grouping, staged-only choices, and amend or fixup targets without asking again. A fixup does not authorize a later rebase or autosquash.
- Resolve the delivery repository, checkout, and branch or detached HEAD from the request and source ownership, not from the cwd: linked worktrees share a repository but not a delivery state. Use plain `git` when the call already runs inside that checkout, and `git -C <checkout>` only when it does not.
- Pass each path as its own quoted `':(top,literal)<path>'` argument, so it resolves from the checkout root and glob characters such as `[id]` stay literal; `--` does not stop pathspec matching. Do not set literal pathspecs process-wide, which also changes Git calls inside hooks.
- Never stage or commit secret plaintext or content that may be secret and is unresolved, including content an earlier step already staged: if a staged-only commit would include it, stop and leave the index as it is. Keep established ciphertext bodies out of every diff.

## Decide the unit

Check for an in-progress merge, cherry-pick, revert, or rebase, and finish one only when that is authorized. Read staged, unstaged, and untracked state separately, and what each hunk delivers against the committed baseline. Record `HEAD` (or the unborn branch) and the original index before any mutation.

One commit is one piece of work: what the user is pursuing on one subject, however many turns and requests it takes, including the review, correction, extension, or simplification they ask for along the way. Its scope follows what the user pursues and asks to review, not only the feature first requested or the lines first committed: fixes to existing behavior inside that scope belong to it, while sharing a file or component does not bring in a defect noticed incidentally. Implementation, migration cleanup, tests, and the guidance documenting them belong together, and so do separate causes found for the problem it addresses. Different paths, types, or root causes, independent revertibility, which commit introduced the corrected lines, and a subject that has to name the shared outcome rather than each change do not justify a split. Split work on a different subject and a defect outside that scope, such as one noticed along the way, unless the user bundled it; follow an explicit request for separate commits.

When a commit on this branch already holds the same piece of work and is not another author's, fold the new changes into it instead of adding a commit: amend it when it is `HEAD`, otherwise create a fixup against it. Choose that target by the piece of work the changes belong to under that scope, not by which commit introduced the lines they correct. An unpushed target needs no further authorization. A target that a remote-tracking branch already contains needs the user's authorization to rewrite published history; without it, the changes get a new commit. For an amend, judge the replacement against the target's parent (the empty tree for a root commit), so rationale that must survive is carried over. For a fixup, verify the changes belong to the target's piece of work; never substitute the current `HEAD` or rewrite intervening commits.

## Stage exactly the unit

The index belongs to the user and may hold another session's work. Do not add, remove, or temporarily alter an entry outside the unit, and do not rely on restoring it afterwards.

- Staged-only request: commit the index as it stands; a partially staged file is not a blocker.
- Deliberate batches or hand-picked hunks: that boundary holds even when the remaining edits concern the same feature.
- Unstaged work that the conversation or tool evidence shows completes the same delivery: include it. Leave anything else intact, and ask only when missing attribution blocks an exact commit.

An ordinary `git commit` takes the whole index; choose by what the unit's paths and the index hold:

- Each unit path's working tree holds exactly what to commit and its index entry holds nothing excluded: `git commit --only` with those paths commits their working-tree content and keeps other index entries. A new file must be added to the index before `--only` can name it.
- Otherwise, when the index holds nothing outside the unit: stage the rest of the unit, such as with `git apply --cached` for hunks, and commit the index.
- Otherwise: build the commit from a separate index that holds the whole unit, setting `GIT_INDEX_FILE` in the same call as every command that uses it, because environment does not carry between calls; that call cannot be plain `git`. Then reconcile the shared index for the unit paths with the new commit, keeping excluded hunks that were staged there, so a later ordinary commit cannot revert the unit.

`git commit --amend --only` with no paths amends without taking staged changes. If no method preserves the boundary, stop before mutating and report the conflict.

## Write the message

Read any message configuration and several recent non-merge messages written by people (not bots) in this repository, narrowed with `-- <changed paths>` when the convention varies by area, and follow their language, tense, subject case, and scope or type prefix; the user's exact wording and repository instructions come first. Only when nothing establishes a convention, use an imperative subject near 50 characters without a trailing period and a body wrapped near 72; accuracy beats length.

The subject alone, without the request or the body, must tell a repository reader the primary changed behavior or boundary. Lead with the verb that names the change, such as allow or deny for a permission, add or remove for a capability, require, stop, or rename for a behavior; `let`, `make`, or `have X do Y` narrates what something can now do and hides the kind of change. Do not hide a replacement, removal, or direction of change behind an area name or a generic improvement claim. When the repository uses type prefixes, derive the type from the verified primary change, not the verb: allowing or adding something that should already have worked is still a fix.

Before writing the body, name why each change is in this commit. A diff shows what changed, not why; when the request and conversation do not state a reason, a body that restates the change does not supply one. Recover it from the repository when the branch's own work does not explain the change, and from the earlier session where it was settled when that happened with another agent, in another directory, or in an earlier conversation; take only the reason from there, because the current diff decides what changed. If specific searches find nothing, ask one specific motivation question.

The body carries supporting changes and the material reasons, constraints, trade-offs, and non-obvious consequences, and keeps that rationale through amends and consolidation. Check each claim against the baseline and the delta. Leave out unsupported causes, file inventories, restatements of the subject, and narration of the investigation, local environment, rejected attempts, or skipped checks; those go in the final report. When the diff contradicts the stated motivation, describe the diff in the message and put the contradiction in the final report instead of stopping to ask.

`chore: keep package binaries and store on one volume`, with a body naming the cross-volume store recreation that motivated it, states the outcome and its reason; `chore: update package manager path` with a body restating the move loses the reason.

- Use backticks for code references and keep each pair on one line; a literal longer than the wrap width may exceed it.
- Name another commit by short hash only when the result depends on it and a remote-tracking branch already contains it; amend, fixup, and rebase change unpushed hashes, so name those by subject. Omit "this commit".
- A fixup keeps Git's generated `fixup!` subject, or `fixup! <target-hash>` when two commits share the target's title. An unsquashed fixup does not complete a requested consolidation.

## Commit

Resolve commit hooks through Git configuration and inspect them before they run unless their content and execution are already established for this task.

Right before committing, recheck `HEAD` and the staged set against the plan for both extra and missing content, since another session may have committed or staged in between; for an amend, check the whole replacement against the target's parent. Reread a message you wrote: does the subject alone identify the primary change, does the body carry the rationale, and does each name follow its owner's spelling, with quoted text, trailers, and dictated wording left exact?

Write the message to a new file in runtime-provided temporary space, then commit in a call of its own that passes the absolute path the write returned, not `$TMPDIR`, which can resolve differently between calls. Keep that call a plain `git` invocation where the mechanism allows: a here-document, substitution, pipe, redirection, environment assignment, `-C`, or second command makes some hosts confine the whole call, and hooks or signing then lose the network and Git-directory access they may need. Put options before `--`; everything after it is a pathspec.

```bash
git commit -F <absolute-message-file>
git commit -F <absolute-message-file> --only -- ':(top,literal)<path>' ...
git commit --amend -F <absolute-message-file>
git commit --fixup=<recorded-target>
```

Never bypass hooks or signing, whether by `--no-verify`, `--no-gpg-sign`, or overriding `core.hooksPath`, `commit.gpgSign`, or `gpg.*`. When a hook or signing fails, inspect `HEAD`, the index, and the working tree before any retry: a failed signature creates no commit, but hooks that ran may have changed the index or working tree; recover the signer or report the failure, and never retry unsigned.

After success, verify the new commit's parent, tree, and message in the recorded checkout and branch or detached HEAD, and what that checkout's index and working tree still hold. Do not rewrite an unexpected commit automatically; reconcile it within existing authority or report it.

## Report

- Commit: the delivery checkout and branch or detached HEAD, with the short hash and subject of each created or amended commit, or `none` with the blocking reason.
- Included beyond initial staging: paths or hunks added beyond the original index, or `none`.
- Leftover: preserved staged content and remaining modified or untracked paths with their relation to the task, counts only for protected or unresolved material, and any unresolved failure or verification gap. A requested delivery stays incomplete while any of its commits is missing.
