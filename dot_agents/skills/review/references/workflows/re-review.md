# Re-Review Workflow

## Scope

- Between the first pass and the final pre-merge pass, review the fix delta: changes since the last reviewed head, their direct dependents, and the contract neighbors those fixes touch. A risk area closed on a previous head stays closed unless the delta materially touches it or new evidence reopens it.
- The first pass and the final pre-merge pass use the full scope; the final pass stays cheap because dispositions and the repeat-review rule in Finding Bar apply.
- Record the reviewed head with the verdict so the next round can resolve its delta.

## Prior review state

Split what enters the main review and an independent delegated review:

- Pre-read deliberate decisions: accepted trade-offs and behavior choices that change correctness judgment, each with the evidence that would reopen it. These are specification input, not reviewer opinion.
- The coordinator or single-context reviewer reads the current discussions under the main Flow before judging implementation, then records one semantic claim and disposition per issue so an existing point is not repeated without different evidence, consequence, or insight.
- An independent delegated reviewer does not receive prior finding narratives, reviewer reasoning, full discussion transcripts, or dispositions before discovery. Keep that state with the coordinator and reconcile the independent candidates during post-verification dedup.
- An accepted fix from a prior round is itself review state: recommending its reversal requires evidence that refutes the original finding, not a fresh preference.

A disposition record is one line per semantic claim: key, status (`fixed` or `dismissed`), one-line basis, reopen condition. The invoker owns storage and pruning; per-change records die with the change. A decision that recurs across changes belongs in the repository's own instructions, promoted by its owner, not by a reviewer.

## Completion

The re-review is complete when every relevant risk area is closed on the final head and no new finding passes the Finding Bar; report convergence. Whether to buy more assurance is the invoker's call; spend it on an independent second opinion or an unexercised risk area, not on rerunning the same pass.
