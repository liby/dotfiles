# Cross-Model Delegation

How to delegate the review to a different model when `--cc` or `--codex` is passed.

The delegate receives this same skill (without the flag), reads the full SKILL.md, and reviews directly. No principle extraction or loop prevention needed.

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

## `--codex`: Delegate to Codex

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

Run the Codex companion from within the worktree:

```bash
cd "$TMPDIR/review-<mr-number>"
node "$CODEX_ROOT/scripts/codex-companion.mjs" adversarial-review --wait [pass-through flags] "<focus text>"
```

- `--wait` is required: it keeps `argv.length >= 2` so the companion script does not re-tokenize the focus block.
- Inline the focus text directly as a shell argument. Do not write it to a temp file.
- Shell-quote the focus string so newlines are preserved as one argv element.
- Pass through `--base <ref>` and `--scope <value>` from the user.

### Filter findings

Walk every finding from the Codex report:

- **Keep**: finding cites observed failure, API contract, tenant isolation, data loss, auth bypass, race condition, schema drift, rollback risk, observability gap, or correctness bug.
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
