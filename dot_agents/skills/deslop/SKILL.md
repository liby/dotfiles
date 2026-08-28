---
name: deslop
description: 'Clean changed code, tests, comments, and documentation before final validation: reuse established mechanisms, reduce accidental complexity and cost, remove AI artifacts, and verify type-driven refactors against runtime evidence. Use when the user invokes /deslop or asks to run deslop. Not for correctness review; use /review.'
argument-hint: "[<target>]"
allowed-tools:
  - Bash(git:*)
  - Bash(rg:*)
  - Bash(fd:*)
  - Agent
  - Read
  - Edit
---

Clean the resolved change surface as one workflow. Preserve intended behavior and scope. Treat runtime evidence as a refactor gate, not a bug hunt.

Treat the current production diff as intended behavior, not a provisional artifact; restoring the base is a behavior change. Change production code only with caller, runtime, owning-contract, or exhaustive control-flow evidence that supported behavior remains equivalent. Missing tests, documentation, contracts, or local callers are not evidence. Otherwise leave the behavior unchanged and report the gap.

## Process

1. **Resolve the change surface.** Use a concrete invocation target when present; otherwise use the current change set. Treat an unexpanded dollar-prefixed `ARGUMENTS` placeholder as absent. Read repository instructions and snapshot `git status --short`. For an explicit target, build the narrowest representative diff. Otherwise use the de-duplicated union of the resolved upstream-or-default `base...HEAD` diff, staged diff, and tracked unstaged diff. Screen untracked names before content; never read raw `.env*`, private keys, or credential stores. Treat repository-declared ciphertext as opaque: account for metadata but keep its body out of scope. Include safe, target-owned files as whole-file scope; report unclassified or raw-secret paths under `Candidates left`. If no branch base resolves, use the working tree and report the omitted branch scope. If a working-tree diff fails, report the command and stderr summary, then stop. For empty scope, skip reviewers and return `no changes to review`, `Changed: none`, `Candidates left: none`, and `Validation: skipped, no changes`.

   Done when every path and hunk has a known source, every untracked path has a disposition, and the initial status is recorded.

2. **Classify before mutation.** The invoking session is the sole writer and owns every artifact disposition. When independent review pays for coordination and agents are available, assign read-only reviewers to the quality lenses below; the Complexity reviewer also cross-checks artifact value. If an assigned reviewer fails, cover its lens locally and record `independent quality review unavailable` under `Candidates left`. Put all findings in the same frontier before mutation.

   - **Reuse:** Find duplicates of an existing helper or mechanism. Compare input, output, side-effect, and error contracts before reusing it.
   - **Complexity:** Find derivable state, copied variants, deep nesting, dead code, and Speculative Generality. Name the smaller behavior-equivalent form.
   - **Cost:** Find repeated computation or I/O, unnecessary sequencing, startup or hot-path blocking, and closures retaining excess state. Name the cheaper form.
   - **Abstraction boundary:** Find local special cases or Shotgun Surgery caused by fixing symptoms outside the component that owns the behavior. Name the narrowest fix at the owning boundary inside scope.
   - **Artifact value:** A current-change artifact is newly added, substantively modified, or made directly redundant by this change; whole-file scope alone does not qualify. Give each an evidence-backed keep, rewrite, delete, or candidate disposition. Historical reachability alone is not independent value. After the owning mechanism changes, re-establish the artifact's trigger in current callers, control flow, runtime evidence, or an external contract; otherwise delete a test that only proves a retired failure stays absent, its unreachable guard or fallback, and comments explaining either. Delete any other artifact with no independent value after checking its available owner; reserve candidate for a concrete unavailable owner.
     - **Tests:** Keep a current-change test when it reaches production logic and detects a distinct observable fault or contract across a named input partition and mock boundary, or when the source or declarative shape it checks is itself an external contract. Exact values and external mocks count when they carry that signal. Merge or delete it only when a survivor covers the same production path, input partition, observations, and failure modes; tests of mocks and coverage-only tests have no independent value. In mixed tests remove brittle detail without deleting unique coverage or adding a seam solely for coverage.
     - **Comments and documentation:** Before calling a rationale unsupported, check governing requirements, documentation, fixtures, and issue context; documentation elsewhere does not make a causal constraint redundant at its owning boundary. Keep the shortest verified why, external constraint, or audience-facing contract there. Rewrite an implementation mirror only when evidence supplies that missing reason; otherwise delete mirrors, duplicate rationales, unsupported claims, stale contrasts, current-state censuses, and current-change commented-out code with no independent value. Preserve tool directives as code and a pre-existing comment's original language; apply repository language policy to current-change prose. Prefer names, types, and direct flow for structure.
   - **Other AI artifacts:** Find impossible guards, blanket catches, and speculative fallbacks; type escapes; contract-free one-caller helpers, configuration toggles, compatibility paths, and Middle Men; redundant caching, normalization, or conversion; orphaned symbols; and edited-hunk style drift. A guard, wait, or fallback backed by a governing source is not speculative merely because local coverage is absent.

   For any refactor whose safety depends on static types matching runtime data, including removal of a guard, fallback, optional chain, default, coercion, normalization, or branch, inspect relevant fixtures, samples, generated data, schema documentation, or adjacent parser tests. Keep it only when runtime evidence supports the assumed shape. If data violates the type, restore the behavior and add a short comment naming the dirty-data source. If evidence is absent, leave the code unchanged and record the exact manual observation.

   Done when every lens is covered, every current-change artifact has an evidence-backed disposition, every rewritten or deleted test assertion and partition is accounted for, every kept artifact names its independent evidence, and every runtime-sensitive refactor has evidence or a named gap.

