# Self-improve Journal

The journal at `~/.claude/skills/review/journal.md` accumulates evidence for *evolving this skill over time*: both what to delete (rules that didn't help) and what to codify (things the agent had to guess). Net direction is not "shrink only"; it's "calibrate to what actually matters."

## Who writes, who observes

**Writing is main-session only.** Only the main session can write to the journal; the Codex delegate under `--cx` runs in a `read-only` sandbox.

**Observations come from both sides.** The Codex delegate sees things the main session doesn't: rules that didn't fire, SKILL.md sections that led it astray, sandbox tool failures. Each Codex run appends a short **Journal suggestions** block to the end of its prose output (one to three bullets, each citing `path:line` or a concrete behavior). Shape: the same four-category format as the entry below, but with the category header inline.

**Main session, at exit**, reads Codex's Journal-suggestions block alongside its own observations and writes ONE entry to the top of the journal file. One exit, one entry. This covers report-only, `--cx`, `--fix` convergence, and `--fix` safety cap. For `--fix` loops specifically: one entry per session at exit, never per round.

## Writing entries

Each entry must be small enough to close. An entry that says `consider adding a rule about X` produces nothing actionable and accumulates as forever-`open`. An entry that quotes the exact line to add and the exact `path:line` to add it at can be closed in a minute.

Each `Over-specified` / `Under-specified` / `Odd behavior` bullet must include:

- The concrete `path:line` of the spec or code that's wrong or missing.
- The literal text of the proposed edit (not a paraphrase, not "consider adding").
- One sentence on the trigger this session that revealed the gap.

If the proposed edit can't be stated in one or two sentences with a clear insertion point, the entry is too vague to ship. Either narrow it until it can, or drop it entirely.

## Entry format

Prepend a new section to the top of the file (use Write/Edit, not `cat >>` which only appends to the bottom). The four section names below are a closed enumeration; do not invent your own headers like `Keep / codify` or `Flag for evolution`. Skip any section that has nothing concrete; **do not pad with `无。`, `(none)`, or `N/A` placeholders**. Omit the section header entirely.

```markdown
## <YYYY-MM-DD> <flags> <target-desc> [repo=<abs-repo-path>, rounds=<N>, exit=<convergence|safety-cap>]

### Over-specified (deletion candidates)
- <specific rule/section that didn't help, cited by path:line, concrete enough to act on>
  - Status: `open` | `addressed: <pointer>` | `reverted: <why>`

### Under-specified (had to guess)
- <what was missing + suggested addition>
  - Status: ...

### Rule that saved me (keep)
- <specific rule that prevented a real mistake this session, with what the mistake would have been>

### Odd behavior
- <unexpected pattern worth noting, e.g. tool failure, surprising Codex output>
  - Status: ...
```

`Status:` applies to `Over-specified`, `Under-specified`, and `Odd behavior` because each implies a pending edit somewhere. `Rule that saved me` bullets do **not** carry `Status:`. They confirm an existing rule worked, there is nothing to address. Marking them `open` falsely inflates the backlog and obscures what actually needs attention.

Header fields:

- `<flags>`: the invocation flags. One of `--fix --cx`, `--cx`, `--fix`, or empty for plain report-only.
- `<target-desc>`: commit SHA, MR number, or branch name.
- `repo=<abs-repo-path>`: required. A SHA or MR number without the repo is un-resolvable a month later.
- `rounds=<N>`: include only under `--fix`. Omit for report-only.
- `exit=<convergence|safety-cap>`: include only under `--fix`. Omit for report-only (no loop = no loop outcome).

## Hard rules

- `Status:` values: `addressed: <pointer>` cites the SKILL.md section, reference doc, commit, or memory file where the lesson was codified; `reverted: <why>` records when a lesson turned out wrong on a later session; `open` is the default at write time. (Scope: applies to `Over-specified`, `Under-specified`, `Odd behavior`. `Rule that saved me` is exempt; see Entry format.)
- Max 5 bullets total across all four categories per entry. Force prioritization.
- No "review went well", "rules were helpful", or any success-report bullets. Deltas only.
- Every bullet cites a `path:line` or a concrete behavior, not vague reflection.
- Past entries may be edited later when a lesson is addressed in a follow-up session: update the `Status:` line of the relevant bullet rather than appending a new entry about the same thing.
