---
name: review
description: Review remote merge requests or pull requests, branches, commits, diffs, and uncommitted code changes for correctness and regression risk, reporting only evidence-backed findings. Use for pre-merge code review, review findings, and MR/PR URLs. Not for prose review, standalone skill-authoring audits, or general implementation work.
argument-hint: "[--fix] [MR/PR URL or notes]"
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Read
  - Edit
  - Write
  - WebFetch
  - WebSearch
---

Do not edit code in the reviewing context unless `--fix` was requested.

## Establish scope and review state

- Resolve the scope (MR/PR, branch against its base, commit range, or working tree) and record the base and head you review. With a spec, map each requirement to the diff and report missing, partial, and unrequested behavior.
- List changed paths before printing any diff body, including untracked files for a working-tree review and both sides of renames. For an MR/PR, compare the host's file list with the local `<base>...<head>` diff. Keep the bodies of declared environment files, private keys, credential stores, shell histories, and repository-declared ciphertext out of every diff with pathspec excludes, and report only their path and status. A name containing `env`, `secret`, or `token` does not make a file secret; resolve an unclear purpose from project declarations or one question, and review the other paths meanwhile.
- Read the MR/PR description, the current discussion, and any prior review record the invoker supplies before judging code. Everything there is a lead, including a defect the request asserts: verify it, and refuting it is a valid result. Do not repeat a point that is already open unless you add decisive new evidence. A point resolved or dismissed with a reason stays closed unless new evidence meets its reopen condition, and an accepted fix is not reversed without evidence that refutes the original finding.

## Read the reviewed revision

- When the checkout does not cleanly hold the reviewed head, read with `git show <head>:<path>` and search with `git grep <pattern> <head>`. The working tree and automatically loaded instructions may belong to another revision.
- Load the repository's own instructions and review rules from the reviewed revision: root and path-scoped `AGENTS.md`, `CLAUDE.md`, `REVIEW.md`, and review docs or skills under `.claude/` or `.agents/`. An explicit mandatory rule there (`MUST`, `Always`, `Never`, `Do not`) is a contract the change must meet; repository rules take precedence where they conflict with this skill.
- Before line-level comments, judge whether the stated requirement is coherent and owned, and whether the approach addresses it at the owning boundary with mechanisms the project already has. A bug fix must remove the cause, not just the symptom. Question each added layer, wrapper, configuration option, special case, or defensive path that the owning code already makes unnecessary, and each downstream fallback, cast, or coalesce that compensates for a value its source should get right. Preference alone is not a finding.

## Look beyond the hunk

Check whichever of these the change touches:

