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

The script writes `/tmp/review/<project>/<scope_slug>-<timestamp>.html` (timestamp is local time, minute precision, e.g. `202606031019`), opens it, and prints the path. The layout is file-centric (modeled on Anthropic's `03-code-review-pr` html-effectiveness example): a PR/scope header whose PR number links to the MR/PR in a new tab, a risk map of all changed files with click-to-anchor navigation, and one collapsible card per file whose findings render as line-anchored review bubbles. File cards form a single-open accordion: the first card starts expanded, opening another collapses the previous, and any card can be closed. Each finding's `path:line` anchor becomes a `vscode://file/...` link. Invalid JSON exits non-zero with the parse error; a finding missing a required field renders blank and warns on stderr.

## meta

| field | type | required | notes |
| --- | --- | --- | --- |
| `project` | string | yes | repo name; leads the title and the filename |
| `scope` | string | recommended | e.g. `working tree · 9 files`, `branch vs origin/main` |
| `scope_slug` | string | recommended | short filename slug: `wt`, `branch`, `mr234` |
| `reviewed_sha` | string | recommended | head SHA; shown under the author in the header |
| `repo_root` | string | for code links | absolute path WITHOUT a leading slash (`Users/me/Code/x`); the renderer prepends the slash to build `vscode://` links |
| `mr` | object | when MR/PR | `{ "iid": 234, "title": "...", "url": "https://.../merge_requests/234" }` |
| `author` | string | when MR/PR | PR author; renders an initials avatar + name in the header |
| `branch` | string | when known | e.g. `feat/x → main`; a mono pill in the header |
| `stat` | object | when known | `{ "add": 142, "del": 38, "files": 6 }`; the +/−/files line in the header |
| `verdict` | string | yes | one-line conclusion; leads the summary block |
| `validation` | string | recommended | what was actually checked |
| `manual_gap` | string | recommended | what was not checked |
| `rationale` | object | recommended | `{ "requirement": "...", "assessment": "..." }`, shown in the summary block |

## findings[]

| field | type | required | notes |
| --- | --- | --- | --- |
| `sev` | `"P1"` / `"P2"` / `"P3"` | yes | uppercase only |
| `path` | string | yes | repo-relative path |
| `line` | number | recommended | drives the `vscode://` link target |
| `title` | string | yes | one-sentence conclusion |
| `level` | `"confirmed"` / `"manual"` / `"weak"` | recommended | evidence level (rules in SKILL.md Output); recorded by review-memory, not surfaced in the HTML |
| `problem` | string | yes | 什么问题 |
| `trigger` | string[] | recommended | 怎么引起的; causal chain, last item is the consequence (in the 更多 block) |
| `fix` | string | yes | 建议修复 direction |
| `code_snippet` | string | optional | the problem code as a local diff; each line prefixed `+`/`-`/space, rendered as a GitLab-style light diff (green/rose tints) in the bubble |
| `fix_code` | string | optional | suggested fix code, light panel under the fix |
| `evidence` | string | recommended | quoted code or cited behavior (in the 更多 block) |
| `impact` | string | recommended | 影响 / 边界 (in the 更多 block) |

`sev` must be uppercase. The renderer keys severity color (P1 rust / P2 clay / P3 olive), the file's risk tag, and the risk-map dot off the exact value `P1`/`P2`/`P3`; `"p2"` silently loses all of them.

Findings group by `path` into file cards; a card's risk tag is the highest severity it carries, and cards sort by that risk (most severe first). Within a card, bubbles sort by `line`. Keep the findings array sorted by severity too, so the raw JSON reads top-down.

`trigger` renders as a left-to-right train of short steps inside the bubble's 更多 block. Keep each step to a few words; the last step is the consequence. Omit `trigger` when a finding has no multi-step path.

Omit any optional field with no content. The renderer guards every optional field, so a missing key renders nothing. Emitting `null` or empty strings only wastes tokens, which is the lever for keeping the raw JSON cheap.

Every prose field (`title`, `problem`, `fix`, `evidence`, `impact`, `verdict`, `rationale.requirement` / `rationale.assessment`, `notes[].text`) runs through one inline renderer: a backtick span `` `code` `` becomes inline `<code>`, and `==text==` becomes a teal highlighter mark. Use the highlight for the single most load-bearing phrase in a finding (usually one mark per card); over-marking dilutes it.

## files[]

Optional. Drives the risk map and the collapsed summaries of clean files. A file with findings is inferred from `path` and needs no entry, but adding one supplies the `+/−` delta on its card. A file with no findings needs an entry to appear at all, shown as a collapsed row with its `note`.

| field | type | required | notes |
| --- | --- | --- | --- |
| `path` | string | yes | repo-relative path; matches `finding.path` for files that have findings |
| `add` | number | optional | added lines, shown as `+N` |
| `del` | number | optional | deleted lines, shown as `−N` |
| `note` | string | optional | one-line summary for a clean file's collapsed body |

Omit `files` entirely for a quick local pass; the risk map then lists only files that have findings.

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

Omit `mr` when the URL is unknown.

The renderer reads the host number symbol off the URL path: a URL containing `/merge_requests/` renders `!<iid>` (GitLab), otherwise `#<iid>` (GitHub). The host word (Merge/Pull Request) is omitted as redundant. Pass `iid` as the bare number; the renderer prepends `!` or `#`.
