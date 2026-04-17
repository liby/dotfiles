---
name: review
description: Review a remote MR/PR (with description and discussion) or local code changes, reporting only real issues with context-first severity. Use when the user says "review", "code review", "帮我 review", "看看这个 MR", or provides a MR/PR URL to review.
argument-hint: "[--cc | --cx | --fix | URL | additional notes]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

## Arguments

### `--cc` / `--cx`: delegate to another model

If `--cc` is passed, delegate to Claude Code. If `--cx` is passed, delegate to Codex. The delegate runs this same skill without the flag, so it reviews directly — no loop. See [references/delegation.md](references/delegation.md) for invocation details.

### `--fix`: auto-fix loop

Default (flag absent): review is **report-only**. Present findings and stop — the user decides what to fix.

If `--fix` is passed, see [references/autofix.md](references/autofix.md) for the baseline setup and fix loop.

## Goal

Produce a high-signal review that focuses on real bugs, silent failure paths, bad state transitions, contract violations, semantic mismatches, security risks, meaningful testing gaps, and project-pattern mismatches.

Do not pad the report with generic style advice. Do not give "textbook review" feedback detached from the repository's actual runtime model.

Respond in Chinese unless the user explicitly asks otherwise.

## Review Process

### Flow

1. Read the MR description and discussion before judging the diff.
2. Review the local diff against the correct base.
3. Read adjacent code, relevant call sites, and touched tests before finalizing severity.
4. Infer the repository's real runtime context before deciding whether something is a blocker, a low-priority edge case, or not a real issue.
5. Identify the real contract, semantics, ownership boundary, and failure model before commenting on implementation details.
6. Report only the findings that survive that context check.

### Project Conventions

Before reviewing, scan for project-level agent instructions: `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.agent/`, `README.md`. Where they conflict with this skill's rules, defer to the project — it reflects local ground truth. Where they don't conflict, treat them as complementary context (e.g., "this repo runs on K8s" informs severity for config errors).

### Context Gathering

Determine the review mode:

- **MR/PR mode** (URL or number provided): fetch metadata from the remote, then diff locally.
- **Local mode** (no URL): diff the working tree, staged changes, or branch against `--base <ref>`.

The review principles, severity, and output are the same in both modes. Only the context gathering differs.

**MR/PR mode**: Use `glab` to fetch from GitLab. If the repository remote is GitHub, fall back to `gh`.

Fetch MR metadata as TSV to minimize output tokens:

```bash
glab mr view <number> --output json | jq -r '["title","state","author","source","target","labels"], [.title, .state, .author.username, .source_branch, .target_branch, (.labels | join(","))] | @tsv'
```

Fetch description and discussions separately (these need full text, not TSV). Summarize the parts that materially affect the review: threat model, rollout assumptions, compatibility promises, migration notes, and anything reviewers already challenged. When existing discussions already debated a point, factor that into the review instead of repeating it blindly.

Check out the head branch in a worktree so you can read files directly and run project validation commands:

```bash
git fetch origin
git worktree add "$TMPDIR/review-<mr-number>" origin/<head-branch> --detach
```

Run validation and diff commands from within the worktree. Clean up with `git worktree remove` after the review completes. If worktree creation fails (e.g. branch already checked out), fall back to `git show <ref>:path` for file reads — validation commands will not be available in this mode.

For the diff, `git diff <base>...<head>`.