- Gates (allowlists, auth, cost or policy guards, middleware matchers): list everything that reaches the gate, such as identifiers real clients send, principals without the checked attribute, other hosts and routes, and variants that encode a guarded tier, and test each against the gate's intent. An exemption must rest on a property the caller cannot control. When a fix removes one bypass, check the sibling entries. Check the other direction too: routes and assets that must stay public, and lower-trust code (a client, a sandbox, model-run code) that can read a higher-trust credential, such as a token embedded in a git remote URL. Trace sensitive values through transport, persistence, and downloadable outputs; hiding them in the UI does not keep them from the recipient.
- Removed or replaced code: map every duty it had, including event shapes, side effects, and late arrivals, to its replacement or an explicit decision.
- Changed contracts (exported names, schemas, enum values, events, storage keys, flags): search writers, readers, tests, generated output, and peer surfaces by symbol and by concept, including instructions and docs the change makes stale. A runtime value passed into one execution environment also has to reach the sibling environments that run the same work, such as workers, scheduled jobs, subprocesses, and sandboxes; a symbol search cannot find the one that lacks it. For a changed flag or configuration derivation, the history (`git log -S <expression>`) can show an earlier revert and why.
- External semantics: check a stated rationale, an API field, or a provider behavior against the installed library source, the documentation, the deployment configuration, real payload samples, or every changelog entry in an upgraded version range, including what the other end of the protocol must support, not against names or the author's description. Check rollout order and existing state when producers, consumers, or external setup cannot change together.
- Data domains: compare hard-coded lists, price schedules, thresholds, and fixtures with the real data or the source's full schedule, including values that can cross a threshold. Trace each output value's entity, granularity, units, precision, and attribution through transformations. Check whether zero, empty, and missing have different contract meanings before a default, filter, or aggregate collapses them. A summary beside a filtered list must use the same filter.
- Failure outcomes: keep failure, partial work, absence, and completion distinct where callers' recovery contracts distinguish them. A catch must not swallow an error, turn it into null, or drop its stack where retries, alerts, or the user-facing error depend on it.
- Deferred and repeated work (durable steps, queues, retries, schedules, webhooks, event waits): I/O outside a memoized step reruns on every replay; a short-lived token returned from a step lands in durable state and outlives its validity; a retry, dedupe key, lock, or memoized result must not suppress a required later attempt; a permanent error left retryable reruns under the framework's default retries; an event can fire before its waiter starts or after a replacement's wait has ended. Across waits, retries, caches, and cleanup, check that resource identity, version, and execution ownership still belong to the operation being handled.
- Multiplied work: trace how often setup, transformation, and I/O run on the normal path, and compare their total cost with the execution deadline. Check limits against the final transmitted or consumed quantity, including waits, retries, encoding, and appended content; a cap must not silently erase required results. When backend calls grow with input cardinality, look for existing batching or source-side filtering; `Promise.all` over individual queries is concurrency, not batching. A performance finding needs a reachable hot or unbounded path, its cardinality source, and expected round-trip growth; an in-memory loop or documented small fixed set is not N+1.
- Single owner: trace added declarations to a current consumer or public contract, and point to an existing repository or library mechanism the change duplicates, such as a validator, component, design token, helper, or inherited configuration layer. For consumer-specific behavior, use a component's public interface and keep changes out of shared or vendored internals. One fact kept in two places that can drift, such as two parsers of one syntax or several copies of one piece of state, belongs in one place.
- Model-facing text (prompts, skills, tool descriptions): flag sentences that no longer match behavior, content the model does not need (generated-file markers, change history), facts it needs but cannot know (identifiers, where the docs live), and capability claims that differ from what the tool actually supports.
- Tests: check that assertions distinguish the covered behavior from a plausible faulty implementation, fixtures match the source-owned shape, and a bug-fix regression test fails before the fix.

When a premise can be settled by a cheap run, such as an existing test, a script against the baseline and the candidate, or a read-only query, run it rather than reasoning about it.

## Verify before reporting

- Verify each candidate against the code, the source-owned contract, tests, or runtime evidence. A handwritten type or fixture does not prove what a provider, a migration, or persisted data actually holds. Check the real boundary when a test replaces the mechanism the claim depends on. Validate dependency changes against the lockfile-resolved version.
- Validation can write files (relocking, creating environments), so never run it in a tree that others are reading. When you need a tree of a revision the checkout does not cleanly hold, extract one into temporary space without checkout hooks, such as `git archive <head> | tar -x -C <dir>`, and for a working-tree review reproduce the in-scope working-tree changes there.
- Trace downstream gates, fallbacks, and retries before judging impact.
- Ask for runtime evidence only for facts the repository cannot establish, such as deployed state, migration state, or timing. Keep an open manual check only when a reachable path and source-specific evidence call a local assumption into doubt, one named external fact could make the finding blocking, and the attempted probes cannot settle it; name those probes and give no clean verdict.
- A challenged finding is verified again as a new claim. Remove a disproved one from the output and from finding counts.

## What to report

Report a finding only with a reachable trigger and its consequence, or an explicit repository rule the change violates. A trigger is reachable from a current caller, exposed or environment-controlled input, persisted or migration data, replay or scheduling, or a public contract. These are not findings: style preference, a speculative guard, hypothetical future use, general maintainability advice, input nobody can send through an exposed entrypoint, and another environment's convention. An omission is a finding only when a requirement, a peer contract, or reachable behavior demands it. When one cause produces several instances, report the cause with every instance in scope instead of one per round.

