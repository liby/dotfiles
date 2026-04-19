# Self-improve Journal

The journal at `~/.claude/skills/review/journal.md` accumulates evidence for *evolving this skill over time* — both what to delete (rules that didn't help) and what to codify (things the agent had to guess). Net direction is not "shrink only" — it's "calibrate to what actually matters."

## Who writes, who observes

**Writing is main-session only.** Only the main session can write to the journal; the Codex delegate under `--cx` runs in a `read-only` sandbox.

**Observations come from both sides.** The Codex delegate sees things the main session doesn't — rules that didn't fire, SKILL.md sections that led it astray, sandbox tool failures. Each Codex run appends a short **Journal suggestions** block to the end of its prose output (one to three bullets, each citing `file:line` or a concrete behavior). Shape: the same four-category format as the entry below, but with the category header inline.

**Main session, at exit**, reads Codex's Journal-suggestions block alongside its own observations and writes ONE entry to the top of the journal file. One exit, one entry — this covers report-only, `--cx`, `--fix` convergence, and `--fix` safety cap. For `--fix` loops specifically: one entry per session at exit, never per round.

## Entry format

Append a new section to the top of the file:

```markdown
## <YYYY-MM-DD> <flags> <target-desc> [repo=<abs-repo-path>, rounds=<N>, exit=<convergence|safety-cap>]

### Over-specified (deletion candidates)
- <specific rule/section that didn't help, cited by file:line, concrete enough to act on>
  - Status: `open` | `addressed: <pointer>` | `reverted: <why>`

### Under-specified (had to guess)
- <what was missing + suggested addition>
  - Status: ...

### Rule that saved me (keep)
- <specific rule that prevented a real mistake this session, with what the mistake would have been>
  - Status: ...

### Odd behavior
- <unexpected pattern worth noting — e.g. tool failure, surprising Codex output>
  - Status: ...
```

Header fields:

- `<flags>`: the invocation flags — `--fix --cx`, `--cx`, `--fix`, or empty for plain report-only.
- `<target-desc>`: commit SHA, MR number, or branch name.
- `repo=<abs-repo-path>`: required. A SHA or MR number without the repo is un-resolvable a month later.
- `rounds=<N>`: include only under `--fix`. Omit for report-only.
- `exit=<convergence|safety-cap>`: include only under `--fix`. Omit for report-only (no loop = no loop outcome).

## Hard rules

- Every bullet carries a `Status:` line. `addressed: <pointer>` points at the SKILL.md section, reference doc, commit, or memory file where the lesson was codified. `reverted: <why>` records when a lesson we thought was right turned out wrong on a later session. `open` is the default at session exit.
- Max 5 bullets total across all four categories per entry. Force prioritization.
- Skip any category that has nothing concrete to say — do not pad.
- No "review went well", "rules were helpful", or any success-report bullets. Deltas only.
- Every bullet cites a `file:line` or a concrete behavior, not vague reflection.
- Do **not** read prior journal entries during a review. The journal is for the user, not future agent context.
- Past entries may be edited later when a lesson is addressed in a follow-up session — update the `Status:` line of the relevant bullet rather than appending a new entry about the same thing.
