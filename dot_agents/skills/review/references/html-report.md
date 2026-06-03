# Review JSON and HTML Report

A review produces one JSON document. That JSON is the canonical data: the agent reads it, downstream steps (`--cx` merge, `--fix` seed) consume it, and it is the input to the HTML renderer. There is no second text format.

Default output is the raw JSON. Render HTML only when the user passes `--html` or asks for a report, artifact, or visual view. The JSON is identical either way; `--html` only adds the render step.

This file covers the field contract and the renderer. Language and evidence-level rules are defined in SKILL.md Output; the `--cx` path that turns delegate output into JSON is in [cx-delegation.md](cx-delegation.md).

## Render

```bash
REVIEW_SKILL_DIR="${REVIEW_SKILL_DIR:-$HOME/.agents/skills/review}"
RENDER="$REVIEW_SKILL_DIR/scripts/render-review.mjs"
DATA=$(mktemp)   # write the review JSON to this file (or pipe it on stdin)
node "$RENDER" "$DATA"
```

The script writes `/tmp/review/<project>/<scope_slug>-<timestamp>.html` (timestamp is local time, minute precision, e.g. `202606031019`), opens it, and prints the path. It auto-expands the first finding, renders the rest collapsed, and turns each `path:line` into a `vscode://file/...` link. Invalid JSON exits non-zero with the parse error; a finding missing a required field renders blank and warns on stderr.

## meta

| field | type | required | notes |
| --- | --- | --- | --- |
| `project` | string | yes | repo name; leads the title and the filename |
| `scope` | string | recommended | e.g. `working tree · 9 files`, `branch vs origin/main` |
| `scope_slug` | string | recommended | short filename slug: `wt`, `branch`, `mr234` |
| `reviewed_sha` | string | recommended | head SHA; not displayed |
| `repo_root` | string | for code links | absolute path WITHOUT a leading slash (`Users/me/Code/x`); the renderer prepends the slash to build `vscode://` links |
| `mr` | object | when MR/PR | `{ "iid": 234, "title": "...", "url": "https://.../merge_requests/234" }` |
| `verdict` | string | yes | one-line conclusion |
| `validation` | string | recommended | what was actually checked |
| `manual_gap` | string | recommended | what was not checked |
| `rationale` | object | recommended | `{ "requirement": "...", "assessment": "..." }`, shown as 需求与方案合理性 |

## findings[]

| field | type | required | notes |
| --- | --- | --- | --- |
| `sev` | `"P1"` / `"P2"` / `"P3"` | yes | uppercase only |
| `path` | string | yes | repo-relative path |
| `line` | number | recommended | drives the `vscode://` link target |
| `title` | string | yes | one-sentence conclusion |
| `level` | `"confirmed"` / `"manual"` / `"weak"` | recommended | evidence level; renderer defaults to `confirmed` when omitted |
| `problem` | string | yes | 什么问题 |
| `trigger` | string[] | recommended | 怎么引起的; the causal chain, last item is the consequence |
| `fix` | string | yes | 建议修复 direction |
| `fix_code` | string | optional | code snippet rendered under the fix |
| `evidence` | string | recommended | quoted code or cited behavior (in the collapsible 更多 block) |
| `impact` | string | recommended | 影响 / 边界 (in the collapsible 更多 block) |
| `mr_hunk_url` | string | when MR | link to the MR diffs page |

`sev` must be uppercase. The renderer keys CSS classes and the count pills off the exact value `P1`/`P2`/`P3`; `"p2"` silently loses the badge color and the left border.

Order findings by severity, highest first. The report auto-expands `findings[0]`, so the top one should be the most important.

`trigger` renders as a left-to-right train of short steps. Keep each step to a few words; the last step is the consequence. Omit `trigger` when a finding has no multi-step path.

Omit any optional field with no content. The renderer guards every optional field, so a missing key renders nothing. Emitting `null` or empty strings only wastes tokens, which is the lever for keeping the raw JSON cheap.

## notes[]

| field | type | required | notes |
| --- | --- | --- | --- |
| `text` | string | yes | the note |
| `level` | `"weak"` | recommended | always weak |

## MR / PR URL

Never fabricate a URL. Use the host CLI web URL or a user-provided one:

```bash
glab mr view <iid> --output json | jq -r .web_url        # GitLab
gh pr view <number> --json url -q .url                    # GitHub
```

Omit `mr` and `mr_hunk_url` when the URL is unknown. GitLab file anchors are path hashes, not filenames, so a `#file.ts` anchor does not jump; point `mr_hunk_url` at the `/diffs` page.