**Local mode**: Diff the working tree or branch against the base (`--base <ref>`, or infer from the branch's upstream).

### Read Surrounding Code

In both modes, read beyond the diff before finalizing severity:

- touched files in full
- surrounding code and nearby helpers
- direct call sites if behavior depends on them
- relevant tests

If a claim depends on a control-flow detail, verify it in code before reporting it.

If a claim depends on a repository convention, verify that convention in adjacent code instead of assuming it.

## Core Principles

### 1. Reject unobserved failure guards

Do not recommend null guards, optional chaining, fallback values, or "safe" alternate branches unless the contract, docs, tests, or observed behavior show they are needed.

If a guard is justified, prefer failing loudly over silently masking the problem.

Inconsistent guards are a finding on their own: if code checks field A but not sibling fields B and C on the same object, the issue is the inconsistency, not the missing checks.

### 2. Keep errors observable

Do not normalize swallowed errors, unchecked `Promise.allSettled`, ignored exit codes, broad `catch {}` blocks, or fallback paths that convert failures into fake success.

Every mechanism must match its purpose. Retries are for transient faults, not polling. Fallbacks are for defined alternate behavior, not hiding unexpected states. Error types (retriable vs non-retriable) must reflect the actual failure semantics.

Treat `isConfigured`, `alreadyDone`, `cache hit`, `skip`, and similar gates as high-risk review targets. They must reflect final usable state, not just partial traces.

Raise severity when failure leaves behind a misleading "configured", "done", "cached", or "healthy" state.

### 3. Question every assumption

For each claimed issue, identify the actual assumption:

- what the code assumes
- why that assumption may be invalid
- what concrete condition breaks it

Do not write abstract criticism without a trigger path.

### 4. Follow repository reality

Severity must match the project's real usage:

- one-shot initializer vs long-running service
- user-facing app vs internal tooling
- migration script vs library
- config writer vs transactional system

Adapt emphasis by project type, but keep the same standard of evidence:

- `infrastructure / IaC`: privilege boundaries, network exposure, resource scope, deployment behavior, least privilege
- `data pipelines / integrations`: schema correctness, field semantics, sync direction, idempotency, ownership of derived values
- `event-driven / async processing`: lifecycle, event naming, delivery semantics, retry vs polling, ordering guarantees, step boundaries
- `APIs / services`: contract compatibility, backwards compatibility, error contracts, protocol semantics
- `CLI / scripts / tooling`: user-visible failure modes, exit codes, idempotency, side effects

Do not overrate a theoretical edge case that contradicts the repository's actual runtime model. Do not underrate a bug that can strand the system in a persistent bad state.

### 5. Prefer simplicity

Do not propose heavyweight redesigns unless the current approach is genuinely unsafe or broken.

Prefer the smallest fix that removes the real risk.

### 6. Names and boundaries must match reality

Treat misleading names, mislayered abstractions, and wrong ownership boundaries as real findings when they obscure the system's true model.

Ask:

- does this name match the real entity or responsibility
- is this field/event/state expressing the right concept
- is this logic living in the right layer
- are we adding a workaround instead of using the correct abstraction

### 7. Contracts outrank convenience

If behavior depends on external APIs, historical conventions, compatibility promises, or undocumented assumptions, look for the source of truth.

If the source of truth is missing:

- do not invent a "safe" fallback
- ask whether a code comment or doc link is needed
- consider whether the implementation is encoding guesswork as normal behavior

## Review Priorities

Look in this order:

1. contract and source of truth
2. semantic correctness: names, fields, event meaning, entity meaning
3. ownership boundary: which layer or module should know this
4. failure behavior: fail loud, partial success, misleading success, recoverability
5. security / permissions / exposure surface
6. complexity: whether the change introduced more machinery than the real problem needs
7. tests and docs as supporting evidence

Do not start from formatting, micro-style, or speculative edge cases.

## Severity Guidance

- `P1`: likely in normal or high-probability usage, or leaves a persistent bad state, or misleads the user/system into believing the operation succeeded
- `P2`: needs specific conditions, but the failure mode and impact are real and meaningful
- `P3`: narrow, low-impact, or mostly about maintainability / consistency

Severity upweights:

- partial success later treated as complete success
- broken permissions or exposure boundary
- semantic mismatch that will mislead future callers or operators
- fallback that hides contract violations

Severity downweights:

- the issue depends on a repository mode the project does not actually use
- the issue is real but local, obvious, and easy to recover from
- the issue is mostly about preferred style without behavioral consequence

## Verification Expectations

Verify claims before reporting them.

When useful and cheap, run existing validation commands already defined by the project (tests, lint, typecheck).

Do not invent new verification commands. Do not run dev servers, build servers, or frontend serve commands just for review.

When a claim is about semantics, verify it against neighboring names, docs, tests, or call sites. Do not rely on wording intuition alone.

## Output

Start with a direct conclusion: whether the MR should be blocked, how many issues at each severity, and the overall assessment.

For each finding, ordered by severity:

- State the conclusion first, not the investigation process.
- Follow a causal narrative: what the code does now → why that is wrong → what concrete scenario breaks → what the impact is. Do not write abstract criticism disconnected from the trigger path.
- Point to specific code (file + line). Do not make claims without evidence.
- Explain why it matters in this project's context.
- Suggest a fix direction, not a redesign.

Report all issues regardless of severity. If a finding is low-priority, say so and explain why — do not omit it.

If no real findings survive scrutiny, say so plainly.

## Writing Rules

- Do not start with a long overview.
- Every vague phrase must be immediately followed by a specific trigger and consequence. If you say "bad state", "edge case", or "inconsistent check", translate it into what actually breaks and how.
- Do not report a finding unless you can point to code that demonstrates it.
- Prefer short, direct conclusions plus concrete evidence and fix direction.
