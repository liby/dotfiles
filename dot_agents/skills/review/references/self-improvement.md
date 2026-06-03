# Self-Improvement

Use at the end of every review or fix run, and when the user asks to evolve the skill.

## Retro Check

At the end of every review or fix run, decide whether the run produced a reusable lesson. Record a private candidate when one answer is yes:

1. Did the skill miss a reusable issue shape?
2. Did it produce a false positive, unclear finding, or confusing output?
3. Did `--cx` or another reviewer expose a useful disagreement pattern?
4. Did `--fix` skip, overreach, or struggle because the policy was underspecified?
5. Did a concrete check save the review and deserve reuse?

Skip ordinary findings, one-off project facts, taste preferences, and anything already covered by an existing rule.

For long or multi-round runs, record a candidate immediately after the event that proves it. Compaction should not erase why the lesson mattered.

Record every qualifying candidate through the SQLite path in [review-memory.md](review-memory.md). If the script is unavailable or the write fails, say `private review-memory unavailable: <reason>`.

Use `review-memory record-run` after the final review verdict. Use `review-memory propose-rule --type <candidate type>` only after a repeated root cause is clear; pass the matching type from Candidate Types below. If many candidates share the same trigger and failure mode, merge them into one proposal instead of creating patch-log rules.

## Candidate Types

Types:

- `Recurring miss`: same bug shape, contract drift, or misleading output appeared more than once.
- `Near miss`: a reusable check prevented a miss.
- `False positive`: evidence did not support the finding.
- `Delegate signal`: a second-opinion path exposed a useful or misleading pattern.
- `Fix drift`: `--fix` crossed, or nearly crossed, the accepted finding boundary.
- `Codified rule`: an entry became reusable skill text.

Point to long evidence instead of pasting it. Return a `Self-improvement candidate` section only when it does not violate the user's exact output contract, or when the private SQLite write failed and the user needs to know it was not recorded. Public skill files receive only distilled rules.

## Distillation

When the user asks to evolve the public skill from recorded candidates:

1. Export a SQLite proposal with `review-memory pack <proposal-id>`.
2. Cluster by repeated trigger and failure mode.
3. Drop one-off project facts.
4. Convert survivors into generic trigger and concrete check.
5. Place the rule in the smallest useful destination:
   - `SKILL.md`: every review needs it.
   - `references/core-principles.md`: recurring review mechanism.
   - `references/responsibility-checks.md`: responsibility-specific check.
   - `references/cx-delegation.md`: second-opinion workflow.
   - `references/fix-policy.md`: mutation boundary or verification policy.
6. Run a regression pass:
   - positive examples the rule should catch,
   - negative examples old behavior should keep,
   - output examples that stay clear and evidence-based.
7. Mark source entries `codified` only after the rule exists and the regression pass holds.

Distill a lesson into public skill text only when it has cited evidence, a future trigger, a concrete check, a destination under an existing broader rule or a reason that broader rule is missing, and at least one regression example that should stay unchanged.

When distilling an evaluator or verifier lesson, write it as a rubric entry, not a story: trigger, required evidence, FAIL or stop condition, PASS condition when useful, owner or runtime boundary, and regression examples. If the lesson depends on transcript evidence, cite the transcript or rollout summary as the evidence source but copy only the reusable failure mode into public skill text.

During a normal review, the skill may record private candidates but must not edit public skill files. Public skill changes require a user request for skill evolution or supplied entries for distillation.