3. **Triage one finding frontier.** Record each finding with path and line, trigger evidence, impact, and disposition. De-duplicate by mechanism. Resolve conflicts by scope and ownership, runtime evidence, intended behavior, structural quality, then comments and style. AI-artifact fixes require ownership by the current change; unclear ownership remains a candidate. Accept production-code edits only with behavior-equivalence evidence. Reject behavior-changing, out-of-scope, runtime-unverified, and false-positive fixes.

   Done when every finding has one disposition and accepted fixes do not conflict.

4. **Close the frontier.** Apply accepted fixes as one coherent patch. Without resolving scope again, recheck affected final hunks against every classification lens and the runtime-contract gate; merge newly evidenced findings into the same frontier. Reclassify only when a mutation or validation result adds trigger evidence. Stop and report on oscillation: the same root cause recurs without new evidence, the next fix would undo a prior fix, or fixes repeatedly create accepted findings in the same mechanism.

   Done when no accepted finding remains and every unresolved item has a concrete candidate reason.

5. **Validate the final state.** Discover the cheapest relevant validation from repository instructions, package or task configuration, build files, and adjacent tests. Run it after the last mutation, scoped to changed files when supported; any later validation-relevant edit invalidates the result. If validation fails, reopen the frontier for failures attributable to this workflow, fix them, and rerun validation. Do not label a failure pre-existing or unattributed without evidence; if attribution requires unavailable external state, record the exact gap under `Candidates left` and stop without unrelated fixes. Do not run dev, start, or serve commands; request the exact runtime observation instead. If no command exists, name the sources searched.

   Done when validation passes on the final state or a precise external, pre-existing, or manual gap is recorded.

6. **Reconcile and report.** Re-run `git status --short` and compare it with the initial scope plus this workflow's edits. Report unexpected new or missing paths under `Candidates left`; do not reconcile them silently. Always return:

   - `Changed:` each edited file and one-line reason, or `none`; for a deleted or rewritten comment, `path:line` in pre-edit numbering with the removed text or the `before -> after` pair; describe, never quote, secret-bearing text
   - `Retained:` only for a current-change test, comment, or documentation block with a keep or rewrite disposition; group by independent fault, contract, or verified rationale and name the production path and mock boundary when relevant. Omit it when there is no such survivor; report candidate survivors only under `Candidates left`.
   - `Candidates left:` ownership, evidence, scope, or stop gaps, or `none`
   - `Validation:` command and result, or skipped reason

   Done when every required label describes the final working tree after the last validation-relevant mutation.
