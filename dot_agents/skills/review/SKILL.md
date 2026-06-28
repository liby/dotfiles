---
name: review
description: Review a remote MR/PR or local code changes, reporting real issues with evidence-first severity. Use when the user says "review", "code review", "帮我 review", "看看这个 MR/改动/diff", asks to look over a branch, commit, or diff for problems before merging, asks for review findings, or provides an MR/PR URL. Not for prose review, skill-authoring audits, or ordinary implementation.
argument-hint: "[--fix] [--html] [MR/PR URL or notes]"
allowed-tools:
  - Bash
  - Read
  - Agent
---

# Review

Read, verify, report. Clean verdicts and no-op are valid outcomes. Default review is read-only for the reviewed project: do not edit reviewed files, post comments, start dev servers, or apply fixes in the main reviewer context.

## Outcome Contract

- Outcome: real repository-impact findings, or a clean verdict.
- Done when: changed paths, direct contracts, relevant review rules, and cheapest validation have been checked.
- Evidence: each finding names a trigger path, source evidence, impact, and fix direction.
- Output: exact user contract first; otherwise a concise Markdown review summary. Use canonical JSON only as an internal contract for `--html`, `--fix`, or an explicit machine-readable report.

## Flow

1. Resolve scope: MR/PR, branch diff, working tree, or explicit notes.
2. Before reading any diff body, collect changed paths and screen each through the machine denylist in `scripts/_lib.sh`, the same authority `--fix` enforces, rather than matching names by hand: source `_lib.sh` from the skill directory and run `is_secret_like_path` per path (or `validate_git_diff_paths <base> <head>` for a branch). Refuse a matched path without printing it; the denylist covers env files, private keys and certificates, SSH material, and history or log files. Do not refuse ordinary source code merely because a path contains `credential`, `secret`, or `token`; review it as security-sensitive code and avoid quoting secret values.
3. List changed files before judging behavior:
   - branch: parse `git diff -z --name-status <base>...HEAD`; for `R*` and `C*`, inspect both source and destination paths before any full diff
   - working tree: parse `git diff -z --name-status HEAD` and `git ls-files -z --others --exclude-standard`; inspect both source and destination for `R*` and `C*`
   - MR/PR: compare host changed files with the local checkout or diff
4. Read local instructions that can change review rules: `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.agents/`, `README.md`, `REVIEW.md`, `CODE_REVIEW.md`, project review commands, and project review skills.
5. Read the MR/PR description and discussions when available.
6. Read touched files, adjacent code, direct call sites, and relevant tests before final severity.
7. For exported identifiers, deleted symbols, schema fields, event names, and shared helpers, `rg` callers, readers, writers, and tests.
8. Load the surface rule file(s) whose changed path or runtime matches, from `references/rules/`:
   - [TypeScript](references/rules/typescript.md): TypeScript API boundaries, exported identifiers, generated types, discriminated unions, and serialization.
   - [React](references/rules/react.md): React components, hooks, client state, streaming or optimistic UI, and disabled controls.
   - [Next.js](references/rules/next.js.md): App or Pages Router, route handlers, server actions, middleware, cache, cookies, and the server/client boundary.
   - [Python](references/rules/python.md): Python ingestion, loaders, dataframes, and scripts that write files or warehouse tables.
   - [SQL](references/rules/sql.md): SQL models, migrations, warehouse schema, joins, aggregates, and grants.
   - [CLI](references/rules/cli.md): CLI behavior, installers, packaging, generated wrappers, runtime readiness, and source-to-package mapping.
   - [Async](references/rules/async.md): queues, jobs, retries, waiters, durable steps, and worker lifecycle.
   - [Agent](references/rules/agent.md): model routing, tools, connectors, provider wrappers, sandboxed execution, and protocol clients.
   - [ELT](references/rules/elt.md): extract/load/transform jobs, dbt models, reverse ETL, backfills, and grants.
9. Apply the Universal Review Lenses to every review, and load the `references/concerns/*.md` file each lens names when the change exercises it.
10. Verify each candidate with code, docs, tests, runtime output, or the cheapest existing validation command that covers the changed path.
11. Report only findings with a concrete trigger path and realistic repository impact.

## Rule Precedence

1. Observed runtime, security, data, and product contracts.
2. Specific distilled rules in `references/concerns/*.md` and `references/rules/*.md` when their `Load when` and trigger match.
3. Repo-local conventions and personal preferences.
4. Generic review heuristics.

Treat a repo-local instruction as a level-1 contract only when it documents an actual runtime, product, security, migration, or deployment constraint. Otherwise, when it conflicts with a matching distilled rule, prefer the rule only when its trigger and evidence match and no repo-owned contract disproves it.

Do not treat people, teams, specific projects, or past incidents as review authority in shared skill text. Convert them into trigger, action, boundary, and evidence requirements.

A lower-priority rule may narrow a higher-priority rule by supplying a concrete boundary. It may not silently turn an observed failure, authority violation, or data-corruption path into an accepted convention.

## Reference Routing

