# Cross-Model Delegation

How to delegate the review to Codex when `--cx` is passed.

## Do not

- Do not edit Codex plugin files (they may appear in `node_modules`-like dirs the review reads from).

## `--cx`: Delegate to Codex

Every `--cx` review invokes two Codex paths **in parallel** and merges their findings:

- **Broad path** — `/codex:review` via the Codex companion. Multi-persona coverage (correctness-reviewer, testing-reviewer, api-contract-reviewer, adversarial-reviewer, etc.). Output is a JSON envelope whose `codex.stdout` is free-form `reviewText` prose, not a machine-readable findings array. `/codex:review` is hardcoded ephemeral (no sidebar entry) and rejects custom focus text at the companion layer.
- **Opinionated path** — `codex exec --ephemeral` reading `/review`'s SKILL.md. Single-persona pass against our contract (principles, priorities, severity calibration). Output is free-form prose per SKILL.md's Output section.

### Invocation

Main session calls [`scripts/codex-review.sh`](../scripts/codex-review.sh) (path relative to the skill root; resolve against the skill's base directory before executing), which resolves the review target, sets up the MR/PR worktree (if `--mr` is passed), and fires both paths in parallel.

**Always capture stdout first, check `$?`, then `eval`** — a bare `eval "$(scripts/codex-review.sh)"` silently swallows the script's non-zero exit and leaves any prior-round `$REVIEW_CWD`/`$BROAD_OUT`/etc. still set, which `--fix` would then mistake for a fresh clean round:

```bash
unset REVIEW_CWD BASE_REF SCOPE BROAD_OUT OPINIONATED_OUT
if out=$(scripts/codex-review.sh); then
  eval "$out"
else
  echo "codex-review.sh failed; aborting round" >&2; exit 1
fi
```

Invocation flags:

```bash
# Local mode (base auto-resolved: --base → @{upstream} if HEAD has commits ahead → origin/HEAD if HEAD has commits ahead → local main/master/trunk if HEAD has commits ahead → working-tree)
# Final guard: if the resolved base would put HEAD at-or-behind origin/HEAD
# (e.g. after `reset --soft HEAD~N` rewinds HEAD onto the default branch),
# scope falls through to working-tree so the review sees the pending workspace
# changes instead of inherited commits between old upstream and default branch.
scripts/codex-review.sh
scripts/codex-review.sh --base origin/main

# MR/PR mode (default remote: origin; fetches both pull/<N>/head or
# merge-requests/<N>/head AND the target branch so the base is fresh)
scripts/codex-review.sh --mr 1234

# Fork workflow: PR lives on upstream, origin is the contributor's fork
scripts/codex-review.sh --mr 1234 --remote upstream

# Self-hosted host whose domain contains neither `github` nor `gitlab`:
# substring-based platform detection won't fire, so pass --platform explicitly.
scripts/codex-review.sh --mr 1234 --remote origin --platform gitlab
```

After `eval`, the caller has:

- `$REVIEW_CWD` — repo root (local) or detached worktree path (MR/PR)
- `$BASE_REF` — resolved base, empty when `SCOPE=working-tree`
- `$SCOPE` — `branch` or `working-tree`
- `$BROAD_OUT` — path to `/codex:review` JSON envelope (extract prose with `jq -r .codex.stdout "$BROAD_OUT"`)
- `$OPINIONATED_OUT` — path to `codex exec` stdout. Findings live at the **tail** of this file, not the head: the prefix is a session header plus a recent-file `... N lines omitted` pseudo-summary, often 2000–3000 lines. Use `tail -c 8000` or `awk '/^codex$/{flag=1} flag'` to reach the actual report.

The script encodes the [Companion API limitation](#companion-api-limitation) (do **not** pass `--base` under `--scope working-tree` — companion silently flips to branch mode), so callers never construct these commands manually.

Read both output files, then apply the [Filter](#filter) below. Whenever `$REVIEW_CWD` differs from `$(git rev-parse --show-toplevel)` (MR/PR mode, or local mode where the script materialized a dirty-tree snapshot worktree), clean up with `git worktree remove --force "$REVIEW_CWD"` after filtering.

Under `--fix`, call the script the same way each round with the same `--base` / `--mr` / `--remote` flags. The script is idempotent given unchanged HEAD / upstream / origin/HEAD, so re-resolving each round yields the same triple.

If either path exits non-zero — or returns a 0-byte output file, which the script promotes to an exit=124 failure — the script exits with status 5 and publishes nothing to stdout. The caller's `eval` sets no outputs, so a degraded "half-review" can never be treated as a complete one. Under `--fix`, this aborts the loop; convergence requires a clean round (non-empty output) from both paths. The 0-byte case typically means companion auth/install is broken (broad path) or codex exec couldn't initialize its sandbox (opinionated path) — see the script's stderr for which side and rerun with `CODEX_LOG=debug`.

### Companion API limitation

For `--scope working-tree`, `/codex:review` must not receive `--base` — the companion's `resolveReviewTarget` forces branch mode the moment it sees `--base`, silently flipping the request to branch diff. [`scripts/codex-review.sh`](../scripts/codex-review.sh) handles this. The opinionated path (`codex exec`) accepts any prompt text, so the script picks a scope-matched prompt.

## Filter

Apply after both paths return. Rules are based on trigger path and real-world impact, not on which persona reported a finding.

**Keep** — Apply the fix.
Finding must satisfy ALL THREE:
- Category is one of the eight SKILL.md Goal types: real bugs, silent failure paths, bad state transitions, contract violations, semantic mismatches, security risks, testing gaps, project-pattern mismatches.
- A concrete trigger path is present (not just a theoretical possibility).
- A realistic impact on this codebase is stated.

**Rewrite** — Split the finding, apply only the real-problem part.
When a single finding mixes a genuine bug with a defensive-programming suggestion, apply the genuine part and move the defensive part to Drop.

**Skip** — Record in the round report, do not apply.
Use when:
- defensive guard without a failing trigger (null check, optional chaining advice with no demonstrated failure path), or
- unverified contract risk that needs human judgment (no source of truth available in the repo), or
- runtime-verification-required (SKILL.md `Verification Expectations → Runtime-verification-required claims`). Under `--cx`, this is the default bucket for any Codex finding whose trigger path was inferred from code rather than witnessed running. Escalate to Keep only when the main session observes the behavior directly (failing test, `curl` result, contradicting call site).

Skip items appear in the final summary count. Runtime-verification Skips also surface in the `--fix` termination "Needs manual verification" list.

**Drop** — Discard silently.
Use when:
- the finding is in SKILL.md's explicitly-NOT list AND has no concrete trigger path. Examples: generic style advice, performance/maintainability nits with no cited failure, pattern-complaint with no trigger; or
- the finding proposes behavior the user explicitly rejected earlier in the same session. Cite the prior turn in the round report so the Drop is auditable. Do not Skip — Skip implies "unverified but possibly valid"; here the user has already verified the opposite.

**Prior-round re-surface** — When a finding was raised in an earlier round and the user neither accepted nor rejected it explicitly, do not silently drop and do not silently escalate. Re-surface with a `prior-round: <severity>` tag and a one-line note of what changed since last round (new trigger path, new code evidence, or "no new evidence, re-asking"). Ambiguous user silence is not consent to either direction.

## Conflict Protocol

When two Keep findings recommend opposing actions (e.g., one says add an assertion, another says remove assertions of this type), resolve using SKILL.md Review Priorities:
contract and source of truth > semantic correctness > ownership boundary > failure behavior > security > complexity > tests and docs

The lower-priority finding moves to Not fixed. Main session does not improvise a resolution.

**Cross-path severity disagreement.** When broad and opinionated agree on a finding but disagree on severity by one step (P1 vs P2, P2 vs P3), separate the disagreement shape before deciding:

- *Scope-boundary disagreement* — both paths cite the same facts but locate the "contract" at different layers (one treats the plan doc as binding, the other treats the downstream consumer as binding). Take the lower severity and note the scope interpretation explicitly in the report.
- *Factual disagreement* — paths cite different code, different trigger paths, or different impact claims. Investigate in the main session (read the cited code, run a cheap repro) before surfacing. Do not split the difference without resolving the facts.

## Pre-filter sanity checks

Run these against the raw delegate output before applying the Filter:

- **Diff direction (MR/PR mode).** If a delegate flags a file not in `origin/<base>..HEAD`, suspect working-tree-vs-commit direction confusion — the finding may describe master commits the MR doesn't yet have, which rebase will absorb. Verify with `git log <base>..HEAD -- <file>` before forwarding.
- **File-not-in-diff (local mode).** Working-tree scope sweeps pre-existing untracked drift into the review surface. If a finding cites a file untouched by the user's actual session work, either note it as pre-existing or drop it — don't let the loop spend rounds fixing unrelated drift.

## Batch Fix Boundary

When multiple Keep findings share a root cause (e.g., three call sites with inconsistent behavior), a single small refactor may eliminate all of them. This is permitted only when ALL of:
- No new abstractions are introduced.
- No modules that were not cited in a finding are touched.
- The change is the minimum needed to eliminate the Keep findings.

If any condition fails, fall back to per-finding fixes. This is not a refactor session.

## Fix kept findings

After filtering:

1. Re-read the cited file/range to confirm the finding is accurate against the current code.
2. If correct, apply the minimal fix. Prefer hard assertions or error propagation over silent fallbacks.
3. If wrong or the fix would violate a principle, record why under **Not fixed**.
4. Opportunistic cleanup is allowed inside edited hunks only (typos, dead code, local renames). Anything outside those hunks is out of scope.

After edits, re-check changed files. Run existing validation commands (tests, lint, typecheck) if cheap. Do not run dev/build/start/serve commands.

**Output language**: per SKILL.md `## Output`, finding descriptions, fix directions, and the round report are in Chinese; file paths, code identifiers, severity tags, and bucket labels stay English.