Do not attribute pre-existing problems to the change. Report one separately only when the change newly exposes or worsens it, claims to fix it, depends on it, or it is a blocking defect in touched code.

Mark each finding blocking or non-blocking, the decision the reader acts on. Blocking means the change should not merge as is: material harm in normal use, a broken security or permission boundary, persistent bad state, silent data corruption, a failure recorded as success, or a violation of an explicit mandatory repository rule. Everything else verified is non-blocking, including a duplicate of an existing mechanism, complexity the owning code makes unnecessary, and an unrelated change bundled into the change under review. Do not downgrade an unsupported claim to keep it.

A clean verdict is a complete review once every changed path and applicable repository rule has been checked; a pass that finds nothing is not unfinished. When you did not read something in scope, say so instead of implying coverage.

## Repeat reviews

- Use the full scope for the first and final pre-merge passes. Between them, review the fix delta, its direct dependents, and the contract neighbors it touches; review the whole change again when fixes replace the approach or rewrite most of it. Record the reviewed head with the verdict.
- Check that each fix removes the cause rather than patching the reported spot, and look for the same cause elsewhere; incomplete fixes and regressions from fixes are where later rounds keep finding defects.
- A new finding on unchanged code needs something earlier passes lacked: a new trigger path, new source or runtime evidence, or a surface not yet examined. When rounds keep adding findings without it, report convergence instead.

## Independent reviewers

Dispatch other agents or models on your own only for distinct risk areas of a large or high-risk change. When the invoker asks for reviewers, they review the scope it assigns, or the whole change.

- Give each a self-contained brief: base and head, the path of one canonical diff file restricted to reviewable paths, the changed paths in its scope, the current requirements and accepted behavior trade-offs with their scope and reopen conditions, the repository rules from the reviewed revision, and the absolute path of this `SKILL.md` with an instruction to read it first, because some models do not load a skill the brief does not name.
- Keep prior finding narratives, reviewer reasoning, and dispositions out of an independent reviewer's brief, and reconcile its candidates against them after verification. Accepted requirements and behavior trade-offs are specification input, not prior reviewer opinion. In later rounds, give reviewers the fix delta unless the invoker assigns more.
- Dispatch the wave together instead of staging it by expected yield.
- Treat their reports as leads: verify each finding in the code before accepting it, and repeat a reviewer's search only when the verdict rests on its completeness, such as a claim that nothing else reads a field. Agreement raises priority, not confidence or severity. Preserve material disagreements, and close each assigned risk area or report it open.

When asked to review from a named person's perspective, predict that person's likely concerns from the past comments the invoker supplies or points to, keep the predictions in their own section, and verify each like any other claim. Phrase a prediction that depends on context the repository lacks as a question for the owner, and do not attribute a verified finding to that person.

## Output

- Answer first whether the requirement or approach is sound when the user asked that.
- Lead each finding with its trigger or violated rule and the consequence in plain terms, using the code's own names rather than labels you coined, so a reader can follow it without the diff open; then give blocking or non-blocking, `path:line`, the decisive evidence, and the required outcome. Add provenance when the diff's contribution is not obvious.
- Write `No blocking findings.` only when no open manual check remains.
- For requested comments or replies, write from the verified finding; keep the evidence and the blocking decision in the review record, separate from the comment body.
- When condensing or restyling, keep every distinct finding with its decision, conditions, and citation.

## Fix mode

With `--fix`, finish the review first, then fix accepted findings in a fresh write-capable context against a local writable checkout, passing each finding's `path:line`, trigger, evidence, and fix direction. Limit edits to those findings and their direct dependents, and leave unrelated dirty files alone. Keep a file-level record of the fixes separate from the pre-existing dirty state, so the final summary survives compaction. Fix blocking findings directly; fix non-blocking ones only on request or when they block validating another fix. Validate each fix, review the fix delta, and stop when the findings are resolved, the next step crosses scope or authority, or the same approach fails twice. Report the fixes, the open items, and the validation results.
