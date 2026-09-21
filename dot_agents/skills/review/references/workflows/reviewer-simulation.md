# Reviewer Simulation Workflow

Load only when the caller explicitly asks to simulate a named reviewer and a local profile supplies that reviewer's corpus. The profile owns the reviewer handle, corpus paths, sampling policy, and any private repository mapping; do not add those values to this reusable skill.

This mode predicts a reviewer's likely comments. It does not claim to reproduce the person's beliefs, and agreement with prior comments is not evidence that a current candidate is correct.

## Inputs and isolation

Use the normal Flow to classify paths before reading bodies. The simulation input is the current MR/PR description, ordinary diff, existing discussions, applicable repository instructions, and the local profile's permitted corpus samples. Do not read opaque ciphertext or raw secrets to improve a prediction.

For a backtest, exclude every comment, reply, later revision, and corpus record from the target change at or after the prediction cutoff. Record the target, cutoff, sampled corpus ids, profile identity, model, prompt identity, and source revision before generating candidates. If the exclusion cannot be proved, label the run contaminated and do not use it as held-out evidence.

## Candidate prediction

Infer patterns from cited corpus examples; do not convert a person's name, reputation, or a generic style adjective into a rule. Produce a ranked candidate set before the normal finding pass. For each candidate record:

- the predicted semantic concern and the current-change evidence that triggered it;
- cited corpus precedent ids and the shared reasoning pattern;
- confidence as `high`, `medium`, or `low`;
- information dependency as `repository-visible` or `private-context-needed`;
- whether an existing discussion already covers the same claim.

Use `private-context-needed` when the prediction depends on company knowledge, business context absent from the reviewed sources, inaccessible SaaS state or permissions, a private prior design, an unrecorded leadership decision, or personal preference. Phrase it as a question for the reviewer or owner, never as fact. Repository-visible candidates may still be wrong and remain predictions until independently verified.

## Verification and output separation

After prediction, run the normal review against repository-owned evidence. Treat every predicted candidate as a lead subject to the same Finding Bar as any other claim; reviewer precedent cannot satisfy provenance, reachability, decisive evidence, consequence, or severity. Drop disproved candidates and deduplicate against existing discussions under the main Flow.

Render two separate records when the caller requests both simulation and review:

1. `Predicted reviewer candidates`: ranked predictions with confidence, dependency, current trigger, precedent ids, and existing-discussion disposition. State that these are simulated candidates, not the named reviewer's actual opinions.
2. `Verified review`: only findings that pass the normal Finding Bar, or the normal clean verdict. Do not imply that a surviving finding came from the named reviewer.

## Backtest scoring

Reveal withheld comments only after the prediction record is frozen. An adjudicator maps predictions and actual comments by semantic claim, records one-to-one matches, and classifies unmatched actual comments as `repository-visible`, `private-context-needed`, or outside the requested review scope. Report:

- recall = matched repository-visible actual claims / all repository-visible actual claims;
- false-positive proportion = unmatched repository-visible predictions / all repository-visible predictions;
- private-context categories and counts, separately from recall;
- contaminated or unjudgeable cases, without folding them into either numerator.

Compare the same targets, cutoffs, inputs, runtime, and adjudication rules against the frozen baseline. A result is not evidence of improvement when only the candidate receives the reviewer corpus, the target's later state leaks into either arm, or the comparison substitutes style preference for semantic matches.
