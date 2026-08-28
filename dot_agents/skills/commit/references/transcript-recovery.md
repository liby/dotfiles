# Transcript Recovery

Load only to recover commit motivation that spans prior agents, directories, or conversations. Search Claude Code under `~/.claude/projects/**/*.jsonl` and Codex under `~/.codex/sessions/**/*.jsonl` without exposing raw transcript content.

1. Build specific terms from changed paths, branch names, issue IDs, symbols, and user context; never start with broad words such as `fix`, `update`, or `commit`.
2. Search the current Claude project first, then Codex sessions mentioning the repository, branch, or changed path. Search globally only when cross-agent or cross-directory work is known and at least two specific terms are available.
3. Use `rg -l --fixed-strings` to list candidates and bound broad searches by date, project slug, or another term. Extract only assistant summaries, final messages, plans, and bounded tool-result summaries with `jq`; avoid raw output, environment dumps, logs, process lists, auth output, and secret-like paths.
4. Trust the current diff for what changed and transcripts only for why. Route transcript-only local state, rejected alternatives, skipped tools, operator workflow, test results, and manual verification gaps to the post-commit report.
5. After one broad search and one refinement with no evidence, ask one specific motivation question.
