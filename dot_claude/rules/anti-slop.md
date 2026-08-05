# Anti-AI slop

Applies to every output in both Chinese and English: chat, explanations, MR/PR descriptions, IM/email drafts, commit messages, announcements. Use direct factual language; rhetorical setup before the point is noise. Use emoji only when the user explicitly asks.

## Patterns to fix

Each rule names a mechanism. Listed tokens are illustrative, not exhaustive. Match by mechanism, not by token literal.

- **One paragraph, one idea.** If a paragraph bridges adjacent-but-distinct points, split it. The split surfaces which point is load-bearing.
- **State the corrected point directly.** Use "不是 X 而是 Y" / "Not X, it's Y" only when overturning something the user or a prior turn actually said. Otherwise drop the contrast and assert Y.
- **Name the concrete change instead of decisiveness signals or vague-improvement verbs.** Replace `落地` with the most specific action supported by the available evidence; do not infer implementation, merge, deployment, persistence, or rollback state from the word itself. Replace `更硬` / `把 X 写硬` with `enforced at compile time` / `assert at request boundary` / `unique constraint at DB layer`; replace `streamline / enhance / robustify / leverage / facilitate` with the specific change, and use `use` instead of `leverage`. Rewrite the sentence; don't just delete the token. Tokens to flag: `落地`, `落库`, `落盘`, `抓手`, `闭环`, `开干`, `起飞`, `更硬`, `变硬`, `最硬`.
- **Use literal editing verbs.** For file moves, renames, deletions, or structural edits, use `移 / 改名 / 删 / 加`. Do not use `砍` to mean deleting edits, files, or code; do not flag the token outside an edit context.
- **Write the system's own English string instead of coining a Chinese label for it.** In Chinese output, keep the exact greppable English form of identifiers, config keys, error or status tokens, API/SDK/vendor concepts, product names, UI strings, section headers, and repo-defined artifacts: `TypeScript` not `Type Script`, `root layout` not `根布局`, `cache entry` not `缓存条目`. Do not translate a repo-defined artifact into an invented label (`评论机器人` for a `review-bot` workflow, `Stripe 对账单` for `stripe-parse-statement`): cut the detail if the reader will not act on it, otherwise write the identifier. Verbs, connectives, narration, and established Chinese business nouns stay Chinese, including natural combinations such as `MR 描述` and `GitLab 项目`.
- **End at the point, without announcing it.** Delete redundant trailing soft-restatements (`这说明……`, `也就是说……`, `换句话说……`) and structure announcements (`一句话总结`, `一句话 X 版`). If the previous sentence already made the point, stop there.
- **Back intensity with evidence or downgrade the claim.** When a claim carries intensity (severity, confidence, a guarantee, or grandiose framing like `彻底改变` for routine work), attach the number, observed behavior, or consequence that licenses it; if none exists, downgrade the claim instead of decorating it. Unlicensed intensity (`可被稳定复现`, `completes reliably`, a confidence label higher than the stated evidence supports) reads as style but fails as accuracy. The same failure runs in reverse: keep a hedge that carries real uncertainty; deleting it manufactures confidence the evidence does not license.
- **Silently filter spurious IDE diagnostics.** Spurious means the warning is technically correct against its own spec, but this file does not belong to that spec. Examples: VS Code agent linter says `allowed-tools` / `context: fork` are unknown (true under VS Code agent spec, valid under Claude Code skill spec); cSpell flags library / CLI / domain names (true that they aren't dictionary words, valid as technical terms here). If you cannot confirm the warning is spurious, verify against the file's actual spec first (`code.claude.com/docs` for Claude Code skills). Do not write rebuttal sentences for confirmed-spurious ones.

## Formatting rules

- Use comma, period, or colon for separators. Replace em-dash (`—`, `——`, `--`) by rewriting the sentence. Do not substitute `-`. CLI flags and code tokens (`--fix`, `--dry-run`) are identifiers, not em-dashes; leave them.
- Use ASCII `->` for chain or transformation arrows in prose, and `>` for breadcrumb separators (`Settings > Account > Profile`). Unicode `→` reads as AI decoration outside math or science contexts. For git ref ranges, use literal git syntax `A..B` / `A...B`.
- Chinese prose uses fullwidth punctuation (`，。：；！？（）「」`), not ASCII halfwidth. ASCII punctuation stays inside code identifiers, file paths, and English terms themselves (`file.ext:line`, `foo(bar)`). In mixed Chinese/English sentences, punctuation follows the language of the surrounding clause.
- Reserve bold for labels in label-value lists, table headers, and section titles; a paragraph with 3+ bolded phrases means most are wrong. Reserve quote marks for actual quotations, system output, error messages, or a term's first-time introduction; use plain text or italic for emphasis: `防止 Agent 提升分数` is the right form, `防止 Agent "提升"分数` is the wrong form.
- Code blocks: always specify language; use `plaintext` when no syntax highlighting fits.
- Links and citations: use descriptive link text that describes the destination, and render external identifiers (PR/issue numbers, commit SHAs, ticket keys) as clickable markdown links. Place evidence inline next to the claim it supports, quoting 1-3 lines plus a clickable `file_path:line_number` for code; no trailing sources section.

## Final output check

Before sending, scan the draft against the mechanisms above. When one matches, rewrite the surrounding sentence around its underlying intent; do not delete the token while leaving the rest of the sentence intact.

<examples>
<example name="silently filter cSpell noise on technical terms">
Wrong: `已完成。cSpell 关于 backtest 的告警是技术词典缺词，可以忽略。`
Right: `已完成。`
</example>

<example name="use the system's own name for a code-level thing">
Wrong: `把 Stripe 对账单和评论机器人里的 model id 换成 claude-opus-5`
Right: `把 stripe-parse-statement 和 review-bot 里的 model id 换成 claude-opus-5`
</example>
</examples>
