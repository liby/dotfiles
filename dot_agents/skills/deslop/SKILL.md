---
name: deslop
description: 'Clean changed code before final validation: reuse established mechanisms, reduce accidental complexity and cost, remove AI artifacts, and verify type-driven refactors against runtime evidence. Use when the user invokes /deslop or asks to run deslop. Not for correctness review; use /review.'
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

## Process

1. **Resolve the change surface.** Use a concrete invocation target when present; otherwise use the current change set. Treat an unexpanded dollar-prefixed `ARGUMENTS` placeholder as absent. Read repository instructions and snapshot `git status --short`. For an explicit target, build the narrowest representative diff. Otherwise use the de-duplicated union of the resolved upstream-or-default `base...HEAD` diff, staged diff, and tracked unstaged diff. Screen untracked names before content; never read `.env*`, private keys, or credential stores. Include safe, target-owned source files as whole-file scope; report unclear or secret-like paths under `Candidates left`. If no branch base resolves, use the working tree and report the omitted branch scope. If a working-tree diff fails, report the command and stderr summary, then stop. For empty scope, skip reviewers and return `no changes to review`, `Changed: none`, `Candidates left: none`, and `Validation: skipped, no changes`.

   Done when every path and hunk has a known source, every untracked path has a disposition, and the initial status is recorded.

2. **Classify before mutation.** The invoking session is the sole writer. When independent agents are available, assign one read-only reviewer to each of the four quality lenses below, in as few concurrent batches as capacity allows. If a reviewer is unavailable or fails, the invoking session covers that lens and records `independent quality review unavailable` under `Candidates left`. The invoking session checks AI artifacts and runtime-contract risks; all findings enter the same frontier before mutation.

   - **Reuse:** Find duplicates of an existing helper or mechanism. Compare input, output, side-effect, and error contracts before reusing it.
   - **Complexity:** Find derivable state, copied variants, deep nesting, dead code, and Speculative Generality. Name the smaller behavior-equivalent form.
   - **Cost:** Find repeated computation or I/O, unnecessary sequencing, startup or hot-path blocking, and closures retaining excess state. Name the cheaper form.
   - **Abstraction boundary:** Find local special cases or Shotgun Surgery caused by fixing symptoms outside the component that owns the behavior. Name the narrowest fix at the owning boundary inside scope.
   - **AI artifacts, checked by the invoking session:** Find restating or style-divergent comments; impossible guards, blanket catches, and speculative fallbacks; type escapes; contract-free one-caller helpers, configuration toggles, compatibility paths, and Middle Men; redundant caching, normalization, or conversion; orphaned symbols; and edited-hunk style drift.

   Judge tests and comments by contract value. Remove comments that restate code or narrate superseded attempts; consolidate rationale at its owning boundary and rewrite live constraints in present tense. Delete a test only when a named survivor covers the same input partition, production path, observations, and failure modes, establishing exact duplication, a strict assertion subset, or zero marginal fault-detection contribution; prefer representative production mutants, and never treat a green suite as evidence. Rewrite vacuous or over-mocked tests when a contract remains. Preserve unique regressions and behavior partitions, characterization/conformance tests, interaction/order/no-throw/registration contracts, public documentation, tool directives, security/concurrency rationale, dirty-data sources, and active workarounds. If evidence is absent, leave unchanged and record the exact gap.

   For any refactor whose safety depends on static types matching runtime data, including removal of a guard, fallback, optional chain, default, coercion, normalization, or branch, inspect relevant fixtures, samples, generated data, schema documentation, or adjacent parser tests. Keep it only when runtime evidence supports the assumed shape. If data violates the type, restore the behavior and add a short comment naming the dirty-data source. If evidence is absent, leave the code unchanged and record the exact manual observation.

   Done when all four lenses and the AI-artifact checks have been applied, every finding has evidence, and every runtime-sensitive refactor has runtime evidence or a manual gap.

3. **Triage one finding frontier.** Record each finding with path and line, trigger evidence, impact, and disposition. De-duplicate by mechanism. Resolve conflicts by scope and ownership, runtime evidence, intended behavior, structural quality, then comments and style. AI-artifact fixes require ownership by the current change; unclear ownership remains a candidate. Reject behavior-changing, out-of-scope, runtime-unverified, and false-positive fixes.

   Done when every finding has one disposition and accepted fixes do not conflict.

4. **Close the frontier.** Apply accepted fixes as one coherent patch. Without resolving scope again, recheck affected final hunks against the four quality lenses, the AI-artifact checks, and the runtime-contract gate; merge newly evidenced findings into the same frontier. Reclassify only when a mutation or validation result adds trigger evidence. Stop and report on oscillation: the same root cause recurs without new evidence, the next fix would undo a prior fix, or fixes repeatedly create accepted findings in the same mechanism.

   Done when no accepted finding remains and every unresolved item has a concrete candidate reason.

5. **Validate the final state.** Discover the cheapest relevant validation from repository instructions, package or task configuration, build files, and adjacent tests. Run it after the last mutation, scoped to changed files when supported; any later validation-relevant edit invalidates the result. If validation fails, reopen the frontier for failures attributable to this workflow, fix them, and rerun validation. Do not label a failure pre-existing or unattributed without evidence; if attribution requires unavailable external state, record the exact gap under `Candidates left` and stop without unrelated fixes. Do not run dev, start, or serve commands; request the exact runtime observation instead. If no command exists, name the sources searched.

   Done when validation passes on the final state or a precise external, pre-existing, or manual gap is recorded.

6. **Reconcile and report.** Re-run `git status --short` and compare it with the initial scope plus this workflow's edits. Report unexpected new or missing paths under `Candidates left`; do not reconcile them silently. Always return:

   - `Changed:` each edited file and one-line reason, or `none`
   - `Candidates left:` ownership, evidence, scope, or stop gaps, or `none`
   - `Validation:` command and result, or skipped reason

   Done when all three labels describe the final working tree after the last validation-relevant mutation.
