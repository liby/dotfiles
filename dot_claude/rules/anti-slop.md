# Anti-AI slop

Applies to every output in both Chinese and English: chat, explanations, MR/PR descriptions, IM/email drafts, commit messages, announcements. Use direct factual language; rhetorical setup before the point is noise.

## Patterns to fix

Each rule names a mechanism. Listed tokens are illustrative, not exhaustive. Match by mechanism, not by token literal.

- **One paragraph, one idea.** If a paragraph bridges adjacent-but-distinct points, split it. The split surfaces which point is load-bearing.
- **State the corrected point directly.** Use "不是 X 而是 Y" / "Not X, it's Y" only when overturning something the user or a prior turn actually said. Otherwise drop the contrast and assert Y.
- **Name the concrete action or invariant instead of decisiveness signals.** Replace `落地` with `deployed with rollback ready`; replace `更硬` / `把 X 写硬` with `enforced at compile time` / `assert at request boundary` / `unique constraint at DB layer`. Rewrite the sentence; don't just delete the token. Tokens to flag: `落地`, `落库`, `落盘`, `抓手`, `闭环`, `开干`, `起飞`, `更硬`, `最硬`.
- **Use literal editing verbs.** For file moves, renames, deletions, or structural edits, use `移 / 改名 / 删 / 加`. Do not use `砍` to mean deleting edits, files, or code; do not flag the token outside an edit context.
- **Name what concretely changed.** Replace `streamline / enhance / robustify / leverage / facilitate` with the specific change. Use `use` instead of `leverage`.
- **End the sentence at the actual point.** Delete redundant trailing soft-restatements (`这说明……`, `也就是说……`, `换句话说……`). If the previous sentence already made the point, stop there.
- **Deliver the conclusion directly without announcing structure.** Drop `一句话总结`, `一句话 X 版`.
- **Back intensity with evidence or downgrade the claim.** When a claim carries intensity (severity, confidence, a guarantee, or grandiose framing like `彻底改变` for routine work), attach the number, observed behavior, or consequence that licenses it; if none exists, downgrade the claim instead of decorating it. Unlicensed intensity (`可被稳定复现`, `completes reliably`, a confidence label higher than the stated evidence supports) reads as style but fails as accuracy.
- **Silently filter spurious IDE diagnostics.** Spurious means the warning is technically correct against its own spec, but this file does not belong to that spec. Examples: VS Code agent linter says `allowed-tools` / `context: fork` are unknown (true under VS Code agent spec, valid under Claude Code skill spec); cSpell flags library / CLI / domain names (true that they aren't dictionary words, valid as technical terms here). If you cannot confirm the warning is spurious, verify against the file's actual spec first (`code.claude.com/docs` for Claude Code skills). Do not write rebuttal sentences for confirmed-spurious ones.

## Formatting rules

- Use comma, period, or colon for separators. Replace em-dash (`—`, `——`, `--`) by rewriting the sentence. Do not substitute `-`. CLI flags and code tokens (`--fix`, `--dry-run`) are identifiers, not em-dashes; leave them.
- Use ASCII `->` for chain or transformation arrows in prose, and `>` for breadcrumb separators (`Settings > Account > Profile`). Unicode `→` reads as AI decoration outside math or science contexts. For git ref ranges, use literal git syntax `A..B` / `A...B`.
- Chinese prose uses fullwidth punctuation (`，。：；！？（）「」`), not ASCII halfwidth. ASCII punctuation stays inside code identifiers, file paths, and English terms themselves (`file.ext:line`, `foo(bar)`). In mixed Chinese/English sentences, punctuation follows the language of the surrounding clause.
- Reserve bold for labels in label-value lists, table headers, and section titles. A paragraph with 3+ bolded phrases means most are wrong.
- Reserve quote marks for actual quotations, system output, error messages, or a term's first-time introduction. Use plain text or italic for emphasis: `防止 Agent 提升分数` is the right form, `防止 Agent "提升"分数` is the wrong form.
- Code blocks: always specify language; use `plaintext` when no syntax highlighting fits.
- Headings: add blank line after all headings for better readability.
- Links: use descriptive link text that describes the destination. Render external identifiers (PR/issue numbers, commit SHAs, ticket keys) as clickable markdown links.

## Final output check

Before sending, scan the draft for these high-frequency offenders. When you find one, rewrite the surrounding sentence around its underlying intent. Do not delete the token while leaving the rest of the sentence intact.

- Trailing restatement: `这说明`, `也就是说`, `换句话说`
- Corporate jargon: `落地`, `落库`, `落盘`, `闭环`, `开干`, `起飞`, `抓手`, `更硬`, `最硬`
- Edit-deletion metaphor: edit-context `砍` (use `删`)
- Signposted meta: `一句话总结`, `一句话 X 版`
- Em-dash: `—`, `——`, `--` (CLI flags like `--fix` exempt)
- Unicode arrow: `→` in prose (use `->`)

<examples>
<example name="em-dash replacement">
Wrong: `修复了 bug — 但测试还没跑`
Right: `Bug 已被修复，但还没有跑测试。`
</example>

<example name="plain language instead of jargon">
Wrong: `这个改动需要落地到生产环境，形成闭环`
Right: `我会为这次的改动补上回滚机制，然后部署到生产环境。`
</example>

<example name="silently filter cSpell noise on technical terms">
Wrong: `已完成。cSpell 关于 backtest 的告警是技术词典缺词，可以忽略。`
Right: `已完成。`
</example>

<example name="end sentence at the point, no trailing restatement">
Wrong: `这次 PR 改了 3 个 file，加了 init 流程。这说明 init 流程之前是缺失的。`
Right: `这次 PR 改了 3 个 file，加了之前缺失的 init 流程。`
</example>
</examples>
