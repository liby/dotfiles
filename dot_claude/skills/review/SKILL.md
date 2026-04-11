---
name: review
description: Run a Codex adversarial review with anti-defensive-programming principles applied, filter defensive-only findings, then fix every remaining finding in-place and return a summary. Use when the user says "review", "/review", "让 codex 看一下", "codex review", or asks for a Codex review of current changes. Wraps /codex:adversarial-review — do not touch plugin files or the strict /codex:review flow.
context: fork
argument-hint: "[--base <ref>] [--scope auto|working-tree|branch] [focus ...]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
---

## Goal

Run a principled Codex adversarial review against the current git state, filter out defensive-only findings, then **fix every remaining finding in-place** within this skill's execution, and return a summary of what was fixed and what was intentionally left alone. Skepticism and rigor stay — the only thing suppressed is defensive-programming advice for unobserved failures.

The user does not want a review-then-prompt loop. If a finding survives the filter, default to fixing it; only skip when fixing is genuinely wrong (e.g., the finding is incorrect, or the fix would violate a separate principle).

## Preflight

1. Confirm there is something to review:
  - `git status --short --untracked-files=all`
  - `git diff --shortstat --cached` and `git diff --shortstat`
  - For `--base <ref>`, also `git diff --shortstat <ref>...HEAD`
  - If the scoped state is empty, return `nothing to review` and stop.

2. Parse `$ARGUMENTS`:
  - Collect `--base <ref>` and `--scope <value>` as pass-through flags.
  - **Drop** any `--wait` or `--background` — this wrapper always runs foreground inside its forked subagent; the user is already blocked on the skill so detaching has no value.
  - Everything after the known flags is the user's focus tail. Keep it; it will be appended after the principles block.

## Principles injected as focus text

Build the final focus string by concatenating this block verbatim, then a blank line, then the user's focus tail (if any):

```
Principles the reviewer MUST apply (these override default defensive-programming habits):

1. Do NOT suggest adding null guards, optional chaining, try/catch, or fallback values for code paths where no failure has actually been observed. If the API contract does not document that a value can be null or a call can throw, assume it does not.
2. If a guard is genuinely required by contract or observed failure, prefer a hard assertion that exposes the violated invariant — not a silent fallback to null, undefined, false, or [].
3. Errors must be observable. Do not suggest swallowing errors, using Promise.allSettled where errors should propagate, or wrapping business logic in try/catch just to continue. Let errors propagate and catch only at API/route/job boundaries where recovery is defined.
4. Question every assumed failure mode. For each proposed guard you keep, cite the API doc, contract, or observed behavior that justifies it. Inconsistent defensive checks in the same code path (checking one field but not its siblings) are a code smell — flag the inconsistency, not the missing check.
5. Retries are for transient faults only. Do not suggest retry as a way to wait for external resources — that should be explicit delay or polling.
6. Prioritize real risks: correctness, auth, tenant isolation, data loss or corruption, rollback safety, races, schema or version skew, and observability gaps. Do not pad the report with stylistic defensive programming suggestions.

Still report every material issue in the categories above. Do not go easy on the change — the goal is to drop stylistic defensiveness, not to lower the bar for real failures.
```

## Resolve the codex plugin root

Do not hardcode the plugin path — the authoritative install location is under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` and the version segment changes on every update. Resolve it at runtime via `claude plugin list --json`, which exposes an `installPath` field per plugin entry:

```bash
CODEX_ROOT=$(claude plugin list --json | jq -r '.[] | select(.id == "codex@openai-codex" and .enabled == true) | .installPath')
if [ -z "$CODEX_ROOT" ] || [ ! -f "$CODEX_ROOT/scripts/codex-companion.mjs" ]; then
  echo "codex plugin not installed or disabled — cannot run principled review" >&2
  exit 1
