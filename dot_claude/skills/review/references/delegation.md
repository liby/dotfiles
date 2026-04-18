# Cross-Model Delegation

How to delegate the review to a different model when `--cc` or `--cx` is passed.

The delegate receives this same skill (without the flag), reads the full SKILL.md, and reviews directly.

## `--cc`: Delegate to Claude Code

```bash
claude -p "Run /review on the current branch" \
  --allowedTools "Bash,Read,Grep,Glob"
```

Claude Code will discover the same `review` skill, read its SKILL.md (without `--cc`), and review directly.

Key flags: `-p` for single-shot, `--allowedTools` to pre-approve tools, `--output-format json` for structured output, `--max-turns N` to cap turns.

## Do not

- Do not edit Codex plugin files or change how the companion script behaves upstream.
- Do not touch git state (commit, push, reset, checkout). Fixing means editing files only.
- Do not expand scope beyond the findings. This is a review-and-fix pass, not a refactor session.

## `--cx`: Delegate to Codex

### Resolve the Codex plugin

Do not hardcode the plugin path — the version segment changes on every update. Resolve at runtime:

```bash
CODEX_ROOT=$(claude plugin list --json | jq -r '.[] | select(.id == "codex@openai-codex" and .enabled == true) | .installPath')
if [ -z "$CODEX_ROOT" ] || [ ! -f "$CODEX_ROOT/scripts/codex-companion.mjs" ]; then
  echo "codex plugin not installed or disabled" >&2
  exit 1
fi
```

### Run the review

**Each round's review delegation must use a fixed `task` invocation that runs this same `/review` skill end-to-end. Do not write per-round custom prompts, and do not narrow scope between rounds.** The prompt is a single invariant string, the same every round of every loop; any caller-written variation makes scope a property of the caller and collapses round-over-round as the loop narrows onto the last fix. Going through `task` (instead of `adversarial-review`) preserves `/review`'s full semantic contract — logic bugs, API contract breakage, meaningful testing gaps — which `adversarial-review`'s own SKILL.md explicitly excludes.

Run the Codex companion from within the worktree:

```bash
cd "$TMPDIR/review-<mr-number>"
node "$CODEX_ROOT/scripts/codex-companion.mjs" task --wait \
  "Follow the review skill at ~/.claude/skills/review/SKILL.md. Review this worktree against base <base-ref> within scope <scope>. Output findings per the skill's Output section."
```

- `--wait` is required: it keeps `argv.length >= 2` so the companion script does not re-tokenize the prompt.
- `<base-ref>` and `<scope>` come from the user's original `/review --fix` flags and are invariant across rounds. Substitute once; do not recompute per round.
- The prompt above is the entire prompt. Do not append per-round context, do not inject "verify the fix from Round N-1", do not reference specific files or prior rounds, do not add severity filters. The round's scope is what `<base>` / `<scope>` say it is.

### Filter findings

Walk every finding from the Codex report:

- **Keep**: finding cites observed failure, API contract, tenant isolation, data loss, auth bypass, race condition, schema drift, rollback risk, observability gap, or correctness bug. Fix every Keep regardless of severity — `autofix.md`'s exit condition is defined against the Keep set, not P1/High.
- **Skip**: finding is entirely "add a null check / optional chaining / try-catch / fallback" with no evidence of observed failure or contract violation.
- **Rewrite**: finding mixes a real concern with a defensive suggestion — keep the real concern, drop the defensive portion.

Record skipped findings with file/line and `unobserved-failure guard`.

### Fix kept findings

After filtering:

1. Re-read the cited file/range to confirm the finding is accurate against the current code.
2. If correct, apply the minimal fix. Prefer hard assertions or error propagation over silent fallbacks.
3. If wrong or the fix would violate a principle, record why under **Not fixed**.
4. Opportunistic cleanup is allowed inside edited hunks only (typos, dead code, local renames). Anything outside those hunks is out of scope.

After edits, re-check changed files. Run existing validation commands (tests, lint, typecheck) if cheap. Do not run dev/build/start/serve commands.
