# Result Contract

Load before emitting machine-readable review JSON, handing findings to `--fix`, or rendering HTML.

Use one canonical JSON document. Normal chat does not use this contract. Write review prose in Chinese, keeping identifiers, paths, commands, severity tags, error codes, and host terms in English.

## Shape

```json
{
  "meta": {
    "project": "acme/web",
    "verdict": "1 项待跟进",
    "scope": "MR !247 · 2 files",
    "scope_slug": "mr247",
    "reviewed_sha": "15c25380",
    "repo_root": "Users/me/Code/web",
    "mr": {
      "iid": 247,
      "title": "标题",
      "url": "https://gitlab.example/acme/web/-/merge_requests/247"
    },
    "validation": "运行了目标测试",
    "rationale": {
      "requirement": "要解决什么",
      "assessment": "方案是否合理"
    }
  },
  "findings": [
    {
      "sev": "P2",
      "path": "lib/x.ts",
      "line": 42,
      "title": "一句话结论",
      "level": "confirmed",
      "provenance": "newly reachable",
      "diff_contribution": "新增调用方使既有缺陷进入正常路径",
      "problem": "什么问题",
      "trigger": ["触发步骤", "中间步骤", "后果"],
      "evidence": "决定性证据",
      "impact": "已验证的影响和边界",
      "fix": "修复方向"
    }
  ],
  "files": [
    { "path": "lib/x.ts", "add": 19, "del": 6 },
    { "path": "lib/clean.ts", "note": "未发现问题" }
  ]
}
```

`meta.project`, `meta.verdict`, and `findings` are required. Optional metadata is `scope`, `scope_slug`, `reviewed_sha`, `repo_root`, `mr`, `author`, `branch`, `stat`, `validation`, and `rationale`. `repo_root` is absolute without the leading slash. Use a host-provided MR/PR URL; omit `mr` when no verified URL exists.

Each finding requires:

- `sev`: `P1`, `P2`, or `P3`
- `path`, `title`, `problem`, `evidence`, `impact`, and `fix`
- `line` when known
- `level`: `confirmed` or `manual`
- `provenance`: `introduced`, `newly reachable`, `worsened`, `pre-existing`, or `unknown`
- `diff_contribution` unless provenance is `introduced`; for `unknown`, name the failed attribution step
- non-empty `trigger`; a direct contract mismatch may use one step

A `manual` finding must pass SKILL.md's material-gap gate and name the one missing boundary or runtime fact. It alone represents the gap; do not duplicate it in metadata or a weak-note side channel. A clean review uses `"findings": []`.

`files` is optional. Each entry requires `path`; `add`, `del`, and a clean-file `note` are optional. Omit empty optional fields.