fi
```

Fail loud if the plugin is missing or disabled.

## Run the review

Call the companion script directly via the resolved root. Do not attempt `/codex:adversarial-review` — the slash command's `Foreground flow` section mandates `Return the command stdout verbatim, exactly as-is`, which leaves no hook for the post-processing this skill needs to do.

```bash
node "$CODEX_ROOT/scripts/codex-companion.mjs" adversarial-review --wait [pass-through flags] "<principles + user focus>"
```

The focus string is the trailing positional argument — shell-quote it so the whole block (including newlines) reaches the script as one argv element. Capture stdout verbatim.

`--wait` is load-bearing, not optional: it keeps `argv.length >= 2` so the companion script's `normalizeArgv` does not re-tokenize our multi-line focus block by whitespace. Never send empty focus either — `buildAdversarialReviewPrompt` substitutes a default placeholder that would erase the principles block.

## Filter findings

Walk every finding in the returned report and categorize:

- **Keep**: any finding whose recommendation cites observed failure, an API contract, tenant isolation, data loss, auth bypass, race condition, schema drift, rollback risk, observability gap, idempotency, or a correctness bug.
- **Skip**: any finding whose recommendation is entirely "add a null check", "add optional chaining", "add try/catch", "add fallback value", or "handle missing field" with no evidence of observed failure, contract violation, or downstream impact.
- **Rewrite**: if a finding mixes a real concern with a defensive suggestion, keep the real concern and drop the defensive portion from the recommendation.

Record skipped findings with their file/line and the one-line phrase `unobserved-failure guard`. Never suppress a finding that names a real failure mode — this is not about going easy on the change.

## Fix the kept findings

After filtering, work through the kept findings and fix them directly using Edit / Write. Treat this as the default — do not return to the user and ask whether to fix. For each kept finding:

1. Re-read the cited file/range to confirm the finding is accurate against the current code. Codex can be wrong, and its sandbox may have been stale.
2. If the finding is correct, apply the minimal fix that addresses the root cause. Respect the repo's existing style and the anti-defensive-programming principles — prefer hard assertions or propagation over silent fallbacks.
3. If the finding is wrong, or the fix would violate a separate principle (e.g., adding a guard Codex asked for but the contract does not justify), do not fix it. Record why under **Not fixed** in the summary.
4. Opportunistic cleanup is allowed inside the hunks you are already editing (typos, dead code, local renames, obviously stale comments). Anything outside those hunks, or any change touching signatures / interfaces / control flow / data shape, is out of scope for this pass. Every opportunistic change must be listed under **Opportunistic cleanup** in the return summary — the summary must be a superset of the diff.

Edit files inline within this skill's execution — do not spawn another subagent for the fix pass.

After edits, re-check the changed files (Read / Grep) to confirm each intended change landed and no stray edits slipped in. Run any cheap local verification that fits the repo (type check, lint) if one is already configured — skip if none exists, and do not fabricate new commands. Never run dev / build / start / serve commands for frontend projects.

## Return format

Return a compact summary to the user:

```
# Codex principled review — <target>

Verdict: <ship | needs-attention | blocked>  (post-fix verdict)

Fixed (<N>):
- <file:line> — <what was wrong> — <what changed>
...

Not fixed (<N>):
- <file:line> — <finding> — <reason for skipping>
...

Opportunistic cleanup (<N>):
- <file:line> — <what changed and why>
...

Skipped by filter (<N>, defensive-only):
- <file:line> — <what Codex proposed>
...
```

The summary must be a superset of the diff: if a change landed in a file, it appears in one of **Fixed** or **Opportunistic cleanup**. Drop empty sections rather than leaving them with `(0)`.

If the review found nothing material, return `Verdict: ship — no material findings` and stop. If Codex returned an `approve` status, mirror it as `Verdict: ship` and do not invent findings. If fixing is blocked on a question only the user can answer (ambiguous intent, missing domain knowledge), list that finding under **Not fixed** with the blocker — do not guess.

## Do not

- Do not edit plugin files or change how `/codex:review` or `/codex:adversarial-review` behave upstream.
- Do not touch git state (commit, push, reset, checkout). Fixing means editing files only — commit is a separate user action.
- Do not expand scope beyond the findings. This is a review-and-fix pass, not a refactor session.
