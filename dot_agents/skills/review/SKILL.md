---
name: review
description: Review remote merge requests or pull requests, branches, commits, diffs, and uncommitted code changes for correctness and regression risk, reporting only evidence-backed findings. Use for pre-merge code review, review findings, and MR/PR URLs. Not for prose review, skill-authoring audits, or implementation requests.
argument-hint: "[--fix] [MR/PR URL or notes]"
allowed-tools:
  - Bash
  - Read
  - Agent
---

# Review

Default review is read-only for the reviewed project: do not edit reviewed files, post comments, start dev servers, or apply fixes in the main reviewer context. A clean verdict is a valid outcome.

## Flow

1. Resolve scope: MR/PR, branch diff, working tree, or explicit notes.
2. Classify changed paths before reading any diff body. Source `scripts/_lib.sh` from the skill directory and run `validate_git_diff_paths <base> <head>` for a branch, `validate_working_tree_paths` for the working tree, or pass an MR/PR host file list as a NUL-delimited file to `validate_path_file_nul` in the same Bash invocation.
   - Keep path transport NUL-delimited. Never copy a path from an earlier response into a later Bash command, because a plain-looking filename can collide with an unrelated Bash permission rule.
   - Refuse raw secret surfaces without printing them. Stop on ambiguous sensitive paths until the host, project instructions, or user classifies them.
   - Treat encrypted-name matches only as ciphertext candidates. Once project instructions or an encryption marker confirms one, account for path and status, keep its body out of every diff, and continue reviewing ordinary paths.
   - Public certificates, public keys, `authorized_keys`, `known_hosts`, and SSH client configuration are not secret by type. Source code is not secret merely because its path contains `credential`, `secret`, or `token`; review it as security-sensitive code and avoid quoting secret values.
   Done when every changed path is classified as ordinary, opaque ciphertext, ambiguous, or raw secret before any body is read.
3. List changed files before judging behavior:
   - branch: parse `git diff -z --name-status <base>...HEAD`; for `R*` and `C*`, inspect both source and destination paths before any full diff
   - working tree: parse `git diff -z --name-status HEAD` and `git ls-files -z --others --exclude-standard`; inspect both source and destination for `R*` and `C*`
   - MR/PR: compare host changed files with the local checkout or diff
4. From the revision being reviewed, discover and read the root and path-scoped `CLAUDE.md`, `AGENTS.md`, `README.md`, `REVIEW.md`, `CODE_REVIEW.md`, project review commands, and review skills under `.claude/` or `.agents/`. Follow one-hop documents selected by their path rules. Do not treat the current checkout or automatically injected instructions as proof of the reviewed revision; use the exact ref (`git show <head>:<path>`) or the host's raw-file API when they differ.
   Done when every changed path has either its applicable repository rules loaded or a recorded `no matching repository rule` disposition.
5. Read the MR/PR description and discussions when available.
   - Treat discussion claims as review state, not proof. Omit resolved or reasoned-dismissed points unless new evidence reopens them; re-report a reverified `P1` as "previously dismissed, re-raised because X".
6. Read touched files, adjacent code, direct call sites, and relevant tests. For exported or deleted symbols, schemas, events, and shared helpers, search writers, readers, generated output, and peer surfaces by both symbol and changed concept.
7. Load every matching surface rule and apply every Universal Review Lens below.
8. Verify each candidate against the applicable code, source-owned contract, tests, or runtime evidence; run the cheapest existing validation that covers the changed path.
9. Finish only after every changed path, matching repository rule, and loaded shared rule is accounted for, then report findings that pass the Finding Bar or a clean verdict.

## Rule Precedence

Observed runtime and source-owned product, security, and data contracts outrank repository conventions; repository conventions outrank generic heuristics. A shared rule applies only when its trigger matches and no repository-owned contract disproves it. An explicit mandatory instruction in any applicable repository-owned instruction or review rule, such as `MUST`, `Always`, `Never`, or `Do not`, is a source-owned conformance contract, not a model-invented style preference.

## Surface Rules

- Load [TypeScript](references/rules/typescript.md), [React](references/rules/react.md), or [Next.js](references/rules/next.js.md) for their language, UI-state, routing, cache, or server/client boundaries.
- Load [SQL](references/rules/sql.md) or [ELT](references/rules/elt.md) for loaders, persisted data, queries, migrations, warehouse models, or pipelines.
- Load [CLI](references/rules/cli.md), [Async](references/rules/async.md), or [Agent](references/rules/agent.md) for packaging and runtime readiness, deferred lifecycle, model/tool/provider boundaries, or changes to `SKILL.md`, `AGENTS.md`, `CLAUDE.md`, and other model-facing instructions.

## Universal Review Lenses

Apply every lens; load its file when the change exercises it.