- The Universal Review Lenses are the concern axis: apply all of them, and load a `references/concerns/*.md` file for the full check when the change exercises that lens.
- The `references/rules/*.md` files are the surface axis: load one when the changed path or runtime matches its `Load when` trigger.
- A change usually loads a few concerns and a few surfaces. A surface file holds only language- and runtime-specific deltas and points up to the concern that owns each cross-cutting rule; do not restate a concern rule inside a surface.
- Rule files identify review candidates. A checklist item is not reportable until it satisfies the Finding Bar with a concrete trigger path, evidence, impact, and fix direction.
- Load [result](references/contracts/result.md) before producing canonical review JSON, before handing findings to `--fix`, or before rendering HTML.
- Load [fix](references/workflows/fix.md) only when `--fix` was requested, after the normal review has produced accepted findings, and before any mutation.
- Load [html](references/workflows/html.md) only when an HTML artifact was requested and the canonical review result already exists.

## Review Variants

| Variant | Trigger | Extra handling |
| --- | --- | --- |
| Default | Local diff, branch, MR/PR URL, or explicit notes | Read-only concise Markdown review summary unless the user gives an exact output contract. |
| Remote MR/PR | Host URL or MR/PR reference | Compare host changed files with local checkout or diff; never fabricate URLs. |
| `--html` | `--html`, report, artifact, or visual view | Load [result](references/contracts/result.md), produce the same review JSON, then render with [html](references/workflows/html.md). |
| `--fix` | `--fix` after review | Run the normal review first. If accepted findings exist and a writable local checkout is available, load [fix](references/workflows/fix.md) before mutation. |
| Spec-backed review | MR/PR description, issue, Jira, PRD, or explicit requirements exist | Map each requirement to a diff change; report missing or partial implementation and unrequested behavior beyond the spec as separate findings so one axis does not mask the other. |
| Large or high-risk review | Broad contract, security, automation, release, migration, or cross-runtime change | Use optional independent reviewers only when they can inspect distinct risk areas; verify their citations before forwarding. |

The main reviewer must not edit reviewed project files. Only the fix-orchestrator may mutate, and only inside a local writable checkout. A host-only MR/PR review is report-only. A local writable checkout of that MR/PR branch is eligible for `--fix`.

## Universal Review Lenses

Apply all of these to every review. Each names the concern file that owns the full check; load it from `references/concerns/` when the change exercises that lens.

- Establish the source-owned contract, names, and generated shapes before judging the implementation: [contract](references/concerns/contract.md).
- Trace ownership and authority through wrappers, runtimes, and deployment boundaries, require an observed caller for each guard, fallback, and abstraction, and filter any value before it reaches a client: [boundaries](references/concerns/boundaries.md).
- Keep expected absence, business rejection, retryable failure, waiting, partial work, and success observably distinct, and write final markers only after durable effects complete: [failure-states](references/concerns/failure-states.md).
- Prove DB and API round trips stay bounded and each write keeps grain, scope, and meaning: [data-integrity](references/concerns/data-integrity.md).
- Classify every config and request value, and prove a lower-trust input cannot become higher-trust authority: [security](references/concerns/security.md).
- Require tests to fail when the changed invariant breaks, not merely exercise a fixture: [tests](references/concerns/tests.md).
- Mechanically inspect every changed, deleted, or moved line, then sweep peer surfaces by concept: [mechanical](references/concerns/mechanical.md).

## Finding Bar

Prioritize:

1. Contract and source-of-truth mismatch
2. Semantic mismatch in names, fields, states, events, or API shape
3. Ownership boundary violation
4. Hidden failure, false success, partial-work masking, or silent data corruption
5. Security, permission, identity, exposure, or environment-isolation risk
6. Incomplete symmetry across writers, readers, sibling cases, schema variants, generated output, or removed consumers
7. Unbounded DB/API fan-out in backend paths that scale with rows, events, users, tools, or retries
8. Mechanical bugs in changed lines
9. Tests and docs, only when they prove or hide one of the risks above

Skip pure style, speculative guards, broad maintainability advice, and pattern matches without a concrete trigger path.

Completeness gaps become numbered findings only when a requirement, peer contract, or reachable behavior proves the omitted behavior. Otherwise put them in `manual` or `notes`.

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

Require runtime evidence for browser or hydration behavior, cross-tab timing, live identifier equality, DB migration state, UI enablement, external service paging, sandbox lifecycle, provider payload shape, and terminal states not encoded locally.

## Output

Respect exact output contracts first: `approve`, `No blocking findings.`, verdict-only, blocker-only, or any user-provided shape override the default chat review.

For normal chat output, give a concise Markdown summary. Start with findings when any exist. For each finding include severity, `path:line`, title, trigger or evidence, impact, and fix direction. If there are no findings, say `No blocking findings.` and name only material validation gaps.

For `--html`, `--fix`, or explicit machine-readable reports, load `references/contracts/result.md` and produce canonical JSON for that workflow. For `--html`, render that same result using `references/workflows/html.md`.

Do not narrate review mechanics, tool setup, worktree preparation, or skill rules.
