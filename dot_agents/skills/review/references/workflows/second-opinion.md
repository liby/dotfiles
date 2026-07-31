# Second Opinion Workflow

Load when dispatching independent reviewer subagents in a large or high-risk review, before composing their briefs.

Do not rely on inherited context. Pass each reviewer:

- diff command with scope and base
- changed paths in the reviewer's risk area
- absolute paths of `SKILL.md` and the applicable concern and rule files, with instructions to read them; if file access is unavailable, inline the Finding Bar, material-validation-gap rule, Output contract, and severity vocabulary

Assign distinct risk areas and request concise candidates satisfying SKILL.md's Output contract. Never omit a supported `P1`/`P2`, material disagreement, or verdict-changing missing fact for brevity.

Treat reports as candidate sets, not evidence. Verify every citation and shared premise; agreement raises investigation priority, not confidence or severity. Deduplicate only after verification and preserve material disagreements.