- [Contract](references/concerns/contract.md): requirements, schemas, names, generated shapes, and consumers.
- [Boundaries](references/concerns/boundaries.md): ownership, authority, guards, persistence, clients, and credential/runtime scope.
- [Failure states](references/concerns/failure-states.md): absence, rejection, retries, partial work, and final markers.
- [Data integrity](references/concerns/data-integrity.md): round trips, grain, scope, transactions, and per-record outcomes.
- [Security](references/concerns/security.md): value trust, authorization, environment isolation, and sandbox exposure.
- [Tests](references/concerns/tests.md): reachable fixtures, observable invariants, and real runtime boundaries.

## Variants

- `--fix`: finish the normal review first; when accepted findings and a writable local checkout exist, load [fix](references/workflows/fix.md) before mutation.
- Spec-backed review: map each requirement to the diff; review missing, partial, and unrequested behavior separately.
- Large or high-risk review: dispatch independent reviewers only for distinct risk areas, after loading [second-opinion](references/workflows/second-opinion.md).

## Finding Bar

Report only a source-owned contract mismatch or repository-reachable behavior, not model-invented style, speculative guards, broad maintainability advice, or pattern matches alone. Report a behavior-neutral violation of an explicit applicable repository conformance rule as a non-blocking `P3`; when the same violation causes reachable behavior, assign severity from its verified impact. A descriptive preference gets no finding. Exact blocker-only or verdict-only output contracts may suppress non-blocking findings. A reachable path may begin at a supported producer or current caller, exposed untrusted or environment-controlled input, persisted or migration data, replay or scheduling, or an external/public contract. Vendor capability, manually constructible syntax, hypothetical future use, and another environment's convention are insufficient; free text is reachable only through an exposed entrypoint for the relevant producer or adversarial input class.

Before reporting, establish provenance and diff contribution, the reachable trigger or matching repository rule, decisive evidence, consequence, severity, remedy prerequisites, and disposition. Verify diagnosis and remedy independently: an unavailable prerequisite invalidates the remedy, while an unknown prerequisite stays conditional and cannot raise severity.

Do not attribute pre-existing debt to the diff; report it separately only when the change newly exposes or worsens it, falsely claims to fix it, it blocks the changed behavior, or it is an active `P1` defect in touched code.

An omission is a finding only when an explicit requirement, source-owned peer contract, or reachable behavior proves it. Otherwise drop it. Preserve a material validation gap only when the path reaches one named unknown boundary/runtime fact, source-specific evidence calls the local assumption into doubt, and the answer could change the verdict to `P1` or `P2`; represent it as a `manual` finding naming each applicable probe already attempted with its result, and do not give a clean verdict.

## Severity

- `P1`: a verified normal-use path with material harm, or a reachable path that breaks a security or permission boundary, leaves persistent bad state with material impact, silently corrupts downstream data, or records a material failure as successful.
- `P2`: a verified path requiring specific supported conditions and causing material impact, but not meeting `P1`.
- `P3`: a verified local, recoverable, low-impact behavior; a behavior-neutral violation of an explicit applicable repository conformance rule; or a concrete future failure path already enabled by the changed code.

Unsupported or unreachable modes fail the Finding Bar; do not preserve them by downshifting.

## Verification

- For provider-, persisted-, migration-, or replay-owned values, verify the exact property the code relies on against a source-owned schema, documentation, generated type, test, or runtime. A handwritten local type or fixture alone does not prove it.
- Trace downstream gates, fallbacks, retries, and containment before assigning impact or severity.
- Validate dependency changes against the lockfile-resolved target version and its types or runtime; otherwise keep the verdict conditional on CI, typecheck, or test.
- Require runtime evidence only for facts not established locally and specific to runtime or deployment, such as migration state, deployed role or plan, timing, or sandbox lifecycle.

A challenged or corrected finding re-enters verification as a new claim at the same Finding Bar. Do not replace one unverified conclusion with another, and remove a disproved candidate from final output and finding counts.

## Output

Respect exact output contracts first: `approve`, `No blocking findings.`, verdict-only, blocker-only, or any user-provided shape override the default chat review.

For normal chat, start each finding with one plain sentence showing the concrete trigger or violated repository rule and its result. Then give severity, `path:line`, decisive evidence, and the required outcome; add provenance and exact diff contribution only when they are not obvious. When the user asks whether the requirement or approach is reasonable, state the current problem and the patch's approach before the findings. Use `No blocking findings.` only when no material validation gap remains.

When comments or replies are requested, emit only the final body and address one issue per comment or reply. State the verified problem or ask the one question needed to establish it. In a reply, answer the author's concern first with the verified fact that resolves it. If the concern is whether the patch changed behavior, state what was already true and whether the patch changes it. Add only the context needed to support that answer, using the concrete terms and identifiers already established by the code or discussion. Omit resolved points, review mechanics, and unsupported examples.

For a review comment or reply, prescribe implementation details or a particular approach only when the author asks, prior replies failed to resolve the same issue, or naming an established repository approach is necessary to explain the problem clearly. A confirmed issue may still request the required behavior or outcome without designing the solution. Use questions only for genuine uncertainty.

Any condensing, restyling, or rendering pass keeps findings, severities, evidence, and `path:line` citations 1:1; readability never justifies merging distinct findings or dropping one.
