---
name: review
description: Review a remote MR/PR or local code changes, reporting real issues with evidence-first severity. Use when the user says "review", "code review", "帮我 review", "看看这个 MR", asks for review findings, or provides an MR/PR URL. Not for prose review, skill-authoring audits, or ordinary implementation.
argument-hint: "[--cx] [--fix] [--html] [MR/PR URL or notes]"
allowed-tools:
  - Bash
  - Read
  - TaskCreate
  - TaskGet
  - TaskList
  - TaskOutput
  - TaskStop
  - TaskUpdate
---

# Review

Read, verify, report. Clean verdicts and no-op are valid outcomes. Default review is read-only for the reviewed project: do not edit reviewed files, post comments, start dev servers, or apply fixes in the main reviewer context.

## Flow

1. Resolve scope: MR/PR, branch diff, working tree, or explicit notes.
2. Before reading any diff body, collect changed paths. Refuse secret-like names without printing raw paths: `.env*`, private keys and certificates (`*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.crt`, `*.cer`), `id_rsa`/`id_dsa`/`id_ecdsa`/`id_ed25519`, `authorized_keys`, `known_hosts`, `.ssh/`, `*.history`, `*.log`, and names containing `credential`, `secret`, or `token`. The same denylist is enforced for `--fix` in [references/fix-policy.md](references/fix-policy.md).
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
2. Classify findings as accepted, skipped, dropped, or manual verification, then seed the live review frontier before any mutation.
3. If `REVIEW_MODE=mr` came from [references/cx-delegation.md](references/cx-delegation.md), report accepted findings and stop: the MR is reviewed in a transient detached worktree with no writable local checkout. To fix, check out the MR branch locally and rerun `--fix`. For `REVIEW_MODE=local`, continue; the fix-orchestrator edits the real working tree (`git rev-parse --show-toplevel`), never `$REVIEW_CWD`, which may be a read-only review snapshot.
4. Launch one fresh write-capable fix-orchestrator subagent with the seeded frontier, repo root, review scope, validation commands, and [references/fix-policy.md](references/fix-policy.md).
5. If no write-capable subagent is available, report accepted findings and do not mutate files.
6. The fix-orchestrator independently triages, edits, validates, reuses its own context for later mutation rounds, and returns a structured summary.
7. The main session reviews that summary and reports changed, skipped, manual, still-open, new-real, regression-from-fix, repeated-or-reworded, and speculative items.

The main reviewer must not edit reviewed project files. Only the fix-orchestrator may mutate, and only inside a local writable checkout.

## Review Stance

**Evidence before claims is the review; everything else is mechanics.** Find the source of truth before approving or rejecting behavior.

- No speculative support paths: guards, fallbacks, `undefined`, caches, switches, and helpers need a current caller, contract, test, or observed failure.
- Failure must stay visible: do not turn errors, bad statuses, partial work, or terminal-state ambiguity into success.
- Names, states, boundaries, and config are contract surfaces.
- A changed contract needs a symmetry sweep across writers, readers, callers, generated types, generated artifacts, and direct consumers; a change that extends a cross-cutting concept (identity, locale, permission, currency, flag, policy) also needs a completeness sweep for peer surfaces it never touched and shares no symbol with.
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

A review produces one JSON document, the canonical data: the agent reads it, `--cx` and `--fix` consume it, and it is the input to the HTML renderer. Default output is that raw JSON. On `--html` or an explicit report request, also render it to a single-file HTML report. Full field contract and the render command: [references/html-report.md](references/html-report.md).

Respect exact output contracts first: `approve`, `No blocking findings.`, verdict-only, blocker-only, or any user-provided shape override the JSON default. With no findings, emit `"findings": []` and state the clean result in `verdict`.

Shape — file-centric (modeled on Anthropic's `03-code-review-pr` example); every field and rule is in [references/html-report.md](references/html-report.md):

```json
{
  "meta": { "project": "acme/web", "scope": "MR !247 · 6 files", "scope_slug": "mr247",
    "reviewed_sha": "15c25380", "repo_root": "Users/me/Code/web",
    "mr": { "iid": 247, "title": "标题", "url": "https://gitlab.example/x/-/merge_requests/247" },
    "author": "Mira Okafor", "branch": "feat/x -> main", "stat": { "add": 142, "del": 38, "files": 6 },
    "verdict": "方案合理，1 项待跟进", "validation": "仅静态验证", "manual_gap": "未做浏览器实测",
    "rationale": { "requirement": "要解决什么", "assessment": "方案是否合理" } },
  "findings": [ { "sev": "P2", "path": "lib/x.ts", "line": 42, "title": "一句话结论",
    "level": "confirmed", "problem": "什么问题", "trigger": ["触发步骤", "中间步骤", "后果"],
    "fix": "修复方向", "code_snippet": "-  旧代码行\n+  新代码行", "evidence": "证据", "impact": "影响 / 边界" } ],
  "files": [ { "path": "lib/x.ts", "add": 19, "del": 6 },
    { "path": "lib/clean.ts", "add": 4, "del": 1, "note": "无 finding 文件的一句话总结" } ],
  "notes": [ { "text": "weak 级别的非 finding 说明", "level": "weak" } ]
}
```

`sev` is uppercase `P1`/`P2`/`P3`. Order findings by severity, highest first. Omit any optional field that has no content.

**Language**: write `title`, `problem`, `trigger`, `fix`, `evidence`, `impact`, `verdict`, `rationale`, and notes as Chinese prose; keep English only for code identifiers, paths, commands, severity tags, error codes, and host terms (`MR`/`PR`/`SHA`). Do not translate word for word; write native Chinese review prose.

**Evidence level**: `confirmed` and `manual` can be numbered findings; a `manual` finding must name the missing runtime observation in `evidence` or `impact`. `weak` goes in `notes`, never a numbered finding.

Rules:

- Use repo-relative `path:line`, not a basename.
- Quote only the code needed to prove the claim.
- Explain project-specific terms on first use.
- Prefer one concrete scenario over abstract mechanism.
- Correct fix means root cause plus direct dependents. Flag unrelated rewrites, surrounding refactors, and adjacent cleanup separately.
- Never fabricate an MR/PR URL: use the host CLI (`glab`/`gh`) web URL or a user-provided one, and omit `mr` when unknown.
- Do not narrate review mechanics, tool setup, worktree preparation, or skill rules.

## Evolution

At the end of a review or fix run, and when the user asks to evolve the skill or record a review lesson, use [references/self-improvement.md](references/self-improvement.md). Do not output self-improvement content when the user gave an exact output contract such as `approve`, clean-verdict-only, verdict-only, or blocker-only, unless private review-memory recording failed; then state `private review-memory unavailable: <reason>`.
