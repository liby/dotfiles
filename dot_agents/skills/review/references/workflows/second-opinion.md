# Second Opinion Workflow

Load when dispatching independent reviewer subagents in a large or high-risk review, before composing their briefs.

Write the scoped diff, restricted to paths classified ordinary in the Flow, to one temp file first; it is the canonical diff for this review, and opaque ciphertext stays path-and-status only. Do not rely on inherited context. Pass each reviewer:

- the canonical diff file's absolute path, with the base and scope it was built from; the file replaces regenerating the diff, not source inspection, so reviewers still read surrounding code, callers, and tests to verify findings
- changed paths in the reviewer's risk area
- paths to temp copies or bounded extracted content for the applicable repository instructions and project review files from the reviewed revision, plus absolute paths of this skill's `SKILL.md` and matching concern and rule files, with instructions to read them; never point a reviewer at an instruction file from a different checkout revision, and if file access is unavailable, inline the repository rules, Finding Bar, material-validation-gap rule, Output contract, and severity vocabulary

Assign distinct risk areas and dispatch the initial wave in one message so reviewers run in parallel; do not stage it by expected yield. A brief presupposes no defect and carries no prior finding dispositions. A targeted follow-up wave on verified findings is fine. Request concise candidates satisfying SKILL.md's Output contract, and require each reviewer to close every assigned risk area and repository rule as a supported finding, checked with no finding, or not exercised by this diff, citing the diff for the latter two. Never omit a supported `P1`/`P2`, repository conformance finding, material disagreement, or verdict-changing missing fact for brevity.

Treat reports as candidate sets, not evidence. Verify every citation and shared premise; reproduce a reviewer's specific search only when the verdict depends on its completeness, such as an absence claim, because rerunning sweeps wholesale collapses the dispatch back into a single-agent review. Agreement raises investigation priority, not confidence or severity. Deduplicate, and reconcile candidates against any supplied prior dispositions, only after verification; preserve material disagreements.
