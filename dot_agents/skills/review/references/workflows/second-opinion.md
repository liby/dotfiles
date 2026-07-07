# Second Opinion Workflow

Load when dispatching independent reviewer subagents in a large or high-risk review, before composing their briefs.

**A dispatched reviewer inherits none of the review skill text loaded in the main context, so the brief must carry the entire contract.** A brief that assumes shared context returns generic, uncalibrated findings.

## Inputs

Pass to each reviewer:

- diff command with scope and base
- changed paths in the reviewer's risk area
- absolute paths of the concern and rule files to read, or the relevant rules inlined
- the Finding Bar threshold
- the `P1`/`P2`/`P3` severity vocabulary

## Scope Each Reviewer

Scope each reviewer to one distinct risk area, and cap each report near 400 words: overlapping scopes duplicate findings without widening coverage, and longer reports leave the aggregator summarizing instead of verifying. Every finding names `path:line`, quoted evidence, impact, and fix direction; the full finding fields are SKILL.md's Output contract, referenced here rather than copied so the two cannot drift.

## Aggregate

Verify every citation against the actual diff or file, then present per-reviewer sections as-is. Do not merge, dedupe, or re-rank findings across reviewers; cross-reviewer re-ranking discards the independent judgment the dispatch exists to produce.
