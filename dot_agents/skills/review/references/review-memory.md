# Review Memory

Use the local SQLite store only for review self-evolution records. It is a private aid for later review checks, not evidence for the current finding and not a skill editor.

Script (requires [Bun](https://bun.sh); uses `bun:sqlite`). Invoke it with the full path below; the commands further down abbreviate that path as `review-memory`:

```text
bun ~/.agents/skills/review/scripts/review-memory.js
```

Default database:

```text
~/.agents/skills/review/state/review-memory.sqlite3
```

Set `REVIEW_MEMORY_DB` only for tests or one-off inspection.

## Commands

```sh
bun ~/.agents/skills/review/scripts/review-memory.js init
bun ~/.agents/skills/review/scripts/review-memory.js record-run review.json
bun ~/.agents/skills/review/scripts/review-memory.js propose-rule --episode <id> --type <type> --trigger <text> --root-cause <text> --rule <text> --boundary <text> --negative-example <text>
bun ~/.agents/skills/review/scripts/review-memory.js search <query>
bun ~/.agents/skills/review/scripts/review-memory.js pack <proposal-id>
```

`record-run` accepts the canonical review JSON from `SKILL.md`. It writes one `episodes` row and `observations` rows for findings, weak notes, and manual gaps.

`propose-rule` writes one `rule_proposals` row, tagged with `--type` (one of the Candidate Types in [self-improvement.md](self-improvement.md)). Use it only after a repeated root cause is clear. Do not turn every finding into a proposal.

`search` returns up to five open proposals matching all query terms. It is read-only.

`pack` prints a Markdown proposal pack. It does not write the database and does not edit skill files.

## Write Timing

| Moment | Command | Writes |
| --- | --- | --- |
| Before a review starts | `review-memory search <query>` | Nothing. Read-only lookup. |
| During review investigation | none | Nothing. |
| After final review verdict | `review-memory record-run review.json` | `episodes` and `observations`. |
| After a repeated root cause is clear | `review-memory propose-rule ...` | `rule_proposals`. |
| When the user asks to inspect a proposal | `review-memory pack <proposal-id>` | Nothing. |

## Boundaries

- Treat search results as checklist prompts only. Re-check current files, contracts, and runtime evidence before reporting a finding.
- Keep `review-memory` independent from `write-skill`. A proposal pack is input for a separate skill-maintenance task only when the user asks for one.
- If the script is unavailable or a write fails, report `private review-memory unavailable: <reason>`.
- Do not store command logs, shell history, raw secrets, or secret-like paths.
