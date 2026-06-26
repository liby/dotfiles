# HTML Report Workflow

Load only when the user requested `--html`, a report, an artifact, or a visual review, and the canonical review JSON from `references/contracts/result.md` already exists.

## Render

```bash
REVIEW_SKILL_DIR="${REVIEW_SKILL_DIR:-$HOME/.agents/skills/review}"
RENDER="$REVIEW_SKILL_DIR/scripts/render-review.mjs"
DATA=$(mktemp)   # write the review JSON to this file, or pipe it on stdin
node "$RENDER" "$DATA"
```

The script writes `/tmp/review/<project>/<scope_slug>-<timestamp>.html`, opens it, and prints the path. Timestamp is local time at minute precision, for example `202606031019`.

The JSON is the same canonical review data used by structured review workflows. The HTML workflow only adds rendering.

Invalid JSON exits non-zero with the parse error. Missing required meta, finding, file, or note fields, invalid severity values, and weak finding levels exit non-zero with the field name and index. Fix the JSON rather than editing the rendered HTML.

All HTML structure, escaping, colors, diff rendering, risk map, and accordion behavior live in `scripts/render-review.mjs`. The reviewer only produces the canonical JSON.
