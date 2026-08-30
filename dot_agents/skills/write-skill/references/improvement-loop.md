# Evidence-Driven Improvement Loop

## Establish the evidence

Define the target behavior, owning instruction root, and qualifying evidence before editing. For a claimed complete time-window, all-skill, or all-session audit, enumerate the qualifying owning roots and account for each root through its terminal user outcome, including dissatisfaction or correction and any accepted successor. Report unresolved roots as coverage gaps; activation counts and sampled traces may prioritize reading but cannot prove complete coverage.

For transcript-derived evidence, exclude duplicated forked or replayed material from independent counts. Treat quoted, pasted, or carried-forward material as context rather than a new preference signal unless the user explicitly adopts it. Pair a rejection with the rejected output and an accepted successor when available.

Weight evidence by what it proves, not by raw volume:

- Strong: a deterministic failure, an explicit user correction with the accepted outcome, or current runtime/source evidence that contradicts the instruction.
- Supporting: the same failure across independent tasks, review feedback tied to a concrete artifact, or repeated defensive reminders traceable to an earlier failure.
- Weak: an isolated preference without an accepted comparison, a defensive reminder with no recoverable failure, invocation counts, silence, or lack of complaint.

One strong case can justify a narrow fix; many weak cases do not justify a rule. Preserve uncertainty instead of converting it into instruction text.

## Diagnose before changing text

- Rule absent: add the general failure mode at the narrowest owner.
- Rule loaded but skipped: sharpen its placement, condition, or done-state; do not restate it elsewhere.
- Rule not loaded: fix routing, ownership, priority, or the reference pointer before rewriting its content.
- Feedback belongs to one repository or session: route it there; do not leak it into a reusable skill.
- A recurring self-authorization derails a step: counter the abstract pattern at that step, not the transcript's wording.

Do not copy the failing instance into the skill; retain it as a regression case. Separate a repeated behavior from an artifact-local correction, and preserve any approach the user already accepted while fixing another issue.

## Compare the smallest candidate

Freeze baseline bytes and evidence cases before editing. Change one owning behavior at a time, remove obsolete or duplicated text in the same diff, and avoid unrelated style rewrites. Use the observed failures for diagnosis and regression; use fresh held-out cases for acceptance.

When Process requires the evaluation protocol, compare the frozen baseline and candidate on the same runtime-visible inputs. For other changes, run the owning validator and the smallest direct reproducer. Present the evidence-to-change mapping and any unresolved trade-off so a human can judge the diff without rereading raw transcripts.

Keep the candidate only when it explains the evidence, belongs to the correct owner, and introduces no paired regression. Stop with no change when evidence is weak or conflicting, the candidate oscillates with an earlier fix, the next edit would undo an accepted constraint, failures are caused mostly by the candidate, or another pass adds no new trigger path or source evidence.
