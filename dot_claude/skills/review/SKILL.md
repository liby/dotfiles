---
name: review
description: Review a remote MR/PR or local code changes, reporting real issues with evidence-first severity. Use when the user says "review", "code review", "帮我 review", "看看这个 MR", asks for review findings, or provides a MR/PR URL.
argument-hint: "[--cx] [--fix] [MR/PR URL or notes]"
allowed-tools:
  - Bash
  - Read
  - Task
---

# Review

Read, verify, report. Clean verdicts and no-op are valid outcomes. Default review is read-only for the reviewed project: do not edit reviewed files, post comments, start dev servers, or apply fixes in the main reviewer context.

## Flow

1. Resolve scope: MR/PR, branch diff, working tree, or explicit notes.
2. Before reading any diff body, collect changed paths and refuse secret-like names without printing raw paths. Refuse `.env*`, `.env/`, keys, certificates, `.ssh/`, shell history, log files or directories, and names containing `credential`, `secret`, or `token`.
3. List changed files before judging behavior:
   - branch: parse `git diff -z --name-status <base>...HEAD`; for `R*` and `C*`, inspect both source and destination paths before any full diff
   - working tree: parse `git diff -z --name-status HEAD` and `git ls-files -z --others --exclude-standard`; inspect both source and destination for `R*` and `C*`
   - MR/PR: compare host changed files with the local checkout or diff
4. Read local instructions that can change review rules: `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.agents/`, `README.md`, `REVIEW.md`, `CODE_REVIEW.md`, project review commands, and project review skills.
5. Read the MR/PR description and discussions when available.
6. Read touched files, adjacent code, direct call sites, and relevant tests before final severity.
7. For exported identifiers, deleted symbols, schema fields, event names, and shared helpers, `rg` callers, readers, writers, and tests.
8. Load [references/core-principles.md](references/core-principles.md) for matching triggers. Load [references/responsibility-checks.md](references/responsibility-checks.md) only when the diff touches that responsibility.
9. Verify each candidate with code, docs, tests, runtime output, or the cheapest existing validation command that covers the changed path.
10. Report only findings with a concrete trigger path and realistic repository impact.

## Modes

### `--cx`

Load [references/cx-delegation.md](references/cx-delegation.md). The helper supports local changes and GitLab MR URLs only; review other hosts in the main session. Delegates return cited candidates; the main session verifies before forwarding. Delegate agreement is a lead, not proof.

### `--fix`

1. Run the normal review first. Review delegates remain read-only.
2. Classify findings as accepted, skipped, dropped, or manual verification, then freeze the accepted set before any mutation.
3. If `IS_TRANSIENT=1` came from [references/cx-delegation.md](references/cx-delegation.md), report accepted findings and stop. Fixes must run from the intended local branch or worktree.
4. Launch one fresh write-capable fix-orchestrator subagent with the frozen accepted set, repo root, review scope, validation commands, and [references/fix-policy.md](references/fix-policy.md).
5. If no write-capable subagent is available, report accepted findings and do not mutate files.
6. The fix-orchestrator independently triages, edits, validates, reuses its own context for later mutation rounds, and returns a structured summary.
7. The main session reviews that summary and reports changed, skipped, manual, and still-open items.

The main reviewer must not edit reviewed project files. Only the fix-orchestrator may mutate, and only inside a local writable checkout.

## Review Stance

- Evidence before claims: find the source of truth before approving or rejecting behavior.
- No speculative support paths: guards, fallbacks, `undefined`, caches, switches, and helpers need a current caller, contract, test, or observed failure.
- Failure must stay visible: do not turn errors, bad statuses, partial work, or terminal-state ambiguity into success.
- Names, states, boundaries, and config are contract surfaces.
- A changed contract needs a symmetry sweep across writers, readers, callers, generated types, generated artifacts, and direct consumers.
- Tests must prove the invariant, not just satisfy the fixture.
- Changed lines still need a mechanical pass for line-local bugs.

## Finding Bar

Prioritize:

1. Contract and source-of-truth mismatch
2. Semantic mismatch in names, fields, states, events, or API shape
3. Ownership boundary violation
4. Hidden failure, false success, or silent data corruption
5. Security, permission, identity, exposure, or environment-isolation risk
6. Incomplete symmetry across writers, readers, sibling cases, schema variants, generated output, or removed consumers
7. Mechanical bugs in changed lines
8. Tests and docs, only when they prove or hide one of the risks above

Skip pure style, speculative guards, broad maintainability advice, and pattern matches without a concrete trigger path.

## Severity

- `P1`: likely in normal use, breaks a security or permission boundary, leaves persistent bad state, or records a failed operation as successful.
- `P2`: needs specific conditions, but the trigger and consequence are real in this repository.
- `P3`: local, recoverable, low impact, or mainly maintainability with a concrete future failure path.

Downshift when the project does not run in the required mode. Upshift when bad state persists, misleads operators, widens access, or silently affects downstream data.

## Verification

- Control flow claim: read the call path.
- Convention claim: verify adjacent code.
- External contract claim: read the local wrapper, docs, schema, generated type, or tests.
- Runtime claim: observe it directly or mark manual verification.
- Missing-X claim: search the whole ownership chain first.

Discover validation commands from local instructions, `package.json`, `Makefile`, `justfile`, task config, CI workflow, and adjacent tests. Use the cheapest existing command that covers the changed path. Do not run dev/start/serve commands during review.

Require runtime evidence for browser or hydration behavior, cross-tab timing, live identifier equality, DB migration state, UI enablement, external service paging, and terminal states not encoded locally.

## Output

Use Chinese for review prose unless the user gives an exact output contract. Keep code identifiers, file paths, quoted code, commands, and severity tags in English.

Respect exact output contracts: `approve`, `No blocking findings.`, verdict-only, blocker-only, or any user-provided shape.

Open with the highest-severity finding. If there are no findings, say so plainly.

Finding format:

```text
P2 src/path/file.ts:42 conclusion in one sentence

Evidence: `quoted code or exact cited behavior`

Why it breaks: current sequence -> missing or wrong step -> concrete consequence.

Correct fix: root-cause fix direction, including direct dependents when needed.
```

Rules:

- Use repo-relative `path:line`, not a basename.
- Quote only the code needed to prove the claim.
- Explain project-specific terms on first use.
- Prefer one concrete scenario over abstract mechanism.
- Correct fix means root cause plus direct dependents. Flag unrelated rewrites, surrounding refactors, and adjacent cleanup separately.
- Do not narrate review mechanics, tool setup, worktree preparation, or skill rules.

## Evolution

At the end of a review or fix run, and when the user asks to evolve the skill or record a review lesson, use [references/self-improvement.md](references/self-improvement.md).
