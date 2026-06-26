# Result Contract

Load before emitting canonical review JSON, before handing findings to `--fix`, or before rendering HTML.

A review can produce one canonical JSON document. That JSON is the structured data: the agent reads it, `--fix` can consume it, and it is the input to the HTML renderer. There is no second JSON schema.

Normal chat review does not need this contract. Produce JSON only when the user requests `--html`, asks for a machine-readable report, or uses a workflow that consumes JSON. Render HTML only when the user passes `--html` or asks for a report, artifact, or visual view. The JSON is identical for every structured workflow; `--html` only adds the render step in `references/workflows/html.md`.

Respect exact output contracts first. When using this JSON output contract and there are no findings, emit `"findings": []` and state the clean result in `meta.verdict`.

**Language**: write `title`, `problem`, `trigger`, `fix`, `evidence`, `impact`, `verdict`, `rationale`, and notes as Chinese prose; keep English only for code identifiers, paths, commands, severity tags, error codes, and host terms (`MR`/`PR`/`SHA`). Do not translate word for word; write native Chinese review prose.

**Evidence level**: `confirmed` and `manual` can be numbered findings; a `manual` finding must name the missing runtime observation in `evidence` or `impact`. `weak` goes in `notes`, never a numbered finding. The renderer rejects `level: "weak"` inside `findings[]`.

## Example

```json
{
  "meta": {
    "project": "acme/web",
    "scope": "MR !247 · 6 files",
    "scope_slug": "mr247",
    "reviewed_sha": "15c25380",
    "repo_root": "Users/me/Code/web",
    "mr": { "iid": 247, "title": "标题", "url": "https://gitlab.example/x/-/merge_requests/247" },
    "author": "Mira Okafor",
    "branch": "feat/x -> main",
    "stat": { "add": 142, "del": 38, "files": 6 },
    "verdict": "方案合理，1 项待跟进",
    "validation": "仅静态验证",
    "manual_gap": "未做浏览器实测",
    "rationale": { "requirement": "要解决什么", "assessment": "方案是否合理" }
  },
  "findings": [
    {
      "sev": "P2",
      "path": "lib/x.ts",
      "line": 42,
      "title": "一句话结论",
      "level": "confirmed",
      "problem": "什么问题",
      "trigger": ["触发步骤", "中间步骤", "后果"],
      "fix": "修复方向",
      "code_snippet": "-  旧代码行\n+  新代码行",
      "evidence": "证据",
      "impact": "影响 / 边界"
    }
  ],
  "files": [
    { "path": "lib/x.ts", "add": 19, "del": 6 },
    { "path": "lib/clean.ts", "add": 4, "del": 1, "note": "无 finding 文件的一句话总结" }
  ],
  "notes": [{ "text": "weak 级别的非 finding 说明", "level": "weak" }]
}
```

## meta

| field | type | required | notes |
| --- | --- | --- | --- |
| `project` | string | yes | repo name; leads the title and filename |
| `scope` | string | recommended | e.g. `working tree · 9 files`, `branch vs origin/main` |
| `scope_slug` | string | recommended | short filename slug: `wt`, `branch`, `mr234` |
| `reviewed_sha` | string | recommended | head SHA; shown under the author in the header |
| `repo_root` | string | for code links | absolute path without a leading slash (`Users/me/Code/x`); the renderer prepends the slash to build `vscode://` links |
| `mr` | object | when MR/PR | `{ "iid": 234, "title": "...", "url": "https://.../merge_requests/234" }` |
| `author` | string | when MR/PR | PR author; renders an initials avatar and name in the header |
| `branch` | string | when known | e.g. `feat/x -> main`; a mono pill in the header |
| `stat` | object | when known | `{ "add": 142, "del": 38, "files": 6 }`; the +/-/files line in the header |
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
| `level` | `"confirmed"` / `"manual"` | recommended | evidence level; weak items stay in `notes[]` |
| `problem` | string | yes | what is wrong |
| `trigger` | string[] | recommended | causal chain; last item is the consequence |
| `fix` | string | yes | fix direction |
| `code_snippet` | string | optional | problem code as a local diff; each line prefixed `+`, `-`, or space |
| `fix_code` | string | optional | suggested fix code |
| `evidence` | string | recommended | quoted code or cited behavior |
| `impact` | string | recommended | impact and boundary |

`sev` must be uppercase. The renderer keys severity color, file risk tag, and risk-map dot off the exact value `P1`/`P2`/`P3`; `"p2"` loses all of them.

Findings group by `path` into file cards. A card's risk tag is the highest severity it carries, and cards sort by that risk. Within a card, bubbles sort by `line`. Keep the findings array sorted by severity too, so the raw JSON reads top-down.

`trigger` renders as a left-to-right train of short steps inside the bubble's more block. Keep each step to a few words. Omit `trigger` when a finding has no multi-step path.

Omit optional fields with no content. Emitting `null` or empty strings only wastes tokens.

Every prose field runs through one inline renderer: a backtick span `` `code` `` becomes inline `<code>`, and `==text==` becomes a highlight mark. Use the highlight for the single most load-bearing phrase in a finding.

## files[]

Optional. Drives the risk map and the collapsed summaries of clean files. A file with findings is inferred from `path` and needs no entry, but adding one supplies the `+/-` delta on its card. A file with no findings needs an entry to appear at all, shown as a collapsed row with its `note`.

| field | type | required | notes |
| --- | --- | --- | --- |
| `path` | string | yes | repo-relative path; matches `finding.path` for files that have findings |
| `add` | number | optional | added lines |
| `del` | number | optional | deleted lines |
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
glab mr view <iid> --output json | jq -r .web_url
gh pr view <number> --json url -q .url
```

Omit `mr` when the URL is unknown. The renderer reads the host number symbol off the URL path: a URL containing `/merge_requests/` renders `!<iid>` (GitLab), otherwise `#<iid>` (GitHub). Pass `iid` as the bare number.
