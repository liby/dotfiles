# HTML Report Workflow

Load only when the user requested `--html`, a report, an artifact, or a visual review, and the canonical review JSON from `references/contracts/result.md` already exists.

```bash
REVIEW_SKILL_DIR="${REVIEW_SKILL_DIR:-$HOME/.agents/skills/review}"
RENDER="$REVIEW_SKILL_DIR/scripts/render-review.mjs"
node "$RENDER" <review-data.json>
```

The script prints the generated path and attempts to open it. If opening is denied, do not retry; return the JSON path, HTML path, and render command. On a contract or parse error, fix the JSON rather than the HTML.
